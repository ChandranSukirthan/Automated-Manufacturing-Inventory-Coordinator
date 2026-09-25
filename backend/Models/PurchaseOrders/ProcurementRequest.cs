using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ManufacturingCoordinator.Models.Authentication;
using backend.Models;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    public enum ProcurementRequestStatus
    {
        Requested,
        Researching,
        RecommendationReady,
        DraftPoCreated,
        Failed,
        Completed
    }

    public class ProcurementRequest
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public int RawMaterialId { get; set; }

        [ForeignKey(nameof(RawMaterialId))]
        public RawMaterial RawMaterial { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string RequiredSpecification { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,3)")]
        public decimal ProductionRequirement { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal CurrentStock { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal SafetyStock { get; set; }

        [Column(TypeName = "decimal(18,3)")]
        public decimal ExistingOpenPoQuantity { get; set; }

        /// <summary>
        /// Deterministically computed:
        /// netRequiredQuantity = productionRequirement + safetyStock - currentStock - openPOQuantity
        /// </summary>
        [Column(TypeName = "decimal(18,3)")]
        public decimal CalculatedNetQuantity { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal MaximumBudget { get; set; }

        public DateTime RequiredByDate { get; set; }

        [MaxLength(500)]
        public string QualityRequirement { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? PreferredRegion { get; set; }

        public ProcurementRequestStatus Status { get; set; } = ProcurementRequestStatus.Requested;

        public int? RecommendedSupplierId { get; set; }

        [ForeignKey(nameof(RecommendedSupplierId))]
        public Supplier? RecommendedSupplier { get; set; }

        public int? GeneratedPurchaseOrderId { get; set; }

        [ForeignKey(nameof(GeneratedPurchaseOrderId))]
        public PurchaseOrder? GeneratedPurchaseOrder { get; set; }

        [MaxLength(1000)]
        public string? FailureReason { get; set; }

        [MaxLength(100)]
        public string? WorkflowId { get; set; }

        [MaxLength(200)]
        public string? MaterialName { get; set; }

        public Guid? CreatedById { get; set; }

        [ForeignKey(nameof(CreatedById))]
        public User? CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // ── Convenience Aliases for Flexible API Mapping ──────────────────────────
        [NotMapped]
        public int MaterialId
        {
            get => RawMaterialId;
            set => RawMaterialId = value;
        }

        [NotMapped]
        public string Specification
        {
            get => RequiredSpecification;
            set => RequiredSpecification = value;
        }

        [NotMapped]
        public decimal NetDeficit
        {
            get => CalculatedNetQuantity;
            set => CalculatedNetQuantity = value;
        }

        [NotMapped]
        public decimal OpenPOQuantity
        {
            get => ExistingOpenPoQuantity;
            set => ExistingOpenPoQuantity = value;
        }

        [NotMapped]
        public DateTime RequiredDeliveryDate
        {
            get => RequiredByDate;
            set => RequiredByDate = value;
        }

        // Navigation
        public ICollection<SupplierCandidate> Candidates { get; set; } = new List<SupplierCandidate>();
    }
}
