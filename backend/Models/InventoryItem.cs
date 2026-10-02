using System.ComponentModel.DataAnnotations;

namespace backend.Models
{
    public class InventoryItem
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string Sku { get; set; } = string.Empty;

        [Required]
        public string Name { get; set; } = string.Empty;

        public string Category { get; set; } = string.Empty; // e.g., 'BoxPouch', 'Bottle'

        // Kept alongside the legacy display fields so every SKU can be traced
        // back to its database-backed packaging type and raw material.
        public int? PackagingTypeId { get; set; }
        public int? RawMaterialId { get; set; }
        public int? SkuNumber { get; set; }

        public int StockLevel { get; set; }

        public int ReorderThreshold { get; set; }
    }
}
