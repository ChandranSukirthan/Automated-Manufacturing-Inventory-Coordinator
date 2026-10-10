using backend.Data;
using backend.Dtos;
using backend.Models;
using backend.Services;
using ManufacturingCoordinator.Api.Controllers;
using ManufacturingCoordinator.Controllers;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Services.PurchaseOrders;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace backend.Tests;

public class IntegrationCompletionTests
{
    [Fact]
    public void ForwardMigrationScript_PreservesRecordsAndExcludesDuplicateAlignmentExperiments()
    {
        using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql("Host=127.0.0.1;Database=unused_script_generation;Username=unused").Options);
        var script = db.GetService<IMigrator>().GenerateScript(); // Generates SQL without opening a database connection.
        Assert.DoesNotContain("DELETE FROM", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("IntegrationModelAlignment", script);
        Assert.DoesNotContain("ManufacturingModelAlignment", script);
        Assert.Contains("CREATE TABLE IF NOT EXISTS \"ProcurementRequests\"", script);
        Assert.Contains("UX_PurchaseOrders_ProcurementRequestId", script);
        Assert.Contains("Unassigned historical catalogue", script);
    }
    private static ApplicationDbContext Database() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static async Task Seed(ApplicationDbContext db)
    {
        db.RawMaterials.Add(new RawMaterial { Id = 1, SkuCode = "BP-FILM-001", Name = "Film", Category = "BoxPouch" });
        db.InventoryItems.Add(new InventoryItem { Sku = "BP-FILM-001", StockLevel = 10 });
        db.Suppliers.Add(new Supplier { Id = 1, Name = "Vendor", SupplierCode = "SUP-1", IsActive = true });
        var po = new PurchaseOrder { Id = 1, SupplierId = 1, PoNumber = "PO-TEST", Status = PurchaseOrderStatus.Sent,
            BudgetLimit = 1000, TotalCost = 200 };
        po.OrderLines.Add(new OrderLine { Id = 1, RawMaterialId = 1, Quantity = 100, UnitPrice = 2, TotalPrice = 200 });
        db.PurchaseOrders.Add(po);
        await db.SaveChangesAsync();
    }

    private static ReceiveGoodsRequest Receipt(string key, string batch, int quantity = 20) => new()
        { ReceiptKey = key, OrderLineId = 1, Quantity = quantity, RollIdentifier = key, BatchId = batch };

    [Fact]
    public async Task MaintenanceTrigger_UsesExactMachineAndCanApproveProcurement()
    {
        await using var db = Database();
        var machine = new ManufacturingCoordinator.Models.Production.Machine { Name = "Press", UptimeHours = 510 };
        db.Machines.Add(machine);
        db.AgentWorkflows.Add(new AgentWorkflow { WorkflowId = "WF-PROCUREMENT", WorkflowType = "Procurement" });
        await db.SaveChangesAsync();
        var admin = new AdminService(db, new PasswordHasher());
        await admin.TriggerWorkflowAsync($"Schedule preventive maintenance [MachineID: {machine.Id}]", null);
        var workflow = await db.AgentWorkflows.SingleAsync(w => w.WorkflowType == "Maintenance");
        await admin.ApproveWorkflowAsync(workflow.WorkflowId);
        await admin.ApproveWorkflowAsync(workflow.WorkflowId);
        Assert.Equal(MachineStatus.UnderMaintenance, machine.Status);
        Assert.Empty(await db.PurchaseOrders.ToListAsync());

        // IT Admin has authority to approve any agentic workflow (except payment)
        var approved = await admin.ApproveWorkflowAsync("WF-PROCUREMENT");
        Assert.Equal(ManufacturingCoordinator.Enums.ApprovalStatus.Approved, approved.ApprovalStatus);
    }

