namespace ManufacturingCoordinator.Models.PurchaseOrders;

public class GoodsReceipt
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public int PurchaseOrderId { get; set; }
    public int OrderLineId { get; set; }
    public string ReceiptKey { get; set; } = "";
    public string RollIdentifier { get; set; } = "";
    public string BatchId { get; set; } = "";
    public decimal Quantity { get; set; }
    public Guid? ReceivedById { get; set; }
    public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
}
