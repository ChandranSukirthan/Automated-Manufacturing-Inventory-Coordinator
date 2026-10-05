using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.Models.PurchaseOrders;

public class SupplierMaterialQuote
{
    public int Id { get; set; }
    public int SupplierId { get; set; }
    public int RawMaterialId { get; set; }
    [Range(0.01, double.MaxValue)] public decimal UnitPrice { get; set; }
    [Range(0, double.MaxValue)] public decimal MinimumOrderQuantity { get; set; }
    [Range(1, double.MaxValue)] public decimal PackSize { get; set; } = 1;
    [Range(0, double.MaxValue)] public decimal AvailableQuantity { get; set; }
    [Range(0, 3650)] public int LeadTimeDays { get; set; }
    [Required, MaxLength(500)] public string QualityEvidence { get; set; } = "";
    [Required, MaxLength(10)] public string Currency { get; set; } = "LKR";
    public bool IsActive { get; set; } = true;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
