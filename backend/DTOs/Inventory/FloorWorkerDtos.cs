using System;

namespace backend.Dtos
{
    public class StockLevelDetailDto
    {
        public int Id { get; set; }
        public int RawMaterialId { get; set; }
        public string SkuCode { get; set; } = string.Empty;
        public string MaterialName { get; set; } = string.Empty;
        public decimal CurrentStock { get; set; }
        public decimal MinimumStock { get; set; }
        public decimal MaximumStock { get; set; }
        public decimal BurnRate { get; set; }
        public decimal DaysRemaining { get; set; }
        public string Status { get; set; } = "NORMAL"; // NORMAL, LOW, CRITICAL
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }

    public class InventoryHistoryItemDto
    {
        public DateTime Date { get; set; } = DateTime.UtcNow;
        public string TransactionType { get; set; } = string.Empty; // RECEIVED, CONSUMED, ADJUSTMENT
        public decimal Quantity { get; set; }
        public decimal PreviousStock { get; set; }
        public decimal NewStock { get; set; }
        public string Reason { get; set; } = string.Empty;
        public string User { get; set; } = "Floor Worker";
    }

    public class QrLookupResultDto
    {
        public int RollId { get; set; }
        public string RollIdentifier { get; set; } = string.Empty;
        public string BarcodeUrl { get; set; } = string.Empty;
        public int RawMaterialId { get; set; }
        public string SkuCode { get; set; } = string.Empty;
        public string MaterialName { get; set; } = string.Empty;
        public decimal InitialQuantity { get; set; }
        public decimal RemainingQuantity { get; set; }
        public string Status { get; set; } = "In Stock";
        public DateTime ReceivedDate { get; set; } = DateTime.UtcNow;
    }

    public class LowStockItemDto
    {
        public int MaterialId { get; set; }
        public string SkuCode { get; set; } = string.Empty;
        public string MaterialName { get; set; } = string.Empty;
        public decimal CurrentStock { get; set; }
        public decimal MinimumStock { get; set; }
        public decimal BurnRate { get; set; }
        public decimal DaysRemaining { get; set; }
        public bool LowStock { get; set; }
        public string Severity { get; set; } = "NORMAL";
        public string Reason { get; set; } = string.Empty;
    }

    public class TriggerReplenishmentDto
    {
        public string Objective { get; set; } = string.Empty;
        public string MaterialId { get; set; } = string.Empty;
        public decimal RequiredQuantity { get; set; } = 2000m;
    }
}

