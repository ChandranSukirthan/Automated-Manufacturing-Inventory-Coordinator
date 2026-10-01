using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using backend.Models;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Services.PurchaseOrders;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using InventoryRoll = ManufacturingCoordinator.Models.Inventory.InventoryRoll;
using Batch = ManufacturingCoordinator.Models.Inventory.Batch;

namespace backend.Tests;

public class DummyStripeService : IStripeService
{
    public Task<StripePaymentResult> CreatePaymentIntentAsync(decimal amount, string currency, string description)
    {
        return Task.FromResult(new StripePaymentResult(true, "pi_mock_123", "succeeded", null));
    }
}

public class DummyEmailService : IEmailService
{
    public Task SendOtpEmailAsync(string toEmail, string recipientName, string otpCode) => Task.CompletedTask;
    public Task SendPurchaseOrderEmailAsync(string toEmail, string supplierName, string poNumber, byte[] pdfAttachment, string attachmentFileName) => Task.CompletedTask;
}

public class QaWorkflowIsolationTests
{
    private static ApplicationDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    [Fact]
    public async Task Test1_TwoIndependentQuarantines_ResolvingQuarantineA_DoesNotPolluteWorkflowB()
    {
        await using var db = CreateInMemoryDbContext();

        // Setup Batch & Rolls
        var batch = new Batch
        {
            Id = "BATCH-TEST-001",
            ProductType = ProductType.BoxPouch,
            InventoryRolls = new List<InventoryRoll>
            {
                new() { Id = "ROLL-A", BatchId = "BATCH-TEST-001", Status = InventoryStatus.Quarantined },
                new() { Id = "ROLL-B", BatchId = "BATCH-TEST-001", Status = InventoryStatus.Quarantined }
            }
        };
        db.Batches.Add(batch);

        var defectA = new DefectReport
        {
            Id = Guid.NewGuid(),
            BatchId = "BATCH-TEST-001",
            ProductType = ProductType.BoxPouch,
            Severity = DefectSeverity.HIGH,
            Description = "Defect on Roll A",
            AffectedInventoryJson = "[\"ROLL-A\"]",
            Status = DefectStatus.Open
        };
        var defectB = new DefectReport
        {
            Id = Guid.NewGuid(),
            BatchId = "BATCH-TEST-001",
            ProductType = ProductType.BoxPouch,
            Severity = DefectSeverity.HIGH,
            Description = "Defect on Roll B",
            AffectedInventoryJson = "[\"ROLL-B\"]",
            Status = DefectStatus.Open
        };
        db.DefectReports.AddRange(defectA, defectB);

        var quarantineA = new Quarantine
        {
            Id = Guid.NewGuid(),
            DefectReportId = defectA.Id,
            InventoryRollId = "ROLL-A",
            Reason = "Defect on Roll A",
            Status = QuarantineStatus.Active,
            CreatedAt = DateTime.UtcNow
        };
        var quarantineB = new Quarantine
        {
            Id = Guid.NewGuid(),
            DefectReportId = defectB.Id,
            InventoryRollId = "ROLL-B",
            Reason = "Defect on Roll B",
            Status = QuarantineStatus.Active,
            CreatedAt = DateTime.UtcNow
        };
        db.Quarantines.AddRange(quarantineA, quarantineB);

        var wfA = new AgentWorkflow
        {
            Id = Guid.NewGuid(),
            WorkflowId = "WF-DEFECT-ROLL-A",
            Objective = "Quality assessment for ROLL-A",
            ValidationResults = JsonSerializer.Serialize(new Dictionary<string, object?>
            {
                ["isValid"] = false,
                ["qualitySafetyStatus"] = "QUARANTINE_ACTIVE",
                ["quarantinedRollsCount"] = 1,
                ["manualResolutionStatus"] = "PENDING_REVIEW",
                ["manualResolutionNote"] = "",
                ["resolvedBy"] = "",
                ["resolvedAt"] = null
            })
        };
        var wfB = new AgentWorkflow
        {
            Id = Guid.NewGuid(),
            WorkflowId = "WF-DEFECT-ROLL-B",
            Objective = "Quality assessment for ROLL-B",
            ValidationResults = JsonSerializer.Serialize(new Dictionary<string, object?>
            {
                ["isValid"] = false,
                ["qualitySafetyStatus"] = "QUARANTINE_ACTIVE",
                ["quarantinedRollsCount"] = 1,
                ["manualResolutionStatus"] = "PENDING_REVIEW",
                ["manualResolutionNote"] = "",
                ["resolvedBy"] = "",
                ["resolvedAt"] = null
            })
        };
        db.AgentWorkflows.AddRange(wfA, wfB);
        await db.SaveChangesAsync();

        var service = new QuarantineService(db);

        // Act: Release ONLY Quarantine A
        var releaseResult = await service.ReleaseAsync(quarantineA.Id, "Released roll A after quality inspection", "Inspector Nithushan");

        Assert.NotNull(releaseResult);
        Assert.Equal(QuarantineStatus.Released, releaseResult.Status);

        // Reload workflows from DB
        var updatedWfA = await db.AgentWorkflows.FirstAsync(w => w.WorkflowId == "WF-DEFECT-ROLL-A");
        var updatedWfB = await db.AgentWorkflows.FirstAsync(w => w.WorkflowId == "WF-DEFECT-ROLL-B");

        using var docA = JsonDocument.Parse(updatedWfA.ValidationResults!);
        using var docB = JsonDocument.Parse(updatedWfB.ValidationResults!);

        // Assert: Workflow A is resolved
        Assert.Equal("RESOLVED", docA.RootElement.GetProperty("manualResolutionStatus").GetString());
        Assert.Equal("Released roll A after quality inspection", docA.RootElement.GetProperty("manualResolutionNote").GetString());
        Assert.Equal("Inspector Nithushan", docA.RootElement.GetProperty("resolvedBy").GetString());

        // Assert: Workflow B remains UNTOUCHED (PENDING_REVIEW)
        Assert.Equal("PENDING_REVIEW", docB.RootElement.GetProperty("manualResolutionStatus").GetString());
        Assert.Equal("", docB.RootElement.GetProperty("manualResolutionNote").GetString());
    }

