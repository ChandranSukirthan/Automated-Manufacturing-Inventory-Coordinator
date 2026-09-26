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
        /// ASP.NET Core is the authoritative calculator. AI does NOT compute this.
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

        /// <summary>LangGraph Workflow ID returned by the Python FastAPI service.</summary>
        [MaxLength(100)]
        public string? WorkflowId { get; set; }

        /// <summary>Human-readable material name stored for fast display without joins.</summary>
        [MaxLength(200)]
        public string? MaterialName { get; set; }

        public int? RecommendedSupplierId { get; set; }

        [ForeignKey(nameof(RecommendedSupplierId))]
        public Supplier? RecommendedSupplier { get; set; }

        public int? GeneratedPurchaseOrderId { get; set; }

        [ForeignKey(nameof(GeneratedPurchaseOrderId))]
        public PurchaseOrder? GeneratedPurchaseOrder { get; set; }

        [MaxLength(1000)]
        public string? FailureReason { get; set; }

        public Guid? CreatedById { get; set; }

        [ForeignKey(nameof(CreatedById))]
        public User? CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(50)]
        public string Priority { get; set; } = "Normal";

        // ── Convenience Aliases for Flexible API Mapping ──────────────────────────

        /// <summary>Alias for RawMaterialId.</summary>
        [NotMapped]
        public int MaterialId
        {
            get => RawMaterialId;
            set => RawMaterialId = value;
        }

        /// <summary>Alias for RequiredSpecification.</summary>
        [NotMapped]
        public string Specification
        {
            get => RequiredSpecification;
            set => RequiredSpecification = value;
        }

        /// <summary>Alias for ProductionRequirement.</summary>
        [NotMapped]
        public decimal RequiredQuantity
        {
            get => ProductionRequirement;
            set => ProductionRequirement = value;
        }

        /// <summary>Alias for CalculatedNetQuantity — the authoritative deficit.</summary>
        [NotMapped]
        public decimal NetDeficit
        {
            get => CalculatedNetQuantity;
            set => CalculatedNetQuantity = value;
        }

        /// <summary>Alias for ExistingOpenPoQuantity.</summary>
        [NotMapped]
        public decimal OpenPOQuantity
        {
            get => ExistingOpenPoQuantity;
            set => ExistingOpenPoQuantity = value;
        }

        /// <summary>Alias for ExistingOpenPoQuantity.</summary>
        [NotMapped]
        public decimal OpenPurchaseQuantity
        {
            get => ExistingOpenPoQuantity;
            set => ExistingOpenPoQuantity = value;
        }

        /// <summary>Alias for MaximumBudget.</summary>
        [NotMapped]
        public decimal BudgetLimit
        {
            get => MaximumBudget;
            set => MaximumBudget = value;
        }

        /// <summary>Alias for RequiredByDate.</summary>
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
