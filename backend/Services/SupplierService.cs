using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public class SupplierService : ISupplierService
    {
        private readonly ApplicationDbContext _context;

        public SupplierService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<SupplierResponseDto>> GetAllAsync()
        {
            return await _context.Suppliers
                .OrderBy(s => s.Name)
                .Select(s => MapToDto(s))
                .ToListAsync();
        }

        public async Task<SupplierResponseDto?> GetByIdAsync(int id)
        {
            var supplier = await _context.Suppliers.FindAsync(id);
            return supplier is null ? null : MapToDto(supplier);
        }

        public async Task<SupplierResponseDto> CreateAsync(CreateSupplierDto dto)
        {
            var supplierCode = string.IsNullOrWhiteSpace(dto.SupplierCode)
                ? await GenerateSupplierCodeAsync()
                : dto.SupplierCode.Trim().ToUpperInvariant();

            // Validate unique supplier code
            var codeExists = await _context.Suppliers
                .AnyAsync(s => s.SupplierCode == supplierCode);
            if (codeExists)
                throw new InvalidOperationException($"Supplier code '{supplierCode}' is already in use.");

            // Validate unique email
            var emailClean = dto.ContactEmail.Trim().ToLowerInvariant();
            var emailExists = await _context.Suppliers
                .AnyAsync(s => s.ContactEmail == emailClean);
            if (emailExists)
                throw new InvalidOperationException($"Supplier with email '{emailClean}' already exists.");

            var supplier = new Supplier
            {
                SupplierCode = supplierCode,
                Name = dto.Name.Trim(),
                ContactEmail = emailClean,
                ContactPhone = dto.ContactPhone?.Trim() ?? string.Empty,
                Address = dto.Address?.Trim() ?? string.Empty,
                PaymentTerms = string.IsNullOrWhiteSpace(dto.PaymentTerms) ? "Net 30" : dto.PaymentTerms.Trim(),
                LeadTimeDays = dto.LeadTimeDays > 0 ? dto.LeadTimeDays : 7,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Suppliers.Add(supplier);
            await _context.SaveChangesAsync();
            return MapToDto(supplier);
        }

        public async Task<SupplierResponseDto?> UpdateAsync(int id, UpdateSupplierDto dto)
        {
            var supplier = await _context.Suppliers.FindAsync(id);
            if (supplier is null) return null;

            if (!string.IsNullOrWhiteSpace(dto.SupplierCode))
            {
                var newCode = dto.SupplierCode.Trim().ToUpperInvariant();
                if (newCode != supplier.SupplierCode)
                {
                    var codeExists = await _context.Suppliers
                        .AnyAsync(s => s.SupplierCode == newCode && s.Id != id);
                    if (codeExists)
                        throw new InvalidOperationException($"Supplier code '{newCode}' is already in use.");
                    supplier.SupplierCode = newCode;
                }
            }

            var emailClean = dto.ContactEmail.Trim().ToLowerInvariant();
            if (emailClean != supplier.ContactEmail)
            {
                var emailExists = await _context.Suppliers
                    .AnyAsync(s => s.ContactEmail == emailClean && s.Id != id);
                if (emailExists)
                    throw new InvalidOperationException($"Supplier with email '{emailClean}' already exists.");
                supplier.ContactEmail = emailClean;
            }

            supplier.Name = dto.Name.Trim();
            supplier.ContactPhone = dto.ContactPhone?.Trim() ?? string.Empty;
            supplier.Address = dto.Address?.Trim() ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(dto.PaymentTerms))
                supplier.PaymentTerms = dto.PaymentTerms.Trim();
            if (dto.LeadTimeDays > 0)
                supplier.LeadTimeDays = dto.LeadTimeDays;
            supplier.IsActive = dto.IsActive;
            supplier.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return MapToDto(supplier);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var supplier = await _context.Suppliers.FindAsync(id);
            if (supplier is null) return false;

            // Soft delete — preserve history
            supplier.IsActive = false;
            supplier.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<SupplierAnalyticsDto> GetAnalyticsAsync()
        {
            var suppliers = await _context.Suppliers.ToListAsync();
            var purchaseOrders = await _context.PurchaseOrders.ToListAsync();

            var totalSuppliers = suppliers.Count;
            var activeSuppliers = suppliers.Count(s => s.IsActive);
            var totalOrders = purchaseOrders.Count;
            var totalSpending = purchaseOrders
                .Where(p => p.Status == PurchaseOrderStatus.Approved || p.Status == PurchaseOrderStatus.Payment || p.Status == PurchaseOrderStatus.Sent)
                .Sum(p => p.TotalCost);

            var avgOrderValue = totalOrders > 0 ? Math.Round(totalSpending / totalOrders, 2) : 0m;
            var avgLeadTime = suppliers.Count > 0 ? (decimal)suppliers.Average(s => s.LeadTimeDays) : 0m;

            var supplierPerformances = suppliers.Select(s =>
            {
                var pos = purchaseOrders.Where(p => p.SupplierId == s.Id).ToList();
                var orderCount = pos.Count;
                var spend = pos
                    .Where(p => p.Status == PurchaseOrderStatus.Approved || p.Status == PurchaseOrderStatus.Payment || p.Status == PurchaseOrderStatus.Sent)
                    .Sum(p => p.TotalCost);
                var aov = orderCount > 0 ? Math.Round(spend / orderCount, 2) : 0m;
                var rejectedCount = pos.Count(p => p.Status == PurchaseOrderStatus.Rejected);
                var rejectionRate = orderCount > 0 ? Math.Round((decimal)rejectedCount / orderCount * 100m, 2) : 0m;
                var sentCount = pos.Count(p => p.Status == PurchaseOrderStatus.Sent);
                var deliveryPerf = orderCount > 0 ? Math.Round((decimal)sentCount / orderCount * 100m, 2) : 100m;

                return new SupplierPerformanceDto
                {
                    SupplierId = s.Id,
                    SupplierCode = s.SupplierCode,
                    SupplierName = s.Name,
                    OrderCount = orderCount,
                    TotalSpending = spend,
                    AverageOrderValue = aov,
                    AverageLeadTime = s.LeadTimeDays,
                    DeliveryPerformance = deliveryPerf,
                    RejectionRate = rejectionRate
                };
            }).OrderByDescending(sp => sp.TotalSpending).ToList();

            return new SupplierAnalyticsDto
            {
                TotalSuppliers = totalSuppliers,
                ActiveSuppliers = activeSuppliers,
                TotalOrders = totalOrders,
                TotalSpending = totalSpending,
                AverageOrderValue = avgOrderValue,
                AverageLeadTimeDays = Math.Round(avgLeadTime, 1),
                Suppliers = supplierPerformances
            };
        }

        public async Task<SupplierPerformanceDto?> GetPerformanceAsync(int id)
        {
            var supplier = await _context.Suppliers.FindAsync(id);
            if (supplier is null) return null;

            var pos = await _context.PurchaseOrders
                .Where(p => p.SupplierId == id)
                .ToListAsync();

            var orderCount = pos.Count;
            var spend = pos
                .Where(p => p.Status == PurchaseOrderStatus.Approved || p.Status == PurchaseOrderStatus.Payment || p.Status == PurchaseOrderStatus.Sent)
                .Sum(p => p.TotalCost);
            var aov = orderCount > 0 ? Math.Round(spend / orderCount, 2) : 0m;
            var rejectedCount = pos.Count(p => p.Status == PurchaseOrderStatus.Rejected);
            var rejectionRate = orderCount > 0 ? Math.Round((decimal)rejectedCount / orderCount * 100m, 2) : 0m;
            var sentCount = pos.Count(p => p.Status == PurchaseOrderStatus.Sent);
            var deliveryPerf = orderCount > 0 ? Math.Round((decimal)sentCount / orderCount * 100m, 2) : 100m;

            return new SupplierPerformanceDto
            {
                SupplierId = supplier.Id,
                SupplierCode = supplier.SupplierCode,
                SupplierName = supplier.Name,
                OrderCount = orderCount,
                TotalSpending = spend,
                AverageOrderValue = aov,
                AverageLeadTime = supplier.LeadTimeDays,
                DeliveryPerformance = deliveryPerf,
                RejectionRate = rejectionRate
            };
        }

        private async Task<string> GenerateSupplierCodeAsync()
        {
            var count = await _context.Suppliers.CountAsync();
            return $"SUP-{(count + 1):D3}";
        }

        private static SupplierResponseDto MapToDto(Supplier s) => new()
        {
            Id = s.Id,
            SupplierCode = s.SupplierCode,
            Name = s.Name,
            ContactEmail = s.ContactEmail,
            ContactPhone = s.ContactPhone,
            Address = s.Address,
            PaymentTerms = s.PaymentTerms,
            LeadTimeDays = s.LeadTimeDays,
            IsActive = s.IsActive,
            CreatedAt = s.CreatedAt,
            UpdatedAt = s.UpdatedAt
        };
    }
}
