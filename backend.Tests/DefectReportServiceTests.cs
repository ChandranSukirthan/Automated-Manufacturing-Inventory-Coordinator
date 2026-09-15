using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Inventory;
using ManufacturingCoordinator.Models.Quality;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace backend.Tests;

public class DefectReportServiceTests
{
    [Fact]
    public async Task CreateAsync_WhenBatchAlreadyHasDefect_ThrowsBusinessRuleException()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH111",
            ProductType = ProductType.BoxPouch,
            InventoryRolls = new List<InventoryRoll>()
        });
        db.DefectReports.Add(new DefectReport
        {
            BatchId = "BATCH111",
            ProductType = ProductType.BoxPouch,
            Severity = DefectSeverity.HIGH,
            Description = "Existing issue",
            Status = DefectStatus.Open,
            AffectedInventoryJson = "[\"ROLL11\",\"ROLL12\"]"
        });
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);

        var dto = new CreateDefectReportDto
        {
            BatchId = "BATCH111",
            ProductType = ProductType.BoxPouch,
            Severity = DefectSeverity.MEDIUM,
            Description = "Second report",
            AffectedInventory = ["ROLL13"],
            Status = DefectStatus.Open
        };

        var ex = await Assert.ThrowsAsync<AuthException>(() => service.CreateAsync(dto, null));
        Assert.Equal("A defect has already been created for this batch.", ex.Message);
    }

    [Fact]
    public async Task CreateAsync_WhenBatchHasNoDefect_AllowsCreation()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH222",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>()
        });
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);

        var dto = new CreateDefectReportDto
        {
            BatchId = "BATCH222",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.LOW,
            Description = "First report",
            AffectedInventory = ["ROLL21"],
            Status = DefectStatus.Open
        };

        var created = await service.CreateAsync(dto, null);

        Assert.Equal("BATCH222", created.BatchId);
        Assert.Equal(["ROLL21"], created.AffectedInventory);
        Assert.Equal(1, await db.DefectReports.CountAsync());
    }

    [Fact]
    public async Task QuarantineDefectAsync_UsesAllAffectedInventoryRolls()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH111",
            ProductType = ProductType.BoxPouch,
            InventoryRolls = new List<InventoryRoll>
            {
                new() { Id = "ROLL11", BatchId = "BATCH111" },
                new() { Id = "ROLL12", BatchId = "BATCH111" },
                new() { Id = "ROLL13", BatchId = "BATCH111" }
            }
        });
        var defect = new DefectReport
        {
            BatchId = "BATCH111",
            ProductType = ProductType.BoxPouch,
            Severity = DefectSeverity.HIGH,
            Description = "Affected rolls",
            AffectedInventoryJson = "[\"ROLL11\",\"ROLL12\"]",
            Status = DefectStatus.Open
        };
        db.DefectReports.Add(defect);
        await db.SaveChangesAsync();

        var service = new QuarantineService(db);
        var created = await service.QuarantineDefectAsync(
            defect.Id,
            new CreateQuarantineDto { Reason = "Quality defect" });

        Assert.Equal(["ROLL11", "ROLL12"], created.Select(item => item.InventoryRollId));
        Assert.Equal(
            InventoryStatus.Quarantined,
            (await db.InventoryRolls.SingleAsync(item => item.Id == "ROLL11")).Status);
        Assert.Equal(
            InventoryStatus.Available,
            (await db.InventoryRolls.SingleAsync(item => item.Id == "ROLL13")).Status);
    }

    [Fact]
    public async Task QuarantineDefectAsync_WhenNoAffectedInventory_UsesBatchRolls()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH222",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>
            {
                new() { Id = "ROLL21", BatchId = "BATCH222" },
                new() { Id = "ROLL22", BatchId = "BATCH222" }
            }
        });
        var defect = new DefectReport
        {
            BatchId = "BATCH222",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.MEDIUM,
            Description = "Batch-level issue",
            Status = DefectStatus.Open
        };
        db.DefectReports.Add(defect);
        await db.SaveChangesAsync();

        var service = new QuarantineService(db);
        var created = await service.QuarantineDefectAsync(
            defect.Id,
            new CreateQuarantineDto { Reason = "Batch-level quality issue" });

        Assert.Equal(["ROLL21", "ROLL22"], created.Select(item => item.InventoryRollId));
    }
}
