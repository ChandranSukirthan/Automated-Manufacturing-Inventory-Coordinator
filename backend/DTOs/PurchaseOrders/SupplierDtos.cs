using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.DTOs.PurchaseOrders
{
    public class CreateSupplierDto
    {
        [MaxLength(50)]
        public string? SupplierCode { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        public string SupplierName
        {
            get => Name;
            set => Name = value;
        }

        [Required]
        [EmailAddress]
        [MaxLength(256)]
        public string ContactEmail { get; set; } = string.Empty;

        [MaxLength(30)]
        public string ContactPhone { get; set; } = string.Empty;

        public string Phone
        {
            get => ContactPhone;
            set => ContactPhone = value;
        }

        [MaxLength(500)]
        public string Address { get; set; } = string.Empty;

        [MaxLength(50)]
        public string PaymentTerms { get; set; } = "Net 30";

        [Range(1, 365, ErrorMessage = "Lead time must be between 1 and 365 days.")]
        public int LeadTimeDays { get; set; } = 7;
    }

    public class UpdateSupplierDto
    {
        [MaxLength(50)]
        public string? SupplierCode { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        public string SupplierName
        {
            get => Name;
            set => Name = value;
        }

        [Required]
        [EmailAddress]
        [MaxLength(256)]
        public string ContactEmail { get; set; } = string.Empty;

        [MaxLength(30)]
        public string ContactPhone { get; set; } = string.Empty;

        public string Phone
        {
            get => ContactPhone;
            set => ContactPhone = value;
        }

        [MaxLength(500)]
        public string Address { get; set; } = string.Empty;

        [MaxLength(50)]
        public string PaymentTerms { get; set; } = "Net 30";

        [Range(1, 365, ErrorMessage = "Lead time must be between 1 and 365 days.")]
        public int LeadTimeDays { get; set; } = 7;

        public bool IsActive { get; set; } = true;

        public string Status
        {
            get => IsActive ? "Active" : "Inactive";
            set => IsActive = string.Equals(value, "Active", StringComparison.OrdinalIgnoreCase);
        }
    }

    public class SupplierResponseDto
    {
        public int Id { get; set; }
        public int SupplierId => Id;
        public string SupplierCode { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string SupplierName => Name;
        public string ContactEmail { get; set; } = string.Empty;
        public string ContactPhone { get; set; } = string.Empty;
        public string Phone => ContactPhone;
        public string Address { get; set; } = string.Empty;
        public string PaymentTerms { get; set; } = "Net 30";
        public int LeadTimeDays { get; set; } = 7;
        public bool IsActive { get; set; }
        public string Status => IsActive ? "Active" : "Inactive";
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class SupplierPerformanceDto
    {
        public int SupplierId { get; set; }
        public string SupplierCode { get; set; } = string.Empty;
        public string SupplierName { get; set; } = string.Empty;
        public int OrderCount { get; set; }
        public decimal TotalSpending { get; set; }
        public decimal AverageOrderValue { get; set; }
        public decimal AverageLeadTime { get; set; }
        public decimal DeliveryPerformance { get; set; } = 100m;
        public decimal RejectionRate { get; set; } = 0m;
    }

    public class SupplierAnalyticsDto
    {
        public int TotalSuppliers { get; set; }
        public int ActiveSuppliers { get; set; }
        public int TotalOrders { get; set; }
        public decimal TotalSpending { get; set; }
        public decimal AverageOrderValue { get; set; }
        public decimal AverageLeadTimeDays { get; set; }
        public List<SupplierPerformanceDto> Suppliers { get; set; } = new();
    }
}
