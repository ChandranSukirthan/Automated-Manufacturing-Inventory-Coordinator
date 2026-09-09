using System;
using System.ComponentModel.DataAnnotations;

namespace backend.Models
{
    public class StockAlert
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string Sku { get; set; } = string.Empty;

        [Required]
        public string PackagingType { get; set; } = string.Empty;

        public int QuantityRequested { get; set; }

        public string Status { get; set; } = "Pending";

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        public string WorkerId { get; set; } = string.Empty;
    }
}
