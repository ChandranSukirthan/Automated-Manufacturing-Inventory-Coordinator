using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

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

        // ── Student 2: Supply Chain Manager Procurement Extensions ─────────────

        [NotMapped]
        public int AlertId => Id;

        public int? MaterialId { get; set; }

        [MaxLength(200)]
        public string? MaterialName { get; set; }

        public decimal CurrentStock { get; set; }

        public decimal RequiredQuantity { get; set; }

        public decimal SafetyStock { get; set; }

        public decimal OpenPurchaseQuantity { get; set; }

        /// <summary>
        /// Deterministically computed:
        /// NetDeficit = (RequiredQuantity + SafetyStock) - (CurrentStock + OpenPurchaseQuantity)
        /// Calculated by ASP.NET Core, never by LLM.
        /// </summary>
        public decimal NetDeficit { get; set; }

        [MaxLength(50)]
        public string Severity { get; set; } = "Medium";

        public bool IsRead { get; set; } = false;

        [NotMapped]
        public DateTime CreatedAt
        {
            get => Timestamp;
            set => Timestamp = value;
        }
    }
}
