using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.DTOs.PurchaseOrders
{
    // ── Order Line ──────────────────────────────────────────────────────────────

    public class OrderLineDto
    {
        [Required]
        public int RawMaterialId { get; set; }

        [MaxLength(500)]
        public string Description { get; set; } = string.Empty;

        [Required]
        [Range(0.001, double.MaxValue, ErrorMessage = "Quantity must be greater than zero.")]
        public decimal Quantity { get; set; }

        [Required]
        [Range(0.01, double.MaxValue, ErrorMessage = "Unit price must be greater than zero.")]
        public decimal UnitPrice { get; set; }
    }

    public class OrderLineResponseDto
    {
        public int Id { get; set; }
        public int RawMaterialId { get; set; }
        public string RawMaterialName { get; set; } = string.Empty;
        public string RawMaterialSku { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
    }

    // ── Purchase Order ──────────────────────────────────────────────────────────

    public class CreatePurchaseOrderDto
    {
        [Required]
        public int SupplierId { get; set; }

        [Required]
        [Range(0.01, double.MaxValue, ErrorMessage = "Budget limit must be greater than zero.")]
        public decimal BudgetLimit { get; set; }

        [MaxLength(1000)]
        public string? Notes { get; set; }

        [Required]
        [MinLength(1, ErrorMessage = "At least one order line is required.")]
        public List<OrderLineDto> Lines { get; set; } = new();
    }

    public class UpdatePurchaseOrderDto
    {
        [Required]
        public int SupplierId { get; set; }

        [Required]
        [Range(0.01, double.MaxValue)]
        public decimal BudgetLimit { get; set; }

        [MaxLength(1000)]
        public string? Notes { get; set; }

        [Required]
        [MinLength(1, ErrorMessage = "At least one order line is required.")]
        public List<OrderLineDto> Lines { get; set; } = new();
    }

    public class ApprovalActionDto
    {
        [MaxLength(1000)]
        public string? Notes { get; set; }
    }

    public class PurchaseOrderSummaryDto
    {
        public int Id { get; set; }
        public string PoNumber { get; set; } = string.Empty;
        public string SupplierName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal TotalCost { get; set; }
        public bool RequiresApproval { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class PurchaseOrderResponseDto
    {
        public int Id { get; set; }
        public string PoNumber { get; set; } = string.Empty;
        public int SupplierId { get; set; }
        public string SupplierName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal TotalCost { get; set; }
        public decimal BudgetLimit { get; set; }
        public decimal ApprovalThreshold { get; set; }
        public bool RequiresApproval { get; set; }
        public string? Notes { get; set; }
        public string? RejectionReason { get; set; }
        public string? ApprovedByName { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public string? StripePaymentIntentId { get; set; }
        public string? StripePaymentStatus { get; set; }
        public List<OrderLineResponseDto> OrderLines { get; set; } = new();
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}

