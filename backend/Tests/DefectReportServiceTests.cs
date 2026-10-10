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
using PackagingType = backend.Models.PackagingType;
using RawMaterial = backend.Models.RawMaterial;
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
            AffectedInventory = [],
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
    public async Task CreateAsync_WithCatalogueSku_AllowsReportingBeforeRollRegistration()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        var packagingType = new PackagingType
        {
            Name = "Box Pouch",
            ShortCode = "BP"
        };
        db.PackagingTypes.Add(packagingType);
        await db.SaveChangesAsync();
        db.RawMaterials.Add(new RawMaterial
        {
            SkuCode = "BP-LAM-001",
            Name = "Laminated Barrier Film",
            Category = "Box Pouch",
            MaterialCode = "LAM",
            PackagingTypeId = packagingType.Id,
            UnitOfMeasure = "KG"
        });
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);
        var created = await service.CreateAsync(new CreateDefectReportDto
        {
            SkuCode = "BP-LAM-001",
            Severity = DefectSeverity.MEDIUM,
            Description = "Sealing film shows pinholes.",
            Status = DefectStatus.Open
        }, null);

        Assert.Equal("BP-LAM-001", created.SkuCode);
        Assert.StartsWith("SKU-BP-LAM-001-", created.BatchId);
        Assert.Empty(created.AffectedInventory);
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

    [Fact]
    public async Task CreateAsync_WhenRollAlreadyInActiveDefectReport_ThrowsConflictException()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH100",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>()
        });
        db.DefectReports.Add(new DefectReport
        {
            BatchId = "BATCH100",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.HIGH,
            Description = "Active defect on roll",
            Status = DefectStatus.Open,
            AffectedInventoryJson = "[\"ROLL-ACTIVE-01\"]"
        });
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);
        var dto = new CreateDefectReportDto
        {
            BatchId = "BATCH100",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.MEDIUM,
            Description = "Duplicate defect attempt on same roll",
            AffectedInventory = ["ROLL-ACTIVE-01"],
            Status = DefectStatus.Open
        };

        var ex = await Assert.ThrowsAsync<AuthException>(() => service.CreateAsync(dto, null));
        Assert.Contains("already have an active defect report or quarantine", ex.Message);
    }

    [Fact]
    public async Task CreateAsync_WhenPreviousDefectResolvedOrClosed_AllowsCreation()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH200",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>()
        });
        db.Batches.Add(new Batch
        {
            Id = "BATCH201",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>()
        });
        db.DefectReports.Add(new DefectReport
        {
            BatchId = "BATCH200",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.LOW,
            Description = "Previously resolved defect",
            Status = DefectStatus.Resolved,
            AffectedInventoryJson = "[\"ROLL-RESOLVED-01\"]"
        });
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);
        var dto = new CreateDefectReportDto
        {
            BatchId = "BATCH201",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.HIGH,
            Description = "New defect after resolution",
            AffectedInventory = ["ROLL-RESOLVED-01"],
            Status = DefectStatus.Open
        };

        var created = await service.CreateAsync(dto, null);
        Assert.NotNull(created);
        Assert.Contains("ROLL-RESOLVED-01", created.AffectedInventory);
    }

    [Fact]
    public async Task CreateAsync_WhenPreviousDefectDeleted_AllowsCreation()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new ApplicationDbContext(options);
        db.Batches.Add(new Batch
        {
            Id = "BATCH300",
            ProductType = ProductType.Bottle,
            InventoryRolls = new List<InventoryRoll>()
        });
        var initialDefect = new DefectReport
        {
            BatchId = "BATCH300",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.MEDIUM,
            Description = "Old defect to be deleted",
            Status = DefectStatus.Open,
            AffectedInventoryJson = "[\"ROLL-DELETED-01\"]"
        };
        db.DefectReports.Add(initialDefect);
        await db.SaveChangesAsync();

        var service = new DefectReportService(db);
        // Delete the initial defect report
        var deleted = await service.DeleteAsync(initialDefect.Id);
        Assert.True(deleted);

        // Now creating for the same roll should succeed
        var dto = new CreateDefectReportDto
        {
            BatchId = "BATCH300",
            ProductType = ProductType.Bottle,
            Severity = DefectSeverity.LOW,
            Description = "New defect after deletion",
            AffectedInventory = ["ROLL-DELETED-01"],
            Status = DefectStatus.Open
        };

        var created = await service.CreateAsync(dto, null);
        Assert.NotNull(created);
        Assert.Contains("ROLL-DELETED-01", created.AffectedInventory);
    }
}
