using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ManufacturingCoordinator.Models.Authentication;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    /// <summary>
    /// Audit log and approval history for purchase orders.
    /// Tracks all state changes, manager actions, payment and dispatch events.
    /// </summary>
    public class PurchaseOrderApproval
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public int PurchaseOrderId { get; set; }

        [ForeignKey(nameof(PurchaseOrderId))]
        public PurchaseOrder PurchaseOrder { get; set; } = null!;

        [Required]
        [MaxLength(100)]
        public string Action { get; set; } = string.Empty;

        public Guid? UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        public User? User { get; set; }

        [MaxLength(150)]
        public string? UserName { get; set; }

        [MaxLength(1000)]
        public string? Notes { get; set; }

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}

