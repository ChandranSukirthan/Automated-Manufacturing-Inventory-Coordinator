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
        private readonly IBarcodeService _barcodeService;

        public InventoryService(ManufacturingContext context, IBarcodeService barcodeService)
        {
            _context = context;
            _barcodeService = barcodeService;
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
            var alerts = await _context.StockAlerts
                .OrderByDescending(alert => alert.Timestamp)
                .ToListAsync();

            return alerts.Select(MapToStockAlertResponseDto);
        }

        public async Task<StockAlertResponseDto?> GetStockAlertByIdAsync(int id)
        {
            var alert = await _context.StockAlerts.FindAsync(id);
            return alert == null ? null : MapToStockAlertResponseDto(alert);
        }

        public async Task<IEnumerable<StockAlertResponseDto>> GetUnreadStockAlertsAsync()
        {
            var alerts = await _context.StockAlerts
                .Where(alert => !alert.IsRead)
                .OrderByDescending(alert => alert.Timestamp)
                .ToListAsync();

            return alerts.Select(MapToStockAlertResponseDto);
        }

        public async Task<bool> MarkStockAlertAsReadAsync(int id)
        {
            var alert = await _context.StockAlerts.FindAsync(id);
            if (alert == null) return false;

            alert.IsRead = true;
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<StockAlertResponseDto> CreateStockAlertAsync(CreateStockAlertDto alertDto)
        {
            // Deterministic calculation:
            // NetDeficit = (RequiredQuantity + SafetyStock) - (CurrentStock + OpenPurchaseQuantity)
            // Never allow the LLM to calculate the authoritative deficit.
            var item = await _context.InventoryItems.FirstOrDefaultAsync(i => i.Sku == alertDto.Sku);

            var currentStock = alertDto.CurrentStock ?? (item != null ? (decimal)item.StockLevel : 0m);
            var safetyStock = alertDto.SafetyStock ?? (item != null ? (decimal)item.ReorderThreshold : 0m);
            var requiredQty = alertDto.RequiredQuantity ?? (decimal)alertDto.QuantityRequested;
            var openPoQty = alertDto.OpenPurchaseQuantity ?? 0m;
            var netDeficit = Math.Max(0m, (requiredQty + safetyStock) - (currentStock + openPoQty));

            var materialName = !string.IsNullOrWhiteSpace(alertDto.MaterialName)
                ? alertDto.MaterialName
                : (item?.Name ?? alertDto.Sku);

            var severity = !string.IsNullOrWhiteSpace(alertDto.Severity)
                ? alertDto.Severity
                : (netDeficit > 500 ? "Critical" : netDeficit > 100 ? "High" : "Medium");

            var alert = new StockAlert
            {
                Sku = alertDto.Sku,
                PackagingType = alertDto.PackagingType,
                QuantityRequested = alertDto.QuantityRequested > 0 ? alertDto.QuantityRequested : (int)requiredQty,
                WorkerId = alertDto.WorkerId,
                Status = "Pending",
                Timestamp = DateTime.UtcNow,
                MaterialId = alertDto.MaterialId ?? item?.Id,
                MaterialName = materialName,
                CurrentStock = currentStock,
                RequiredQuantity = requiredQty,
                SafetyStock = safetyStock,
                OpenPurchaseQuantity = openPoQty,
                NetDeficit = netDeficit,
                Severity = severity,
                IsRead = false
            };

            _context.StockAlerts.Add(alert);
            await _context.SaveChangesAsync();

            return MapToStockAlertResponseDto(alert);
        }

        private static StockAlertResponseDto MapToStockAlertResponseDto(StockAlert alert)
        {
            var reqQty = alert.RequiredQuantity > 0 ? alert.RequiredQuantity : alert.QuantityRequested;
            var deficit = alert.NetDeficit > 0
                ? alert.NetDeficit
                : Math.Max(0m, (reqQty + alert.SafetyStock) - (alert.CurrentStock + alert.OpenPurchaseQuantity));

            return new StockAlertResponseDto
            {
                Id = alert.Id,
                Sku = alert.Sku,
                PackagingType = alert.PackagingType,
                QuantityRequested = alert.QuantityRequested,
                Status = alert.Status,
                Timestamp = alert.Timestamp,
                WorkerId = alert.WorkerId,
                MaterialId = alert.MaterialId,
                MaterialName = alert.MaterialName ?? alert.Sku,
                CurrentStock = alert.CurrentStock,
                RequiredQuantity = reqQty,
                SafetyStock = alert.SafetyStock,
                OpenPurchaseQuantity = alert.OpenPurchaseQuantity,
                NetDeficit = deficit,
                Severity = string.IsNullOrWhiteSpace(alert.Severity) ? "Medium" : alert.Severity,
                IsRead = alert.IsRead
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

        // Student A - Implements InventoryRoll creation with Barcode Generation
        public async Task<InventoryRoll> CreateInventoryRollAsync(InventoryRoll roll)
        {
            // Validate basic required fields or let DB constraints handle it
            if (string.IsNullOrWhiteSpace(roll.RollIdentifier))
            {
                throw new ArgumentException("RollIdentifier is required.");
            }

            // Phase 2: Automatically generate the QR code URL using the 3rd-party service
            roll.BarcodeUrl = _barcodeService.GenerateQrCodeUrl(roll.RollIdentifier);

            // Set timestamps
            roll.CreatedAt = DateTime.UtcNow;
            roll.UpdatedAt = DateTime.UtcNow;

            _context.InventoryRolls.Add(roll);
            await _context.SaveChangesAsync();
            return roll;
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
  
