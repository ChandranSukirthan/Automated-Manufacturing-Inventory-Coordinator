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

        public int StockLevel { get; set; }

        public int ReorderThreshold { get; set; }
    }
}