    [Fact]
    public async Task BatchQuarantine_LeavesOtherBatchOfTheSameMaterialAvailable()
    {
        await using var db = Database(); await Seed(db);
        var receipt = new GoodsReceiptService(db);
        await receipt.ReceiveAsync(1, Receipt("roll-a", "batch-a"), null);
        await receipt.ReceiveAsync(1, Receipt("roll-b", "batch-b"), null);
        var defect = new DefectReport { SkuCode = "BP-FILM-001", BatchId = "batch-a", Description = "Inspect", AffectedInventoryJson = "[]" };
        db.DefectReports.Add(defect); await db.SaveChangesAsync();
        var holds = await new QuarantineService(db).QuarantineDefectAsync(defect.Id, new CreateQuarantineDto { Reason = "Inspect" });
        Assert.Single(holds);
        Assert.Equal("ROLL-A", holds[0].InventoryRollId);
        Assert.Equal("In Stock", (await db.StockRolls.SingleAsync(r => r.RollIdentifier == "ROLL-B")).Status);
        Assert.Equal(30, (await db.InventoryItems.SingleAsync()).StockLevel);
    }

    [Fact]
    public async Task ReleaseOneRoll_DoesNotResolveAnotherActiveHoldInTheBatch()
    {
        await using var db = Database(); await Seed(db);
        var receipts = new GoodsReceiptService(db);
        await receipts.ReceiveAsync(1, Receipt("roll-a", "batch-a"), null);
        await receipts.ReceiveAsync(1, Receipt("roll-b", "batch-a"), null);
        var defect = new DefectReport { SkuCode = "BP-FILM-001", BatchId = "batch-a", Description = "Inspect", AffectedInventoryJson = "[]" };
        var workflow = new AgentWorkflow { WorkflowId = "WF-DEFECT-batch-a", ValidationResults = "{\"manualResolutionStatus\":\"PENDING_REVIEW\"}" };
        db.DefectReports.Add(defect); db.AgentWorkflows.Add(workflow); await db.SaveChangesAsync();
        var service = new QuarantineService(db);
        var holds = await service.QuarantineDefectAsync(defect.Id, new CreateQuarantineDto { Reason = "Inspect" });
        await service.ReleaseAsync(holds[0].Id, "Inspected", "QA");
        Assert.Contains("PENDING_REVIEW", workflow.ValidationResults);
        Assert.Single(await db.Quarantines.Where(q => q.Status == QuarantineStatus.Active).ToListAsync());
        await service.ReleaseAsync(holds[1].Id, "Inspected", "QA");
        Assert.Contains("RESOLVED", workflow.ValidationResults);
    }

    [Fact]
    public async Task NewSevereDefect_InvalidatesEarlierQaResolution()
    {
        await using var db = Database(); await Seed(db);
        var po = await db.PurchaseOrders.Include(p => p.OrderLines).SingleAsync();
        var service = new PurchaseOrderService(db, new DummyStripeService(), new DummyEmailService(),
            new ConfigurationBuilder().Build(), NullLogger<PurchaseOrderService>.Instance);
        var workflow = await service.RunAiValidationWorkflowAsync(po);
        workflow.ValidationResults = "{\"manualResolutionStatus\":\"RESOLVED\"}";
        db.DefectReports.Add(new DefectReport { SkuCode = "BP-FILM-001", BatchId = "batch-a", Description = "New severe defect", Severity = DefectSeverity.HIGH, AffectedInventoryJson = "[]" });
        await db.SaveChangesAsync();
        await service.RunAiValidationWorkflowAsync(po);
        Assert.Contains("PENDING_REVIEW", workflow.ValidationResults);
        Assert.Contains("MANUAL_REVIEW_REQUIRED", workflow.ValidationResults);
    }

    [Fact]
    public async Task Quarantine_RejectsAnExplicitRollFromAnotherBatch()
    {
        await using var db = Database(); await Seed(db);
        await new GoodsReceiptService(db).ReceiveAsync(1, Receipt("roll-b", "batch-b"), null);
        var defect = new DefectReport { SkuCode = "BP-FILM-001", BatchId = "batch-a", Description = "Inspect", AffectedInventoryJson = "[\"roll-b\"]" };
        db.DefectReports.Add(defect); await db.SaveChangesAsync();
        await Assert.ThrowsAsync<ManufacturingCoordinator.Api.Helpers.AuthException>(() =>
            new QuarantineService(db).QuarantineDefectAsync(defect.Id, new CreateQuarantineDto { Reason = "Inspect" }));
        Assert.Empty(await db.Quarantines.ToListAsync());
        Assert.Equal(30, (await db.InventoryItems.SingleAsync()).StockLevel);
    }

