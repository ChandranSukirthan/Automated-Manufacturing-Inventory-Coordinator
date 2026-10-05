using System;

namespace backend.Dtos
{
    public class StockAlertResponseDto
    {
        public int Id { get; set; }
        public int AlertId => Id;
        public string Sku { get; set; } = string.Empty;
        public string PackagingType { get; set; } = string.Empty;
        public int QuantityRequested { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
        public DateTime CreatedAt => Timestamp;
        public string WorkerId { get; set; } = string.Empty;

        // Supply Chain Manager fields
        public int? MaterialId { get; set; }
        public string MaterialName { get; set; } = string.Empty;
        public decimal CurrentStock { get; set; }
        public decimal RequiredQuantity { get; set; }
        public decimal SafetyStock { get; set; }
        public decimal OpenPurchaseQuantity { get; set; }
        public decimal NetDeficit { get; set; }
        public decimal Shortage => NetDeficit;
        public string Severity { get; set; } = "Medium";
        public string Priority => Severity;
        public bool IsRead { get; set; }
    }
}