    [Fact]
    public async Task Test2_StaleResolutionPrevention_ActiveQuarantine_ResetsToPendingReview()
    {
        await using var db = CreateInMemoryDbContext();

        var supplier = new Supplier
        {
            Id = 1,
            Name = "Supplier One",
            SupplierCode = "SUP-001",
            IsActive = true,
            ContactEmail = "supplier@test.com",
            LeadTimeDays = 5
        };
        var rawMaterial = new RawMaterial
        {
            Id = 1,
            Name = "Polymer Resin",
            SkuCode = "RM-POLY-001"
        };
        db.Suppliers.Add(supplier);
        db.RawMaterials.Add(rawMaterial);

        var po = new PurchaseOrder
        {
            Id = 1,
            PoNumber = "PO-2026-0033",
            SupplierId = 1,
            BudgetLimit = 5000m,
            TotalCost = 1000m,
            Currency = "USD",
            Status = PurchaseOrderStatus.Draft,
            OrderLines = new List<OrderLine>
            {
                new() { RawMaterialId = 1, Quantity = 100, UnitPrice = 10m, TotalPrice = 1000m }
            }
        };
        db.PurchaseOrders.Add(po);

        // An active quarantine exists in DB
        db.Quarantines.Add(new Quarantine
        {
            Id = Guid.NewGuid(),
            InventoryRollId = "ROLL-TEST-1",
            Reason = "Active quarantine defect",
            Status = QuarantineStatus.Active,
            CreatedAt = DateTime.UtcNow
        });

        // Workflow has stale "RESOLVED" state
        var staleWf = new AgentWorkflow
        {
            Id = Guid.NewGuid(),
            WorkflowId = "WF-QA-PO-2026-0033",
            Objective = "Validation for PO PO-2026-0033",
            ValidationResults = JsonSerializer.Serialize(new Dictionary<string, object?>
            {
                ["isValid"] = true,
                ["qualitySafetyStatus"] = "QUARANTINE_ACTIVE",
                ["quarantinedRollsCount"] = 1,
                ["manualResolutionStatus"] = "RESOLVED", // STALE RESOLUTION
                ["manualResolutionNote"] = "Old stale note",
                ["resolvedBy"] = "Old Inspector",
                ["resolvedAt"] = "2026-09-01T00:00:00Z"
            })
        };
        db.AgentWorkflows.Add(staleWf);
        await db.SaveChangesAsync();

        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();
        var poService = new PurchaseOrderService(
            db,
            new DummyStripeService(),
            new DummyEmailService(),
            config,
            NullLogger<PurchaseOrderService>.Instance
        );

        // Act: Re-run validation for PO
        var resultWf = await poService.EnsurePoValidationWorkflowAsync(po);

        // Assert: It must NOT remain falsely resolved!
        using var doc = JsonDocument.Parse(resultWf.ValidationResults!);
        Assert.False(doc.RootElement.GetProperty("isValid").GetBoolean());
        Assert.Equal("QUARANTINE_ACTIVE", doc.RootElement.GetProperty("qualitySafetyStatus").GetString());
        Assert.Equal("PENDING_REVIEW", doc.RootElement.GetProperty("manualResolutionStatus").GetString());
        Assert.Equal(1, doc.RootElement.GetProperty("quarantinedRollsCount").GetInt32());
    }

