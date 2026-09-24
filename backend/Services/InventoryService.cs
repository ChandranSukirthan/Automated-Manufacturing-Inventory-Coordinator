using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data; // Updated to the new Data namespace
using backend.Dtos;
using backend.Models;

namespace backend.Services
{
    public class InventoryService : IInventoryService
    {
        private readonly ApplicationDbContext _context; // Changed to ApplicationDbContext

        public InventoryService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<InventoryItemDto>> GetInventoryItemsAsync()
        {
            return await _context.InventoryItems
                .Select(item => new InventoryItemDto
                {
                    Id = item.Id,
                    Sku = item.Sku,
                    Name = item.Name,
                    Category = item.Category,
                    StockLevel = item.StockLevel,
                    ReorderThreshold = item.ReorderThreshold
                })
                .ToListAsync();
        }

        public async Task<IEnumerable<StockAlertResponseDto>> GetStockAlertsAsync()
        {
            return await _context.StockAlerts
                .OrderByDescending(alert => alert.Timestamp)
                .Select(alert => new StockAlertResponseDto
                {
                    Id = alert.Id,
                    Sku = alert.Sku,
                    PackagingType = alert.PackagingType,
                    QuantityRequested = alert.QuantityRequested,
                    Status = alert.Status,
                    Timestamp = alert.Timestamp,
                    WorkerId = alert.WorkerId
                })
                .ToListAsync();
        }

        public async Task<StockAlertResponseDto> CreateStockAlertAsync(CreateStockAlertDto alertDto)
        {
            var alert = new StockAlert
            {
                Sku = alertDto.Sku,
                PackagingType = alertDto.PackagingType,
                QuantityRequested = alertDto.QuantityRequested,
                WorkerId = alertDto.WorkerId,
                Status = "Pending",
                Timestamp = DateTime.UtcNow
            };

            _context.StockAlerts.Add(alert);
            await _context.SaveChangesAsync();

            return new StockAlertResponseDto
            {
                Id = alert.Id,
                Sku = alert.Sku,
                PackagingType = alert.PackagingType,
                QuantityRequested = alert.QuantityRequested,
                Status = alert.Status,
                Timestamp = alert.Timestamp,
                WorkerId = alert.WorkerId
            };
        }

        public async Task<bool> UpdateAlertStatusAsync(int id, string newStatus)
        {
            var alert = await _context.StockAlerts.FindAsync(id);
            if (alert == null)
            {
                return false;
            }

            alert.Status = newStatus;
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> UpdateInventoryItemAsync(int id, InventoryItem item)
        {
            if (id != item.Id)
            {
                return false;
            }

            _context.Entry(item).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
                return true;
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!_context.InventoryItems.Any(e => e.Id == id))
                {
                    return false;
                }
                else
                {
                    throw;
                }
            }
        }

        public async Task<bool> DeleteInventoryItemAsync(int id)
        {
            var item = await _context.InventoryItems.FindAsync(id);
            if (item == null)
            {
                return false;
            }

            _context.InventoryItems.Remove(item);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<InventoryItem> CreateInventoryItemAsync(InventoryItem item)
        {
            _context.InventoryItems.Add(item);
            await _context.SaveChangesAsync();
            return item;
        }

        public async Task<InventoryItem> GetInventoryItemByIdAsync(int id)
        {
            return await _context.InventoryItems.FindAsync(id);
        }

        public async Task<InventoryRoll> CreateInventoryRollAsync(InventoryRoll roll)
        {
            if (string.IsNullOrWhiteSpace(roll.RollIdentifier))
            {
                throw new ArgumentException("RollIdentifier is required.");
            }

            roll.RollIdentifier = roll.RollIdentifier.Trim();
            roll.CreatedAt = DateTime.UtcNow;
            roll.UpdatedAt = DateTime.UtcNow;

            _context.InventoryRolls.Add(roll);
            await _context.SaveChangesAsync();

            // The app serves this image through its authenticated API endpoint.
            // Do not store a third-party URL or make external calls on writes.
            roll.BarcodeUrl = $"/api/inventory/rolls/{Uri.EscapeDataString(roll.RollIdentifier)}/qr";
            await _context.SaveChangesAsync();
            return roll;
        }

        public async Task<InventoryRoll?> GetInventoryRollByIdentifierAsync(string rollIdentifier)
        {
            return await _context.InventoryRolls
                .AsNoTracking()
                .FirstOrDefaultAsync(roll => roll.RollIdentifier == rollIdentifier);
        }

        public async Task<RawMaterial> CreateRawMaterialAsync(RawMaterial material)
        {
            material.CreatedAt = DateTime.UtcNow;
            material.UpdatedAt = DateTime.UtcNow;

            _context.RawMaterials.Add(material);
            await _context.SaveChangesAsync();
            return material;
        }
    }
}