    [Fact]
    public async Task Receipt_RejectsBatchFromAnotherPackagingCategoryWithoutStockChanges()
    {
        await using var db = Database(); await Seed(db);
        db.Batches.Add(new ManufacturingCoordinator.Models.Inventory.Batch { Id = "wrong", ProductType = ProductType.TeaBag });
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => new GoodsReceiptService(db).ReceiveAsync(1, Receipt("roll", "wrong"), null));
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Empty(await db.GoodsReceipts.ToListAsync());
        Assert.Empty(await db.InventoryMovements.ToListAsync());
    }

    [Fact]
    public async Task DispatchedOrderValidation_AwaitsReceiptForBothNewAndExistingWorkflow()
    {
        await using var db = Database(); await Seed(db);
        var service = new PurchaseOrderService(db, new DummyStripeService(), new DummyEmailService(),
            new ConfigurationBuilder().Build(), NullLogger<PurchaseOrderService>.Instance);
        var po = await db.PurchaseOrders.Include(p => p.OrderLines).SingleAsync();
        var workflow = await service.RunAiValidationWorkflowAsync(po);
        Assert.Equal(1, workflow.PurchaseOrderId);
        Assert.Equal(WorkflowStatus.Running, workflow.Status);
        Assert.Null(workflow.CompletedAt);
        Assert.Equal("Goods Receipt", workflow.CurrentAgent);
        await service.RunAiValidationWorkflowAsync(po);
        Assert.Equal(WorkflowStatus.Running, workflow.Status);
        Assert.Single(await db.AgentWorkflows.ToListAsync());
    }

    [Theory]
    [InlineData(typeof(PurchaseOrdersController), "Approve", "SupplyChainManager,ITAdmin")]
    [InlineData(typeof(QualityAiValidationController), "ResolveWorkflow", "QualityInspector")]
    [InlineData(typeof(QuarantineController), "Release", "QualityInspector")]
    public void ApprovalOwnership_IsEnforcedAtTheBackendBoundary(Type controller, string method, string role)
    {
        var policy = controller.GetMethods().Single(m => m.Name == method)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>().Single();
        Assert.Equal(role, policy.Roles);
    }

    [Fact]
    public async Task ManualRollCrud_RecordsBalancedMovementsWithoutAnAiClient()
    {
        await using var db = new ManufacturingContext(new DbContextOptionsBuilder<ManufacturingContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.RawMaterials.Add(new RawMaterial { Id = 1, SkuCode = "BP-FILM-001", Name = "Film" });
        db.InventoryItems.Add(new InventoryItem { Sku = "BP-FILM-001", RawMaterialId = 1 });
        await db.SaveChangesAsync();
        using var cache = new Microsoft.Extensions.Caching.Memory.MemoryCache(new Microsoft.Extensions.Caching.Memory.MemoryCacheOptions());
        var service = new InventoryService(db, new BarcodeService(cache, NullLogger<BarcodeService>.Instance), new ConfigurationBuilder().Build(), NullLogger<InventoryService>.Instance);
        var roll = await service.CreateInventoryRollAsync(new backend.Models.InventoryRoll
            { RawMaterialId = 1, RollIdentifier = "offline-roll", BatchId = "offline-batch", InitialQuantity = 10 });
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
        await service.UpdateInventoryRollAsync(roll.Id, new backend.Models.InventoryRoll
            { Id = roll.Id, InitialQuantity = 10, CurrentQuantity = 4, Status = "In Stock" });
        Assert.Equal(4, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.True(await service.DeleteInventoryRollAsync(roll.Id));
        Assert.Equal(0, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal(new[] { "RECEIVED", "CONSUMED", "REMOVED" }, await db.InventoryMovements.OrderBy(m => m.Id).Select(m => m.TransactionType).ToArrayAsync());
    }
}
