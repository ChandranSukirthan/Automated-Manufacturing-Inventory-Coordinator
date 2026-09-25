using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace ManufacturingCoordinator.DTOs.PurchaseOrders
{
    public class CreateProcurementRequestDto
    {
        [Required]
        public int RawMaterialId { get; set; }

        public int MaterialId
        {
            get => RawMaterialId;
            set => RawMaterialId = value;
        }

        [Required]
        [MaxLength(200)]
        public string RequiredSpecification { get; set; } = string.Empty;

        [Required]
        [Range(0.001, double.MaxValue, ErrorMessage = "Production requirement must be positive.")]
        public decimal ProductionRequirement { get; set; }

        [Range(0, double.MaxValue)]
        public decimal CurrentStock { get; set; }

        [Range(0, double.MaxValue)]
        public decimal SafetyStock { get; set; }

        [Range(0, double.MaxValue)]
        public decimal ExistingOpenPoQuantity { get; set; }

        [Required]
        [Range(0.01, double.MaxValue, ErrorMessage = "Maximum budget must be greater than zero.")]
        public decimal MaximumBudget { get; set; }

        [Required]
        public DateTime RequiredByDate { get; set; }

        [MaxLength(500)]
        public string QualityRequirement { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? PreferredRegion { get; set; }
    }

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
        public string SupplierStatus { get; set; } = "UNVERIFIED";
        public decimal ConfidenceScore { get; set; }
        public string? SourceUrl { get; set; }
        public bool IsValidated { get; set; }
        public string? ValidationRemarks { get; set; }
        public decimal RecommendedOrderQuantity { get; set; }
        public decimal TotalCost { get; set; }
        public DateTime CreatedAt { get; set; }
    }

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

    public class ProcurementResponseDto
    {
        public int Id { get; set; }
        public int RawMaterialId { get; set; }
        public string RawMaterialName { get; set; } = string.Empty;
        public string RawMaterialSku { get; set; } = string.Empty;
        public string RequiredSpecification { get; set; } = string.Empty;
        public decimal ProductionRequirement { get; set; }
        public decimal CurrentStock { get; set; }
        public decimal SafetyStock { get; set; }
        public decimal ExistingOpenPoQuantity { get; set; }
        public decimal CalculatedNetQuantity { get; set; }
        public decimal MaximumBudget { get; set; }
        public DateTime RequiredByDate { get; set; }
        public string QualityRequirement { get; set; } = string.Empty;
        public string? PreferredRegion { get; set; }
        public string Status { get; set; } = string.Empty;
        public int? RecommendedSupplierId { get; set; }
        public string? RecommendedSupplierName { get; set; }
        public int? GeneratedPurchaseOrderId { get; set; }
        public string? GeneratedPoNumber { get; set; }
        public string? FailureReason { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<SupplierCandidateDto> Candidates { get; set; } = new();
    }

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
}
