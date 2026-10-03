using System.Data;
using System.ComponentModel.DataAnnotations;
using backend.Models;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;
using Microsoft.EntityFrameworkCore;

namespace ManufacturingCoordinator.Services.PurchaseOrders;

public class ReceiveGoodsRequest
{
    [Required, MaxLength(100)] public string ReceiptKey { get; set; } = "";
    public int OrderLineId { get; set; }
    [Range(1, int.MaxValue)] public decimal Quantity { get; set; }
    [Required, MaxLength(120)] public string RollIdentifier { get; set; } = "";
    [Required, MaxLength(80)] public string BatchId { get; set; } = "";
}

public sealed class GoodsReceiptService(ApplicationDbContext db)
{
    public async Task<GoodsReceipt> ReceiveAsync(int poId, ReceiveGoodsRequest request, Guid? userId)
    {
        if (string.IsNullOrWhiteSpace(request.ReceiptKey) || string.IsNullOrWhiteSpace(request.RollIdentifier) ||
            string.IsNullOrWhiteSpace(request.BatchId) || request.Quantity <= 0 || request.Quantity != decimal.Truncate(request.Quantity))
            throw new InvalidOperationException("A receipt key, roll, batch and positive whole-unit quantity are required.");
        var key = request.ReceiptKey.Trim();
        var identifier = request.RollIdentifier.Trim().ToUpperInvariant();
        var existing = await db.GoodsReceipts.SingleOrDefaultAsync(r => r.ReceiptKey == key);
        if (existing != null)
        {
            if (existing.PurchaseOrderId != poId || existing.OrderLineId != request.OrderLineId ||
                existing.Quantity != request.Quantity || existing.RollIdentifier != identifier || existing.BatchId != request.BatchId.Trim())
                throw new InvalidOperationException("This receipt key was already used for a different delivery.");
            return existing;
        }
        await using var transaction = db.Database.IsRelational()
            ? await db.Database.BeginTransactionAsync(IsolationLevel.Serializable) : null;
        var po = await db.PurchaseOrders.Include(p => p.OrderLines).SingleOrDefaultAsync(p => p.Id == poId)
            ?? throw new KeyNotFoundException("Purchase order was not found.");
        if (po.Status is not (PurchaseOrderStatus.Sent or PurchaseOrderStatus.InTransit))
            throw new InvalidOperationException("Only a dispatched or in-transit order can be received.");
        var line = po.OrderLines.SingleOrDefault(l => l.Id == request.OrderLineId)
            ?? throw new InvalidOperationException("The order line does not belong to this purchase order.");
        var received = await db.GoodsReceipts.Where(r => r.OrderLineId == line.Id).SumAsync(r => r.Quantity);
        if (received + request.Quantity > line.Quantity)
            throw new InvalidOperationException("Received quantity exceeds the remaining ordered quantity.");
        if (await db.StockRolls.AnyAsync(r => r.RollIdentifier == identifier))
            throw new InvalidOperationException("This physical roll is already registered.");
        var material = await db.RawMaterials.FindAsync(line.RawMaterialId)
            ?? throw new InvalidOperationException("The ordered material was not found.");
        var item = await db.InventoryItems.SingleOrDefaultAsync(i => i.Sku == material.SkuCode)
            ?? throw new InvalidOperationException("Register the ordered SKU before receiving its rolls.");
        if (!await db.Batches.AnyAsync(b => b.Id == request.BatchId.Trim()))
        {
            if (!Enum.TryParse<ProductType>(material.Category, true, out var productType))
                throw new InvalidOperationException("Set a valid packaging category on this material before receiving a batch.");
            db.Batches.Add(new ManufacturingCoordinator.Models.Inventory.Batch { Id = request.BatchId.Trim(), ProductType = productType });
        }
        var receipt = new GoodsReceipt { PurchaseOrderId = poId, OrderLineId = line.Id, ReceiptKey = key,
            RollIdentifier = identifier, BatchId = request.BatchId.Trim(), Quantity = request.Quantity, ReceivedById = userId };
        var previous = item.StockLevel;
        item.StockLevel = checked(previous + decimal.ToInt32(request.Quantity));
        db.GoodsReceipts.Add(receipt);
        db.StockRolls.Add(new backend.Models.InventoryRoll { RawMaterialId = line.RawMaterialId,
            RollIdentifier = identifier, BatchId = receipt.BatchId, InitialQuantity = request.Quantity,
            CurrentQuantity = request.Quantity, Status = "In Stock",
            BarcodeUrl = $"/api/inventory/rolls/{Uri.EscapeDataString(identifier)}/qr" });
        db.InventoryMovements.Add(new InventoryMovement { RawMaterialId = line.RawMaterialId,
            RollIdentifier = identifier, TransactionType = "RECEIVED", Quantity = request.Quantity,
            PreviousStock = previous, NewStock = item.StockLevel, Reason = $"Goods receipt for {po.PoNumber}: {key}" });
        if (item.StockLevel > item.ReorderThreshold)
        {
            var alerts = await db.StockAlerts.Where(a => a.Sku == item.Sku &&
                (a.Status == "Pending" || a.Status == "Processing" || a.Status == "Acknowledged")).ToListAsync();
            foreach (var alert in alerts) alert.Status = "Resolved";
        }
        var receipts = await db.GoodsReceipts.Where(r => r.PurchaseOrderId == poId).ToListAsync();
        receipts.Add(receipt);
        var fullyReceived = po.OrderLines.All(l => receipts.Where(r => r.OrderLineId == l.Id).Sum(r => r.Quantity) == l.Quantity);
        po.Status = fullyReceived ? PurchaseOrderStatus.Delivered : PurchaseOrderStatus.InTransit;
        po.TrackingStatus = fullyReceived ? "Delivered" : "PartiallyReceived";
        po.ActualDeliveryDate = fullyReceived ? DateTime.UtcNow : null;
        po.UpdatedAt = DateTime.UtcNow;
        var workflows = await db.AgentWorkflows.Where(w => w.PurchaseOrderId == poId).ToListAsync();
        foreach (var workflow in workflows)
        {
            workflow.CurrentAgent = fullyReceived ? "Goods Receipt" : "Partial Delivery";
            workflow.Status = fullyReceived ? WorkflowStatus.Completed : WorkflowStatus.Running;
            workflow.CompletedAt = fullyReceived ? DateTime.UtcNow : null;
            workflow.FinalOutcome = fullyReceived ? $"All goods received for {po.PoNumber}. Stock updated from recorded receipts." : $"Partial delivery received for {po.PoNumber}; remaining quantities are open.";
        }
        await db.SaveChangesAsync();
        if (transaction != null) await transaction.CommitAsync();
        return receipt;
    }
}
