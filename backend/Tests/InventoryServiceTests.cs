using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using backend.Data;
using backend.Dtos;
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
            var barcodeService = new TestBarcodeService();
            var config = new ConfigurationBuilder().Build();
            var logger = NullLogger<InventoryService>.Instance;
            return new InventoryService(context, barcodeService, config, logger);
        }

        private sealed class TestBarcodeService : IBarcodeService
        {
            public Task<QrCodeImage> GenerateInventoryRollQrAsync(
                string rollIdentifier,
                CancellationToken cancellationToken = default) =>
                Task.FromResult(new QrCodeImage(Array.Empty<byte>(), "image/png"));
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
            context.InventoryItems.Add(new InventoryItem
            {
                Sku = mat.SkuCode,
                Name = mat.Name,
                StockLevel = 500,
                ReorderThreshold = 100,
            });
            await context.SaveChangesAsync();

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
            Assert.Equal(500m, qrResult.RemainingQuantity);
            Assert.Equal(1000m, qrResult.CurrentSkuStock);

            // UPDATE ROLL
            roll.CurrentQuantity = 200m;
            var updated = await service.UpdateInventoryRollAsync(roll.Id, roll);
            Assert.True(updated);

            var verifyQr = await service.GetInventoryRollByQrAsync("QR-ROLL-TEST-001");
            Assert.Equal(200m, verifyQr?.RemainingQuantity);
        }

        [Fact]
        public async Task InventoryRoll_GeneratesItsOwnQrReference_And_IncreasesSkuStock()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);
            var material = await service.CreateRawMaterialAsync(new RawMaterial
            {
                Name = "Test film",
                SkuCode = "RM-ROLL-AUTO",
            });
            context.InventoryItems.Add(new InventoryItem
            {
                Sku = material.SkuCode,
                Name = material.Name,
                StockLevel = 100,
            });
            await context.SaveChangesAsync();

            var roll = await service.CreateInventoryRollAsync(new InventoryRoll
            {
                RawMaterialId = material.Id,
                InitialQuantity = 75m,
            });

            Assert.StartsWith("ROLL-", roll.RollIdentifier);
            Assert.Equal(75m, roll.CurrentQuantity);
            Assert.Equal("In Stock", roll.Status);
            Assert.Equal(175, (await context.InventoryItems.SingleAsync()).StockLevel);

            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.CreateInventoryRollAsync(new InventoryRoll
                {
                    RawMaterialId = material.Id,
                    InitialQuantity = 0m,
                }));
            await service.CreateInventoryRollAsync(new InventoryRoll
            {
                RawMaterialId = material.Id,
                InitialQuantity = 26m,
            });
            Assert.Equal(201, (await context.InventoryItems.SingleAsync()).StockLevel);
        }

        [Fact]
        public async Task RegisteringRoll_AddsItsQuantityToTheStockLevelShownForItsSku()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);
            var material = await service.CreateRawMaterialAsync(new RawMaterial
            {
                Name = "Tinplate sheet",
                SkuCode = "CAN-TIN-001",
                ReorderThreshold = 140m,
            });
            context.InventoryItems.Add(new InventoryItem
            {
                Sku = material.SkuCode,
                Name = material.Name,
                RawMaterialId = material.Id,
                StockLevel = 260,
                ReorderThreshold = 140,
            });
            await context.SaveChangesAsync();

            await service.CreateInventoryRollAsync(new InventoryRoll
            {
                RawMaterialId = material.Id,
                RollIdentifier = "ROLL-CAN-TIN-001-01",
                InitialQuantity = 2m,
            });

            var item = await context.InventoryItems.SingleAsync();
            var stockLevel = (await service.GetStockLevelsAsync()).Single();
            Assert.Equal(262, item.StockLevel);
            Assert.Equal(262m, stockLevel.CurrentStock);
            Assert.Equal("CAN-TIN-001", stockLevel.SkuCode);

            var scanned = await service.GetInventoryRollByQrAsync(
                "ROLL-CAN-TIN-001-01");
            Assert.Equal(262m, scanned?.CurrentSkuStock);
        }

        [Fact]
        public async Task LowStockAlert_ResolvesTheSkuFromTheSelectedMaterial()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);
            var packaging = new PackagingType
            {
                Name = "Can",
                ShortCode = "CAN",
                IsActive = true,
            };
            context.PackagingTypes.Add(packaging);
            await context.SaveChangesAsync();

            var material = await service.CreateRawMaterialAsync(new RawMaterial
            {
                Name = "Tinplate sheet",
                SkuCode = "CAN-TIN-001",
                MaterialCode = "TIN",
                PackagingTypeId = packaging.Id,
            });
            context.InventoryItems.Add(new InventoryItem
            {
                Sku = material.SkuCode,
                Name = material.Name,
                RawMaterialId = material.Id,
                PackagingTypeId = packaging.Id,
                StockLevel = 260,
            });
            await context.SaveChangesAsync();

            var alert = await service.CreateStockAlertAsync(new CreateStockAlertDto
            {
                PackagingTypeId = packaging.Id,
                RawMaterialId = material.Id,
                QuantityRequested = 25,
                WorkerId = "EMP0000",
            });

            Assert.Equal("CAN-TIN-001", alert.Sku);
            Assert.Equal("Can", alert.PackagingType);
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
            context.InventoryItems.Add(new InventoryItem
            {
                Sku = mat.SkuCode,
                Name = mat.Name,
                StockLevel = 100,
                ReorderThreshold = 500,
            });
            await context.SaveChangesAsync();

            // Receipt increases the live SKU balance to 200; it remains
            // critically below its 500-unit threshold.
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

        [Fact]
        public async Task GetStockAlertsAsync_ReturnsOnlyTheLatestAlertForEachSku()
        {
            var context = CreateInMemoryContext();
            var service = CreateService(context);
            var earlier = DateTime.UtcNow.AddMinutes(-10);
            var latest = DateTime.UtcNow;

            context.StockAlerts.AddRange(
                new StockAlert
                {
                    Sku = "CR-001",
                    PackagingType = "BoxPouch",
                    QuantityRequested = 500,
                    Status = "Pending",
                    Timestamp = earlier,
                    WorkerId = "Floor Worker"
                },
                new StockAlert
                {
                    Sku = "CR-001",
                    PackagingType = "BoxPouch",
                    QuantityRequested = 650,
                    Status = "Processing",
                    Timestamp = latest,
                    WorkerId = "Floor Worker"
                },
                new StockAlert
                {
                    Sku = "CR-002",
                    PackagingType = "Can",
                    QuantityRequested = 300,
                    Status = "Pending",
                    Timestamp = latest,
                    WorkerId = "Floor Worker"
                });
            await context.SaveChangesAsync();

            var alerts = (await service.GetStockAlertsAsync()).ToList();

            Assert.Equal(2, alerts.Count);
            var boxPouchAlert = Assert.Single(alerts, alert => alert.Sku == "CR-001");
            Assert.Equal(650, boxPouchAlert.QuantityRequested);
            Assert.Equal("Processing", boxPouchAlert.Status);
        }
    }
}

