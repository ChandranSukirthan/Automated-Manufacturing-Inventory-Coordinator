using System;
using System.Collections.Generic;

namespace backend.Models
{
    public class RawMaterial
    {
        public int Id { get; set; }
        public string SkuCode { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;

        // The material portion of an SKU, e.g. LAM in BP-LAM-001. This is
        // assigned by the catalogue and is never typed by a floor worker.
        public string MaterialCode { get; set; } = string.Empty;
        public int PackagingTypeId { get; set; }
        [System.Text.Json.Serialization.JsonIgnore]
        public PackagingType? PackagingType { get; set; }
        
        // E.g., meters, kg, units
        public string UnitOfMeasure { get; set; } = string.Empty; 
        
        // Threshold for low stock alerts
        public decimal ReorderThreshold { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public ICollection<InventoryRoll> InventoryRolls { get; set; } = new List<InventoryRoll>();
        public ICollection<StockLevel> StockLevels { get; set; } = new List<StockLevel>();
    }
}

