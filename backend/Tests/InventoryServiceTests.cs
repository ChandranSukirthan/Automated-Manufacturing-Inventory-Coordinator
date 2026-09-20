using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using backend.Data;
using backend.Models;
using backend.Services;
using Xunit;

namespace backend.Tests
{
    public class InventoryServiceTests
    {
        private ManufacturingContext CreateInMemoryContext()
        {
            var options = new DbContextOptionsBuilder<ManufacturingContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new ManufacturingContext(options);
        }

        private InventoryService CreateService(ManufacturingContext context)
        {
            var barcodeService = new BarcodeService();
            var config = new ConfigurationBuilder().Build();
            var logger = NullLogger<InventoryService>.Instance;
            return new InventoryService(context, barcodeService, config, logger);
        }

        [Fact]
        public void CalculateBurnRate_ComputesCorrectly()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);

            // 2400 KG / 30 days = 80 KG/day
            var rate = service.CalculateBurnRate(2400m, 30);
            Assert.Equal(80.00m, rate);

            // Safe failure on 0 days
            var zeroRate = service.CalculateBurnRate(2400m, 0);
            Assert.Equal(0m, zeroRate);
        }

        [Fact]
        public void CalculateDaysRemaining_ComputesCorrectly()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);

            // 350 KG / 80 KG/day = 4.38 days
            var days = service.CalculateDaysRemaining(350m, 80m);
            Assert.Equal(4.38m, days);

            // Zero burn rate returns safe buffer
            var infiniteDays = service.CalculateDaysRemaining(350m, 0m);
            Assert.Equal(999m, infiniteDays);
        }

        [Fact]
        public async Task RawMaterial_Crud_Operations_Succeed()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);

            // CREATE
            var mat = new RawMaterial
            {
                Name = "High Grade Stainless Steel",
                SkuCode = "RM-STEEL-TEST",
                Category = "Metal",
                UnitOfMeasure = "KG",
                ReorderThreshold = 200m
            };
            var created = await service.CreateRawMaterialAsync(mat);
            Assert.True(created.Id > 0);

            // READ
            var fetched = await service.GetRawMaterialByIdAsync(created.Id);
            Assert.NotNull(fetched);
            Assert.Equal("High Grade Stainless Steel", fetched.Name);

            // UPDATE
            fetched.Name = "Updated Stainless Steel";
            var updated = await service.UpdateRawMaterialAsync(fetched.Id, fetched);
            Assert.True(updated);

            var verifyUpdate = await service.GetRawMaterialByIdAsync(created.Id);
            Assert.Equal("Updated Stainless Steel", verifyUpdate?.Name);

            // DELETE
            var deleted = await service.DeleteRawMaterialAsync(created.Id);
            Assert.True(deleted);

            var verifyDelete = await service.GetRawMaterialByIdAsync(created.Id);
            Assert.Null(verifyDelete);
        }

        [Fact]
        public async Task InventoryRoll_Crud_And_QrLookup_Succeed()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);

            var mat = await service.CreateRawMaterialAsync(new RawMaterial
            {
                Name = "Aluminum Sheet",
                SkuCode = "RM-ALUM-QR",
                ReorderThreshold = 100m
            });

            // CREATE ROLL
            var roll = await service.CreateInventoryRollAsync(new InventoryRoll
            {
                RawMaterialId = mat.Id,
                RollIdentifier = "QR-ROLL-TEST-001",
                InitialQuantity = 500m,
                CurrentQuantity = 450m,
                Status = "In Stock"
            });
            Assert.True(roll.Id > 0);
            Assert.False(string.IsNullOrEmpty(roll.BarcodeUrl));

            // QR CODE LOOKUP
            var qrResult = await service.GetInventoryRollByQrAsync("QR-ROLL-TEST-001");
            Assert.NotNull(qrResult);
            Assert.Equal("QR-ROLL-TEST-001", qrResult.RollIdentifier);
            Assert.Equal("RM-ALUM-QR", qrResult.SkuCode);
            Assert.Equal(450m, qrResult.RemainingQuantity);

            // UPDATE ROLL
            roll.CurrentQuantity = 200m;
            var updated = await service.UpdateInventoryRollAsync(roll.Id, roll);
            Assert.True(updated);

            var verifyQr = await service.GetInventoryRollByQrAsync("QR-ROLL-TEST-001");
            Assert.Equal(200m, verifyQr?.RemainingQuantity);
        }

        [Fact]
        public async Task DetectLowStock_CreatesAlert_WhenBelowThreshold()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);

            var mat = await service.CreateRawMaterialAsync(new RawMaterial
            {
                Name = "Polymer Pellets",
                SkuCode = "RM-POLY-LOW",
                Category = "Plastic",
                ReorderThreshold = 500m
            });

            // Add roll with only 100 remaining (threshold is 500)
            await service.CreateInventoryRollAsync(new InventoryRoll
            {
                RawMaterialId = mat.Id,
                RollIdentifier = "ROLL-POLY-01",
                InitialQuantity = 100m,
                CurrentQuantity = 100m,
                Status = "In Stock"
            });

            var result = await service.DetectLowStockAsync(mat.Id);
            Assert.True(result.LowStock);
            Assert.Equal("CRITICAL", result.Severity);

            // Confirm StockAlert was automatically registered
            var alerts = await service.GetStockAlertsAsync();
            Assert.Contains(alerts, a => a.Sku == "RM-POLY-LOW");
        }
    }
}