    [Fact]
    public async Task Test3_FreshClearWorkflow_HasClearSafety_And_NotRequiredManualResolution()
    {
        await using var db = CreateInMemoryDbContext();

        var supplier = new Supplier
        {
            Id = 1,
            Name = "Active Supplier",
            SupplierCode = "SUP-001",
            IsActive = true,
            ContactEmail = "supplier@test.com",
            LeadTimeDays = 3
        };
        var rawMaterial = new RawMaterial
        {
            Id = 1,
            Name = "Steel Sheet",
            SkuCode = "RM-STEEL-001"
        };
        db.Suppliers.Add(supplier);
        db.RawMaterials.Add(rawMaterial);

        var po = new PurchaseOrder
        {
            Id = 2,
            PoNumber = "PO-2026-0034",
            SupplierId = 1,
            BudgetLimit = 5000m,
            TotalCost = 500m,
            Currency = "USD",
            Status = PurchaseOrderStatus.Draft,
            OrderLines = new List<OrderLine>
            {
                new() { RawMaterialId = 1, Quantity = 25, UnitPrice = 20m, TotalPrice = 500m }
            }
        };
        db.PurchaseOrders.Add(po);
        await db.SaveChangesAsync();

        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();
        var poService = new PurchaseOrderService(
            db,
            new DummyStripeService(),
            new DummyEmailService(),
            config,
            NullLogger<PurchaseOrderService>.Instance
        );

        // Act
        var resultWf = await poService.EnsurePoValidationWorkflowAsync(po);

        // Assert: Clear case
        using var doc = JsonDocument.Parse(resultWf.ValidationResults!);
        Assert.True(doc.RootElement.GetProperty("isValid").GetBoolean());
        Assert.Equal("CLEAR", doc.RootElement.GetProperty("qualitySafetyStatus").GetString());
        Assert.Equal("NOT_REQUIRED", doc.RootElement.GetProperty("manualResolutionStatus").GetString());
        Assert.Equal(0, doc.RootElement.GetProperty("quarantinedRollsCount").GetInt32());
    }

    [Fact]
    public async Task Test4_ManagerApprovalGate_BlockedWhenQuarantineActive_AllowedAfterResolution()
    {
        await using var db = CreateInMemoryDbContext();

        var supplier = new Supplier
        {
            Id = 1,
            Name = "Supplier A",
            SupplierCode = "SUP-001",
            IsActive = true,
            ContactEmail = "supp@test.com",
            LeadTimeDays = 5
        };
        var rawMaterial = new RawMaterial
        {
            Id = 1,
            Name = "Material A",
            SkuCode = "RM-A"
        };
        db.Suppliers.Add(supplier);
        db.RawMaterials.Add(rawMaterial);

        var po = new PurchaseOrder
        {
            Id = 10,
            PoNumber = "PO-2026-0040",
            SupplierId = 1,
            BudgetLimit = 10000m,
            TotalCost = 2000m,
            Currency = "USD",
            Status = PurchaseOrderStatus.PendingApproval,
            Notes = "Workflow ID: WF-QA-PO-2026-0040",
            OrderLines = new List<OrderLine>
            {
                new() { RawMaterialId = 1, Quantity = 200, UnitPrice = 10m, TotalPrice = 2000m }
            }
        };
        db.PurchaseOrders.Add(po);

        var quarantine = new Quarantine
        {
            Id = Guid.NewGuid(),
            InventoryRollId = "ROLL-40",
            Reason = "Defect hold",
            Status = QuarantineStatus.Active,
            CreatedAt = DateTime.UtcNow
        };
        db.Quarantines.Add(quarantine);
        await db.SaveChangesAsync();

        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();
        var poService = new PurchaseOrderService(
            db,
            new DummyStripeService(),
            new DummyEmailService(),
            config,
            NullLogger<PurchaseOrderService>.Instance
        );

        // 1. Initial Validation -> BLOCKED
        await poService.EnsurePoValidationWorkflowAsync(po);
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => poService.ValidateApprovalGateAsync(po));
        Assert.Contains("Approval blocked: QA validation requires manual review.", ex.Message);

        // 2. Resolve & Release Quarantine
        quarantine.Status = QuarantineStatus.Released;
        quarantine.ReleasedAt = DateTime.UtcNow;

        var wf = await db.AgentWorkflows.FirstAsync(w => w.WorkflowId == "WF-QA-PO-2026-0040");
        wf.ValidationResults = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["isValid"] = true,
            ["qualitySafetyStatus"] = "CLEAR",
            ["supplierValidation"] = "PASSED",
            ["budgetCheck"] = "PASSED",
            ["poMathematicalCheck"] = "PASSED",
            ["materialValidation"] = "PASSED",
            ["quarantinedRollsCount"] = 0,
            ["isHighImpact"] = false,
            ["impactReason"] = "",
            ["rejectionReason"] = "",
            ["manualResolutionStatus"] = "RESOLVED",
            ["manualResolutionNote"] = "Inspected and verified release",
            ["resolvedBy"] = "Inspector",
            ["resolvedAt"] = DateTime.UtcNow.ToString("o")
        });
        await db.SaveChangesAsync();

        // 3. Approval Gate check now PASSES without exception
        var exception = await Record.ExceptionAsync(() => poService.ValidateApprovalGateAsync(po));
        Assert.Null(exception);
    }
}
