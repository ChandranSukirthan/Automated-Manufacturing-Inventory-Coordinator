using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    public class PurchaseOrder
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        /// <summary>Auto-generated unique identifier, e.g. PO-2024-0001</summary>
        [Required]
        [MaxLength(50)]
        public string PoNumber { get; set; } = string.Empty;

        // ── Supplier ──────────────────────────────────────────────────────────
        [Required]
        public int SupplierId { get; set; }

        [ForeignKey(nameof(SupplierId))]
        public Supplier Supplier { get; set; } = null!;

        // ── Status & Workflow ─────────────────────────────────────────────────
        public PurchaseOrderStatus Status { get; set; } = PurchaseOrderStatus.Draft;

        [MaxLength(1000)]
        public string? Notes { get; set; }

        [MaxLength(1000)]
        public string? RejectionReason { get; set; }

        // ── Business Rules ────────────────────────────────────────────────────
        /// <summary>Computed from sum of all OrderLine.TotalPrice. Updated on every save.</summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCost { get; set; }

        [NotMapped]
        public decimal TotalAmount
        {
            get => TotalCost;
            set => TotalCost = value;
        }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        /// <summary>Maximum allowed spend for this order.</summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal BudgetLimit { get; set; }

        /// <summary>Threshold above which manager approval is mandatory.</summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal ApprovalThreshold { get; set; } = 5000m;

        /// <summary>Set to true by checkApprovalThreshold() when TotalCost > ApprovalThreshold.</summary>
        public bool RequiresApproval { get; set; }

        // ── Creator & Approval ─────────────────────────────────────────────────
        public Guid? CreatedById { get; set; }

        [ForeignKey(nameof(CreatedById))]
        public User? CreatedBy { get; set; }

        public Guid? ApprovedById { get; set; }

        [ForeignKey(nameof(ApprovedById))]
        public User? ApprovedBy { get; set; }

        public DateTime? ApprovedAt { get; set; }

        // ── AI Procurement Link ───────────────────────────────────────────────
        /// <summary>Links this PO back to the AI ProcurementRequest that generated it.</summary>
        public int? ProcurementRequestId { get; set; }

        // ── Delivery / Tracking ───────────────────────────────────────────────
        /// <summary>
        /// Granular tracking status beyond PO workflow status.
        /// Values: Draft, PendingApproval, Approved, PaymentPending, Paid,
        ///         SupplierNotified, Ordered, InTransit, Delivered, Completed
        /// </summary>
        [MaxLength(50)]
        public string TrackingStatus { get; set; } = "Draft";

        public DateTime? ExpectedDeliveryDate { get; set; }
        public DateTime? ActualDeliveryDate { get; set; }

        [MaxLength(200)]
        public string? TrackingNumber { get; set; }

        [MaxLength(500)]
        public string? DeliveryRemarks { get; set; }

        // ── Stripe Payment ────────────────────────────────────────────────────
        [MaxLength(200)]
        public string? StripePaymentIntentId { get; set; }

        [MaxLength(50)]
        public string? StripePaymentStatus { get; set; }

        [MaxLength(500)]
        public string? PaymentFailureReason { get; set; }

        // ── Bank Slip Payment ─────────────────────────────────────────────────
        [MaxLength(500)]
        public string? BankSlipUrl { get; set; }

        [MaxLength(100)]
        public string? BankReferenceNumber { get; set; }

        [MaxLength(50)]
        public string? BankSlipStatus { get; set; }

        public DateTime? BankSlipUploadedAt { get; set; }

        // ── SendGrid Email ────────────────────────────────────────────────────
        [MaxLength(200)]
        public string? SendGridMessageId { get; set; }

        [MaxLength(50)]
        public string? EmailStatus { get; set; }

        public DateTime? EmailSentAt { get; set; }

        [MaxLength(500)]
        public string? EmailFailureReason { get; set; }

        // ── Audit ─────────────────────────────────────────────────────────────
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<OrderLine> OrderLines { get; set; } = new List<OrderLine>();
        public ICollection<PurchaseOrderApproval> Approvals { get; set; } = new List<PurchaseOrderApproval>();
        public ICollection<PaymentTransaction> Transactions { get; set; } = new List<PaymentTransaction>();
    }
}

