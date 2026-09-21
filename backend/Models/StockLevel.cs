using System;
using System.Text.Json.Serialization;

namespace backend.Models
{
    public class StockLevel
    {
        public int Id { get; set; }
        
        // Foreign Key
        public int RawMaterialId { get; set; }
        
        [JsonIgnore]
        public RawMaterial? RawMaterial { get; set; }
        
        public decimal TotalQuantity { get; set; }
        
        public string Notes { get; set; } = string.Empty;
        
        public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
    }
}

