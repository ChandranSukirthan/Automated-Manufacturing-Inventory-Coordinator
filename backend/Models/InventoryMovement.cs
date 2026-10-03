namespace backend.Models;

public class InventoryMovement
{
    public long Id { get; set; }
    public int RawMaterialId { get; set; }
    public string RollIdentifier { get; set; } = "";
    public string TransactionType { get; set; } = "";
    public decimal Quantity { get; set; }
    public decimal PreviousStock { get; set; }
    public decimal NewStock { get; set; }
    public string Reason { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
