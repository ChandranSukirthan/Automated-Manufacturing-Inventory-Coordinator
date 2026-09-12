using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    /// <summary>
    /// Tracks supplier performance metrics: orders, spending, lead time, delivery performance, and rejection rate.
    /// </summary>
    public class SupplierPerformance
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public int SupplierId { get; set; }

        [ForeignKey(nameof(SupplierId))]
        public Supplier Supplier { get; set; } = null!;

        public int OrderCount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalSpending { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal AverageOrderValue { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal AverageLeadTime { get; set; }

        [Column(TypeName = "decimal(5,2)")]
        public decimal DeliveryPerformanceRate { get; set; } = 100m;

        [Column(TypeName = "decimal(5,2)")]
        public decimal RejectionRate { get; set; } = 0m;

        public DateTime CalculatedAt { get; set; } = DateTime.UtcNow;
    }
}

