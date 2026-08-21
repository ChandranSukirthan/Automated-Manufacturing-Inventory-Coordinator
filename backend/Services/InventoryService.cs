using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Dtos;
using backend.Models;

namespace backend.Services
{
    public class InventoryService : IInventoryService
    {
        private readonly ManufacturingContext _context;

        public InventoryService(ManufacturingContext context)
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
            // FindAsync searches the database for the primary key (id)
            return await _context.InventoryItems.FindAsync(id);
        }
    }
}
  
