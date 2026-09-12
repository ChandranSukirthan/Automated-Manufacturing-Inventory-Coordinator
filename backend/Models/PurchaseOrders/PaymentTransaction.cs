using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    /// <summary>
    /// Stores Stripe sandbox payment transaction records.
    /// Strictly excludes card details or secrets.
    /// </summary>
    public class PaymentTransaction
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public int PurchaseOrderId { get; set; }

        [ForeignKey(nameof(PurchaseOrderId))]
        public PurchaseOrder PurchaseOrder { get; set; } = null!;

        [MaxLength(200)]
        public string? TransactionId { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "usd";

        [Required]
        [MaxLength(50)]
        public string PaymentStatus { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? FailureReason { get; set; }

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}
