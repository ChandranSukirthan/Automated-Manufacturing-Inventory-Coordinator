using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
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
            var supplier = new Supplier
            {
                Name = dto.Name.Trim(),
                ContactEmail = dto.ContactEmail.Trim().ToLowerInvariant(),
                ContactPhone = dto.ContactPhone?.Trim() ?? string.Empty,
                Address = dto.Address?.Trim() ?? string.Empty,
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

            supplier.Name = dto.Name.Trim();
            supplier.ContactEmail = dto.ContactEmail.Trim().ToLowerInvariant();
            supplier.ContactPhone = dto.ContactPhone?.Trim() ?? string.Empty;
            supplier.Address = dto.Address?.Trim() ?? string.Empty;
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

        private static SupplierResponseDto MapToDto(Supplier s) => new()
        {
            Id = s.Id,
            Name = s.Name,
            ContactEmail = s.ContactEmail,
            ContactPhone = s.ContactPhone,
            Address = s.Address,
            IsActive = s.IsActive,
            CreatedAt = s.CreatedAt,
            UpdatedAt = s.UpdatedAt
        };
    }
}

