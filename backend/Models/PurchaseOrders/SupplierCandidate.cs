using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    public class SupplierCandidate
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public int ProcurementRequestId { get; set; }

        [ForeignKey(nameof(ProcurementRequestId))]
        public ProcurementRequest ProcurementRequest { get; set; } = null!;

        public int? SupplierId { get; set; }

        [ForeignKey(nameof(SupplierId))]
        public Supplier? Supplier { get; set; }

        [Required]
        [MaxLength(200)]
        public string SupplierName { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string MaterialName { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [Column(TypeName = "decimal(18,3)")]
        public decimal MinimumOrderQuantity { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal PackSize { get; set; } = 1m;

        public int LeadTimeDays { get; set; }

        [MaxLength(500)]
        public string QualityEvidence { get; set; } = string.Empty;

        /// <summary>
        /// Stock availability status reported by supplier (e.g. "In Stock", "Limited", "Pre-order").
        /// </summary>
        [MaxLength(100)]
        public string Availability { get; set; } = "In Stock";

        /// <summary>
        /// "APPROVED", "UNVERIFIED", or "BLOCKED".
        /// Candidates found online are UNVERIFIED until reviewed by Supply Chain Manager.
        /// </summary>
        [Required]
        [MaxLength(50)]
        public string SupplierStatus { get; set; } = "UNVERIFIED";

        [Column(TypeName = "decimal(5,2)")]
        public decimal ConfidenceScore { get; set; }

        [MaxLength(500)]
        public string? SourceUrl { get; set; }

        public bool IsValidated { get; set; }

        [MaxLength(1000)]
        public string? ValidationRemarks { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal RecommendedOrderQuantity { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCost { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
