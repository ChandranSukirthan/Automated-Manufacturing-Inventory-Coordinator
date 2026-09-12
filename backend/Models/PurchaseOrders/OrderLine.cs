using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    public class OrderLine
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        // ── Purchase Order ─────────────────────────────────────────────────────
        [Required]
        public int PurchaseOrderId { get; set; }

        [ForeignKey(nameof(PurchaseOrderId))]
        public PurchaseOrder PurchaseOrder { get; set; } = null!;

        // ── Raw Material (from Student 1's entity — no duplication) ────────────
        [Required]
        public int RawMaterialId { get; set; }

        [ForeignKey(nameof(RawMaterialId))]
        public RawMaterial RawMaterial { get; set; } = null!;

        // ── Line Details ───────────────────────────────────────────────────────
        [MaxLength(500)]
        public string Description { get; set; } = string.Empty;

        /// <summary>Quantity in the raw material's unit of measure (e.g., KG, metres).</summary>
        [Required]
        [Column(TypeName = "decimal(18,3)")]
        public decimal Quantity { get; set; }

        /// <summary>Price per unit in USD.</summary>
        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        /// <summary>Computed: Quantity × UnitPrice. Updated on every save.</summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalPrice { get; set; }

        // ── Audit ──────────────────────────────────────────────────────────────
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}

