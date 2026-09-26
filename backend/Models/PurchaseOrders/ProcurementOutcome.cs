using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    /// <summary>
    /// Student 2: Procurement History & Structured Outcome Dataset.
    /// Captures end-to-end procurement cycle telemetry as raw training and evaluation
    /// data for future learning-based procurement and supplier ranking components.
    /// </summary>
    public class ProcurementOutcome
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [MaxLength(200)]
        public string Material { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,3)")]
        public decimal RequestedQuantity { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal RecommendedQuantity { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal FinalOrderedQuantity { get; set; }

        [Required]
        [MaxLength(200)]
        public string RecommendedSupplier { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string SelectedSupplier { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,2)")]
        public decimal EstimatedPrice { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal FinalPrice { get; set; }

        public int EstimatedLeadTime { get; set; }

        public int ActualLeadTime { get; set; }

        [MaxLength(1000)]
        public string QualityEvidence { get; set; } = string.Empty;

        [MaxLength(100)]
        public string SupplierVerification { get; set; } = "VERIFIED";

        [Required]
        [MaxLength(100)]
        public string ManagerDecision { get; set; } = "Approved";

        [MaxLength(1000)]
        public string? ManagerRevision { get; set; }

        public bool ProcurementSuccess { get; set; } = true;

        public bool PaymentSuccess { get; set; } = true;

        public bool DeliverySuccess { get; set; } = false;

        [MaxLength(500)]
        public string? QualityOutcome { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? CompletedAt { get; set; }

        // Traceability references
        public int? PurchaseOrderId { get; set; }
        public int? ProcurementRequestId { get; set; }
    }
}
