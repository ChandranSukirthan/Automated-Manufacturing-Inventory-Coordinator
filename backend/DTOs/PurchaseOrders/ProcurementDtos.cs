using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace ManufacturingCoordinator.DTOs.PurchaseOrders
{
    // ── Procurement Request Input ─────────────────────────────────────────────────

    public class CreateProcurementRequestDto
    {
        [Required]
        public int RawMaterialId { get; set; }

        /// <summary>Alias for RawMaterialId.</summary>
        public int MaterialId
        {
            get => RawMaterialId;
            set => RawMaterialId = value;
        }

        [Required]
        [MaxLength(200)]
        public string RequiredSpecification { get; set; } = string.Empty;

        /// <summary>Alias for RequiredSpecification.</summary>
        public string Specification
        {
            get => RequiredSpecification;
            set => RequiredSpecification = value;
        }

        [Required]
        [Range(0.001, double.MaxValue, ErrorMessage = "Production requirement must be positive.")]
        public decimal ProductionRequirement { get; set; }

        [Range(0, double.MaxValue)]
        public decimal CurrentStock { get; set; }

        [Range(0, double.MaxValue)]
        public decimal SafetyStock { get; set; }

        [Range(0, double.MaxValue)]
        public decimal ExistingOpenPoQuantity { get; set; }

        /// <summary>Alias for ExistingOpenPoQuantity.</summary>
        public decimal OpenPOQuantity
        {
            get => ExistingOpenPoQuantity;
            set => ExistingOpenPoQuantity = value;
        }

        [Required]
        [Range(0.01, double.MaxValue, ErrorMessage = "Maximum budget must be greater than zero.")]
        public decimal MaximumBudget { get; set; }

        [Required]
        public DateTime RequiredByDate { get; set; }

        /// <summary>Alias for RequiredByDate.</summary>
        public DateTime RequiredDeliveryDate
        {
            get => RequiredByDate;
            set => RequiredByDate = value;
        }

        [MaxLength(500)]
        public string QualityRequirement { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? PreferredRegion { get; set; }
    }

    // ── Supplier Candidate ────────────────────────────────────────────────────────

    public class SupplierCandidateDto
    {
        public int Id { get; set; }
        public int? SupplierId { get; set; }
        public string SupplierName { get; set; } = string.Empty;
        public string MaterialName { get; set; } = string.Empty;
        public decimal UnitPrice { get; set; }
        public string Currency { get; set; } = "USD";
        public decimal MinimumOrderQuantity { get; set; }
        public decimal PackSize { get; set; } = 1m;
        public int LeadTimeDays { get; set; }
        public string QualityEvidence { get; set; } = string.Empty;
        public string Availability { get; set; } = "In Stock";

        /// <summary>APPROVED, UNVERIFIED, or BLOCKED.</summary>
        public string SupplierStatus { get; set; } = "UNVERIFIED";
        public decimal ConfidenceScore { get; set; }
        public string? SourceUrl { get; set; }
        public bool IsValidated { get; set; }
        public string? ValidationRemarks { get; set; }
        public decimal RecommendedOrderQuantity { get; set; }
        public decimal TotalCost { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    // ── Candidate Validation Result ───────────────────────────────────────────────

    public class CandidateValidationResultDto
    {
        public bool IsValid { get; set; }
        public bool SpecificationMatches { get; set; }
        public bool SupplierApproved { get; set; }
        public bool QualityEvidenceSufficient { get; set; }
        public bool MoqRespected { get; set; }
        public bool LeadTimeFeasible { get; set; }
        public bool BudgetRespected { get; set; }
        public decimal RecommendedOrderQuantity { get; set; }
        public decimal TotalCost { get; set; }
        public List<string> ValidationMessages { get; set; } = new();
    }

    // ── Procurement Response ──────────────────────────────────────────────────────

    public class ProcurementResponseDto
    {
        public int Id { get; set; }
        public int RawMaterialId { get; set; }
        public string RawMaterialName { get; set; } = string.Empty;
        public string RawMaterialSku { get; set; } = string.Empty;
        public string RequiredSpecification { get; set; } = string.Empty;

        /// <summary>Alias for RequiredSpecification.</summary>
        public string Specification => RequiredSpecification;

        public string? MaterialName { get; set; }
        public decimal ProductionRequirement { get; set; }
        public decimal CurrentStock { get; set; }
        public decimal SafetyStock { get; set; }
        public decimal ExistingOpenPoQuantity { get; set; }

        /// <summary>Authoritative calculated net deficit stored by ASP.NET Core.</summary>
        public decimal CalculatedNetQuantity { get; set; }

        /// <summary>Alias for CalculatedNetQuantity.</summary>
        public decimal NetDeficit => CalculatedNetQuantity;

        public decimal MaximumBudget { get; set; }
        public DateTime RequiredByDate { get; set; }

        /// <summary>Alias for RequiredByDate.</summary>
        public DateTime RequiredDeliveryDate => RequiredByDate;

        public string QualityRequirement { get; set; } = string.Empty;
        public string? PreferredRegion { get; set; }
        public string Status { get; set; } = string.Empty;

        /// <summary>LangGraph Workflow ID (internal). NOT exposed to React/Flutter directly; only used for backend audit.</summary>
        public string? WorkflowId { get; set; }

        public int? RecommendedSupplierId { get; set; }
        public string? RecommendedSupplierName { get; set; }
        public int? GeneratedPurchaseOrderId { get; set; }
        public string? GeneratedPoNumber { get; set; }
        public string? FailureReason { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<SupplierCandidateDto> Candidates { get; set; } = new();
    }

    // ── AI Recommendation Summary (for React/Flutter display) ────────────────────

    public class ProcurementRecommendationDto
    {
        public int ProcurementRequestId { get; set; }
        public string Status { get; set; } = string.Empty;

        /// <summary>LangGraph workflow ID stored internally for audit trail.</summary>
        public string? WorkflowId { get; set; }

        /// <summary>The best-scored and validated supplier candidate.</summary>
        public SupplierCandidateDto? RecommendedCandidate { get; set; }

        public int? GeneratedPurchaseOrderId { get; set; }
        public string? GeneratedPoNumber { get; set; }

        /// <summary>Human-readable AI rationale for the recommendation.</summary>
        public string? Rationale { get; set; }

        /// <summary>True when the recommended candidate is UNVERIFIED and requires manager onboarding before a Draft PO can be generated.</summary>
        public bool RequiresSupplierVerification { get; set; }

        /// <summary>True when PO has been created and is pending Supply Chain Manager approval.</summary>
        public bool RequiresHumanApproval { get; set; }

        public string? FailureReason { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    // ── Status Tracking DTO (for Flutter & React real-time monitoring) ────────────

    public class ProcurementStatusTrackingDto
    {
        public int ProcurementId { get; set; }
        public string MaterialName { get; set; } = string.Empty;
        public string RequiredSpecification { get; set; } = string.Empty;
        public decimal NetDeficit { get; set; }
        public string ProcurementStatus { get; set; } = string.Empty;

        /// <summary>Internal LangGraph workflow reference for audit.</summary>
        public string? WorkflowId { get; set; }

        public int? PurchaseOrderId { get; set; }
        public string? PurchaseOrderNumber { get; set; }

        /// <summary>Draft, PendingApproval, Approved, Rejected, RevisionRequested, Payment, Sent.</summary>
        public string? PurchaseOrderStatus { get; set; }

        /// <summary>Stripe payment state: Pending, Processing, Paid, Failed.</summary>
        public string? PaymentStatus { get; set; }

        /// <summary>SendGrid email delivery state: NotSent, Sent, Delivered, Failed.</summary>
        public string? SupplierNotificationStatus { get; set; }

        /// <summary>Name and status of the recommended/selected supplier.</summary>
        public string? SupplierName { get; set; }
        public string? SupplierStatus { get; set; }

        public decimal? RecommendedQuantity { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? TotalCost { get; set; }
        public string? QualityEvidence { get; set; }
        public int? LeadTimeDays { get; set; }
        public string? Availability { get; set; }

        public bool RequiresSupplierVerification { get; set; }
        public bool RequiresHumanApproval { get; set; }

        public DateTime LastUpdated { get; set; }
    }

    // ── Verify & Onboard Supplier Candidate ──────────────────────────────────────

    public class VerifySupplierCandidateDto
    {
        [Required]
        [MaxLength(200)]
        public string SupplierName { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        public string ContactEmail { get; set; } = string.Empty;

        [MaxLength(30)]
        public string? ContactPhone { get; set; }

        [MaxLength(500)]
        public string? Address { get; set; }

        [MaxLength(50)]
        public string PaymentTerms { get; set; } = "Net 30";

        public int LeadTimeDays { get; set; } = 7;
    }

    // ── Verify Existing Supplier (by SupplierID) ──────────────────────────────────

    public class VerifySupplierDto
    {
        [MaxLength(200)]
        public string? Notes { get; set; }
    }
}
