using System;
using System.Threading;
using System.Threading.Tasks;
using backend.Data;
using backend.Models;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace backend.Tests;

/// <summary>
/// Focused business-rule tests: the calculation and the low-stock decision
/// remain independently testable without an HTTP server or PostgreSQL.
/// </summary>
public class InventoryBusinessLogicTests
{
    private static ManufacturingContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<ManufacturingContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ManufacturingContext(options);
    }

    private static InventoryService CreateService(ManufacturingContext context) => new(
        context,
        new TestBarcodeService(),
        new ConfigurationBuilder().Build(),
        NullLogger<InventoryService>.Instance);

    private sealed class TestBarcodeService : IBarcodeService
    {
        public Task<QrCodeImage> GenerateInventoryRollQrAsync(
            string rollIdentifier,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(new QrCodeImage(Array.Empty<byte>(), "image/png"));
    }

    [Fact]
    public void BurnRateCalculation_DividesConsumptionByRecordedDays()
    {
        using var context = CreateContext();
        var service = CreateService(context);

        // 2,400 kg consumed in 30 days = 80 kg per day.
        Assert.Equal(80m, service.CalculateBurnRate(2400m, 30));
        Assert.Equal(0m, service.CalculateBurnRate(2400m, 0));
    }

    [Fact]
        public async Task LowStockDetection_UsesTheLiveInventorySkuBalance()
    {
        await using var context = CreateContext();
        var service = CreateService(context);
        var material = await service.CreateRawMaterialAsync(new RawMaterial
        {
            SkuCode = "CR-001",
            Name = "BoxPouch film",
            Category = "BoxPouch",
            UnitOfMeasure = "KG",
            ReorderThreshold = 100m,
        });
        context.InventoryItems.Add(new InventoryItem
        {
            Sku = material.SkuCode,
            Name = material.Name,
            StockLevel = 40,
            ReorderThreshold = 100,
        });
        await context.SaveChangesAsync();

        await service.CreateInventoryRollAsync(new InventoryRoll
        {
            RawMaterialId = material.Id,
            RollIdentifier = "CR-001-ROLL-TEST",
            InitialQuantity = 40m,
            CurrentQuantity = 40m,
            Status = "In Stock",
        });

        var result = await service.DetectLowStockAsync(material.Id);

        Assert.True(result.LowStock);
        Assert.Equal("LOW", result.Severity);
        Assert.Equal(80m, result.CurrentStock);
    }

    [Fact]
    public async Task ProcessAutomatedLowStockReplenishment_CreatesAlertAndHandlesOfflineAiGracefully()
    {
        await using var context = CreateContext();
        var service = CreateService(context);

        context.InventoryItems.Add(new InventoryItem
        {
            Sku = "BP-FILM-AUTO",
            Name = "Auto Film",
            StockLevel = 30,
            ReorderThreshold = 100
        });
        await context.SaveChangesAsync();

        // Run automated replenishment routine
        await service.ProcessAutomatedLowStockReplenishmentAsync();

        // Verify a StockAlert was automatically created for this low-stock item
        var alert = await context.StockAlerts.SingleOrDefaultAsync(a => a.Sku == "BP-FILM-AUTO");
        Assert.NotNull(alert);
        Assert.Equal("Automated Low-Stock Detector", alert.WorkerId);
        Assert.True(alert.QuantityRequested > 0);
    }
}
