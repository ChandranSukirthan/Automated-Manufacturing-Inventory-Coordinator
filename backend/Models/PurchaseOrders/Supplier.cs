using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ManufacturingCoordinator.Models.PurchaseOrders
{
    public class Supplier
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string SupplierCode { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(256)]
        [EmailAddress]
        public string ContactEmail { get; set; } = string.Empty;

        [MaxLength(30)]
        public string ContactPhone { get; set; } = string.Empty;

        [MaxLength(500)]
        public string Address { get; set; } = string.Empty;

        [MaxLength(50)]
        public string PaymentTerms { get; set; } = "Net 30";

        public int LeadTimeDays { get; set; } = 7;

        /// <summary>Soft-delete flag — inactive suppliers cannot receive new POs.</summary>
        public bool IsActive { get; set; } = true;

        [NotMapped]
        public int SupplierId
        {
            get => Id;
            set => Id = value;
        }

        [NotMapped]
        public string SupplierName
        {
            get => Name;
            set => Name = value;
        }

        [NotMapped]
        public string Phone
        {
            get => ContactPhone;
            set => ContactPhone = value;
        }

        [NotMapped]
        public string Status
        {
            get => IsActive ? "Active" : "Inactive";
            set => IsActive = string.Equals(value, "Active", StringComparison.OrdinalIgnoreCase);
        }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<PurchaseOrder> PurchaseOrders { get; set; } = new List<PurchaseOrder>();
    }
}

