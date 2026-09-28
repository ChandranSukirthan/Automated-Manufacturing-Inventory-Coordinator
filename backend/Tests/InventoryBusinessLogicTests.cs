using System;
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
        new BarcodeService(),
        new ConfigurationBuilder().Build(),
        NullLogger<InventoryService>.Instance);

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
    public async Task LowStockDetection_FlagsInventoryRollBelowMaterialThreshold()
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
        Assert.Equal("CRITICAL", result.Severity);
        Assert.Equal(40m, result.CurrentStock);
    }
}
