using System.Text.Json;
using backend.Models;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Services;
using ManufacturingCoordinator.Services.PurchaseOrders;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Api.DTOs.Quality;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace backend.Tests;

public class InventoryIntegrationTests
{
    private static ApplicationDbContext Database() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static async Task<PurchaseOrder> Seed(ApplicationDbContext db, PurchaseOrderStatus status = PurchaseOrderStatus.Sent)
    {
        db.RawMaterials.Add(new RawMaterial { Id = 1, SkuCode = "BP-FILM-001", Name = "Film", Category = "BoxPouch", MaterialCode = "FILM" });
        db.InventoryItems.Add(new InventoryItem { Id = 1, Sku = "BP-FILM-001", Name = "Film", StockLevel = 10, ReorderThreshold = 20 });
        db.Suppliers.Add(new Supplier { Id = 1, SupplierCode = "SUP-001", Name = "Vendor", IsActive = true });
        var po = new PurchaseOrder { Id = 1, PoNumber = "PO-INTEGRATION", SupplierId = 1, Status = status, TotalCost = 200, BudgetLimit = 500 };
        po.OrderLines.Add(new OrderLine { Id = 1, RawMaterialId = 1, Quantity = 100, UnitPrice = 2, TotalPrice = 200 });
        db.PurchaseOrders.Add(po);
        await db.SaveChangesAsync();
        return po;
    }

    private static ReceiveGoodsRequest Receipt(string key, int quantity, string roll) => new()
        { ReceiptKey = key, Quantity = quantity, OrderLineId = 1, RollIdentifier = roll, BatchId = "BATCH-RECEIVED" };

    [Fact]
    public async Task PartialReceiptAndRetry_CountOnlyActualArrivals()
    {
        await using var db = Database(); var po = await Seed(db);
        db.AgentWorkflows.Add(new AgentWorkflow { WorkflowId = "WF-RECEIPT", PurchaseOrderId = 1 });
        await db.SaveChangesAsync();
        var service = new GoodsReceiptService(db);
        var first = await service.ReceiveAsync(1, Receipt("shipment-1", 40, "roll-1"), null);
        var repeated = await service.ReceiveAsync(1, Receipt("shipment-1", 40, "roll-1"), null);
        Assert.Equal(first.Id, repeated.Id);
        Assert.Equal(50, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal(PurchaseOrderStatus.InTransit, po.Status);
        Assert.Equal(WorkflowStatus.Running, (await db.AgentWorkflows.SingleAsync()).Status);
        await service.ReceiveAsync(1, Receipt("shipment-2", 60, "roll-2"), null);
        Assert.Equal(110, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal(PurchaseOrderStatus.Delivered, po.Status);
        Assert.NotNull(po.ActualDeliveryDate);
        Assert.Equal(2, await db.InventoryMovements.CountAsync());
        Assert.Equal(WorkflowStatus.Completed, (await db.AgentWorkflows.SingleAsync()).Status);
        Assert.Equal("BATCH-RECEIVED", (await db.StockRolls.FirstAsync()).BatchId);
        Assert.Single(await db.Batches.ToListAsync());
    }

    [Fact]
    public async Task Receipt_RejectsOverdeliveryAndReusedKeyForAnotherShipment()
    {
        await using var db = Database(); await Seed(db); var service = new GoodsReceiptService(db);
        await service.ReceiveAsync(1, Receipt("shipment", 50, "roll-1"), null);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.ReceiveAsync(1, Receipt("shipment", 49, "roll-1"), null));
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.ReceiveAsync(1, Receipt("shipment-2", 51, "roll-2"), null));
        Assert.Equal(60, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Single(await db.GoodsReceipts.ToListAsync());
    }

    [Fact]
    public async Task Approval_DoesNotManufactureInventory_AndCannotReceiveBeforeDispatch()
    {
        await using var db = Database(); var po = await Seed(db, PurchaseOrderStatus.PendingApproval);
        var service = new PurchaseOrderService(db, new DummyStripeService(), new DummyEmailService(),
            new ConfigurationBuilder().Build(), NullLogger<PurchaseOrderService>.Instance);
        await service.ApproveAsync(1, Guid.NewGuid());
        Assert.Equal(PurchaseOrderStatus.Approved, po.Status);
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Empty(await db.StockRolls.ToListAsync());
        await Assert.ThrowsAsync<InvalidOperationException>(() => new GoodsReceiptService(db).ReceiveAsync(1, Receipt("early", 1, "roll-early"), null));
    }

    [Fact]
    public async Task QuarantineAndRepeatedRelease_AdjustOnlyTheExactRollOnce()
    {
        await using var db = Database(); await Seed(db);
        await new GoodsReceiptService(db).ReceiveAsync(1, Receipt("arrival", 40, "roll-1"), null);
        var defect = new DefectReport { SkuCode = "BP-FILM-001", BatchId = "BATCH-RECEIVED", Severity = DefectSeverity.HIGH,
            Description = "Seal defect", AffectedInventoryJson = "[\"ROLL-1\"]" };
        db.DefectReports.Add(defect); await db.SaveChangesAsync();
        var qa = new QuarantineService(db);
        var holds = await qa.QuarantineDefectAsync(defect.Id, new CreateQuarantineDto { Reason = "Inspect seal" });
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal("Quarantined", (await db.StockRolls.SingleAsync()).Status);
        await qa.ReleaseAsync(holds[0].Id, "Inspection passed", "Inspector");
        await qa.ReleaseAsync(holds[0].Id, "Inspection passed", "Inspector");
        Assert.Equal(50, (await db.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal(3, await db.InventoryMovements.CountAsync());
    }

    [Fact]
    public async Task DraftFinalization_IsIdempotentAndCreatesNoStock()
    {
        await using var db = Database(); await Seed(db);
        db.AgentWorkflows.Add(new AgentWorkflow { WorkflowId = "WF-DRAFT", Status = WorkflowStatus.WaitingForApproval,
            StateJson = JsonSerializer.Serialize(new { material_id = "BP-FILM-001", budget_limit = 1000,
                draft_po = new { supplierId = "SUP-001", quantity = 30, unitPrice = 2, currency = "USD" },
                validation_results = new { isValid = true } }) });
        await db.SaveChangesAsync(); var service = new WorkflowDraftService(db);
        var first = await service.FinalizeAsync("WF-DRAFT"); var second = await service.FinalizeAsync("WF-DRAFT");
        Assert.Equal(first, second); Assert.Equal(2, await db.PurchaseOrders.CountAsync());
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
    }

    [Fact]
    public async Task BankEvidence_DoesNotPayOrDispatchUntilManagerVerification()
    {
        await using var db = Database(); var po = await Seed(db, PurchaseOrderStatus.Approved);
        po.BankSlipStatus = "SUBMITTED"; po.BankReferenceNumber = "REF-1"; po.Status = PurchaseOrderStatus.PaymentPending;
        await db.SaveChangesAsync();
        Assert.Empty(await db.PaymentTransactions.ToListAsync());
        var service = new PurchaseOrderService(db, new DummyStripeService(), new DummyEmailService(),
            new ConfigurationBuilder().Build(), NullLogger<PurchaseOrderService>.Instance);
        await service.VerifyBankSlipAsync(1, null); await service.VerifyBankSlipAsync(1, null);
        Assert.Equal("VERIFIED", po.BankSlipStatus);
        Assert.Single(await db.PaymentTransactions.ToListAsync());
        Assert.Equal(10, (await db.InventoryItems.SingleAsync()).StockLevel);
    }
}
