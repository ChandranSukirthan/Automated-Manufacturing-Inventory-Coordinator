using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using backend.Data;
using backend.Dtos;
using backend.Models;

namespace backend.Services
{
    public class InventoryService : IInventoryService
    {
        private readonly ManufacturingContext _context;
        private readonly IBarcodeService _barcodeService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<InventoryService> _logger;

        public InventoryService(
            ManufacturingContext context,
            IBarcodeService barcodeService,
            IConfiguration configuration,
            ILogger<InventoryService> logger)
        {
            _context = context;
            _barcodeService = barcodeService;
            _configuration = configuration;
            _logger = logger;
        }

        // ========== Legacy / Generic Inventory Items ==========

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

        public async Task<InventoryItem?> GetInventoryItemByIdAsync(int id)
        {
            return await _context.InventoryItems.FindAsync(id);
        }

        public async Task<InventoryItem> CreateInventoryItemAsync(InventoryItem item)
        {
            _context.InventoryItems.Add(item);
            await _context.SaveChangesAsync();
            return item;
        }

        public async Task<bool> UpdateInventoryItemAsync(int id, InventoryItem item)
        {
            if (id != item.Id) return false;
            _context.Entry(item).State = EntityState.Modified;
            try
            {
                await _context.SaveChangesAsync();
                return true;
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!_context.InventoryItems.Any(e => e.Id == id)) return false;
                throw;
            }
        }

        public async Task<bool> DeleteInventoryItemAsync(int id)
        {
            var item = await _context.InventoryItems.FindAsync(id);
            if (item == null) return false;
            _context.InventoryItems.Remove(item);
            await _context.SaveChangesAsync();
            return true;
        }

        // ========== Stock Alerts ==========

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
                WorkerId = string.IsNullOrWhiteSpace(alertDto.WorkerId) ? "Floor Worker" : alertDto.WorkerId,
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
            if (alert == null) return false;
            alert.Status = newStatus;
            await _context.SaveChangesAsync();
            return true;
        }

        // ========== Student 1: Raw Material CRUD ==========

        public async Task<IEnumerable<RawMaterial>> GetRawMaterialsAsync()
        {
            return await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .Include(r => r.StockLevels)
                .OrderBy(r => r.Id)
                .ToListAsync();
        }

        public async Task<RawMaterial?> GetRawMaterialByIdAsync(int id)
        {
            return await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .Include(r => r.StockLevels)
                .FirstOrDefaultAsync(r => r.Id == id);
        }

        public async Task<RawMaterial> CreateRawMaterialAsync(RawMaterial material)
        {
            material.CreatedAt = DateTime.UtcNow;
            material.UpdatedAt = DateTime.UtcNow;
            _context.RawMaterials.Add(material);
            await _context.SaveChangesAsync();
            return material;
        }

        public async Task<bool> UpdateRawMaterialAsync(int id, RawMaterial material)
        {
            if (id != material.Id) return false;
            var existing = await _context.RawMaterials.FindAsync(id);
            if (existing == null) return false;

            existing.Name = material.Name;
            existing.SkuCode = material.SkuCode;
            existing.Description = material.Description;
            existing.Category = material.Category;
            existing.UnitOfMeasure = material.UnitOfMeasure;
            existing.ReorderThreshold = material.ReorderThreshold;
            existing.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteRawMaterialAsync(int id)
        {
            var existing = await _context.RawMaterials.FindAsync(id);
            if (existing == null) return false;

            _context.RawMaterials.Remove(existing);
            await _context.SaveChangesAsync();
            return true;
        }

        // ========== Student 1: Inventory Roll CRUD & QR Lookup ==========

        public async Task<IEnumerable<InventoryRoll>> GetInventoryRollsAsync()
        {
            return await _context.InventoryRolls
                .Include(r => r.RawMaterial)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();
        }

        public async Task<InventoryRoll?> GetInventoryRollByIdAsync(int id)
        {
            return await _context.InventoryRolls
                .Include(r => r.RawMaterial)
                .FirstOrDefaultAsync(r => r.Id == id);
        }

        public async Task<QrLookupResultDto?> GetInventoryRollByQrAsync(string qrCode)
        {
            if (string.IsNullOrWhiteSpace(qrCode)) return null;

            var clean = qrCode.Trim();
            var roll = await _context.InventoryRolls
                .Include(r => r.RawMaterial)
                .FirstOrDefaultAsync(r => r.RollIdentifier == clean ||
                                          r.RollIdentifier.ToUpper() == clean.ToUpper());

            if (roll == null) return null;

            return new QrLookupResultDto
            {
                RollId = roll.Id,
                RollIdentifier = roll.RollIdentifier,
                BarcodeUrl = roll.BarcodeUrl,
                RawMaterialId = roll.RawMaterialId,
                SkuCode = roll.RawMaterial?.SkuCode ?? "UNKNOWN",
                MaterialName = roll.RawMaterial?.Name ?? "Raw Material",
                InitialQuantity = roll.InitialQuantity,
                RemainingQuantity = roll.CurrentQuantity,
                Status = roll.Status,
                ReceivedDate = roll.ReceivedDate
            };
        }

        public async Task<InventoryRoll> CreateInventoryRollAsync(InventoryRoll roll)
        {
            if (string.IsNullOrWhiteSpace(roll.RollIdentifier))
            {
                roll.RollIdentifier = $"ROLL-{DateTime.UtcNow:yyyyMMddHHmmss}-{new Random().Next(100, 999)}";
            }

            roll.BarcodeUrl = _barcodeService.GenerateQrCodeUrl(roll.RollIdentifier);
            roll.CreatedAt = DateTime.UtcNow;
            roll.UpdatedAt = DateTime.UtcNow;
            if (roll.ReceivedDate == default) roll.ReceivedDate = DateTime.UtcNow;
            if (roll.CurrentQuantity == 0 && roll.InitialQuantity > 0) roll.CurrentQuantity = roll.InitialQuantity;
            if (string.IsNullOrWhiteSpace(roll.Status)) roll.Status = "In Stock";

            _context.InventoryRolls.Add(roll);
            await _context.SaveChangesAsync();
            return roll;
        }

        public async Task<bool> UpdateInventoryRollAsync(int id, InventoryRoll roll)
        {
            if (id != roll.Id) return false;
            var existing = await _context.InventoryRolls.FindAsync(id);
            if (existing == null) return false;

            existing.CurrentQuantity = roll.CurrentQuantity;
            existing.InitialQuantity = roll.InitialQuantity;
            existing.Status = roll.Status;
            existing.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteInventoryRollAsync(int id)
        {
            var roll = await _context.InventoryRolls.FindAsync(id);
            if (roll == null) return false;

            _context.InventoryRolls.Remove(roll);
            await _context.SaveChangesAsync();
            return true;
        }

        // ========== Student 1: Business Operations & Calculations ==========

        public decimal CalculateBurnRate(decimal historicalConsumption, int numberOfDays)
        {
            if (numberOfDays <= 0) return 0m;
            return Math.Round(historicalConsumption / numberOfDays, 2);
        }

        public decimal CalculateDaysRemaining(decimal currentStock, decimal burnRate)
        {
            if (burnRate <= 0m) return 999m;
            return Math.Round(currentStock / burnRate, 2);
        }

        public async Task<IEnumerable<StockLevelDetailDto>> GetStockLevelsAsync()
        {
            var materials = await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .ToListAsync();

            var list = new List<StockLevelDetailDto>();

            foreach (var m in materials)
            {
                // Calculate stock from active available rolls
                var activeRolls = m.InventoryRolls.Where(r => !r.Status.Equals("Depleted", StringComparison.OrdinalIgnoreCase));
                var currentStock = activeRolls.Any() ? activeRolls.Sum(r => r.CurrentQuantity) : (m.ReorderThreshold * 1.5m);
                var minStock = m.ReorderThreshold;
                var maxStock = minStock * 5m;

                // Estimate burn rate based on category / historical rate
                var burnRate = m.SkuCode.Contains("STEEL", StringComparison.OrdinalIgnoreCase) ? 80m :
                               m.SkuCode.Contains("ALUM", StringComparison.OrdinalIgnoreCase) ? 25m : 180m;
                var daysRemaining = CalculateDaysRemaining(currentStock, burnRate);

                var status = currentStock <= (minStock * 0.5m) || daysRemaining <= 3 ? "CRITICAL" :
                             currentStock <= minStock || daysRemaining <= 7 ? "LOW" : "NORMAL";

                list.Add(new StockLevelDetailDto
                {
                    Id = m.Id,
                    RawMaterialId = m.Id,
                    SkuCode = m.SkuCode,
                    MaterialName = m.Name,
                    CurrentStock = currentStock,
                    MinimumStock = minStock,
                    MaximumStock = maxStock,
                    BurnRate = burnRate,
                    DaysRemaining = daysRemaining,
                    Status = status,
                    UpdatedAt = m.UpdatedAt
                });
            }

            return list;
        }

        public async Task<StockLevel> CreateStockLevelAsync(StockLevel stockLevel)
        {
            stockLevel.RecordedAt = DateTime.UtcNow;
            _context.StockLevels.Add(stockLevel);
            await _context.SaveChangesAsync();
            return stockLevel;
        }

        public async Task<LowStockItemDto> DetectLowStockAsync(int rawMaterialId)
        {
            var material = await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .FirstOrDefaultAsync(r => r.Id == rawMaterialId);

            if (material == null)
            {
                return new LowStockItemDto { MaterialId = rawMaterialId, LowStock = false, Reason = "Material not found" };
            }

            var activeRolls = material.InventoryRolls.Where(r => !r.Status.Equals("Depleted", StringComparison.OrdinalIgnoreCase));
            var currentStock = activeRolls.Any() ? activeRolls.Sum(r => r.CurrentQuantity) : 0m;
            var minStock = material.ReorderThreshold;
            var burnRate = material.SkuCode.Contains("STEEL", StringComparison.OrdinalIgnoreCase) ? 80m :
                           material.SkuCode.Contains("ALUM", StringComparison.OrdinalIgnoreCase) ? 25m : 180m;
            var daysRemaining = CalculateDaysRemaining(currentStock, burnRate);

            var isLow = currentStock <= minStock || daysRemaining <= 5m;
            var severity = currentStock <= (minStock * 0.5m) || daysRemaining <= 2m ? "CRITICAL" : isLow ? "LOW" : "NORMAL";

            // If low stock reached threshold, create a StockAlert automatically
            if (isLow)
            {
                var existingPendingAlert = await _context.StockAlerts
                    .AnyAsync(a => a.Sku == material.SkuCode && a.Status == "Pending");

                if (!existingPendingAlert)
                {
                    _context.StockAlerts.Add(new StockAlert
                    {
                        Sku = material.SkuCode,
                        PackagingType = material.Category,
                        QuantityRequested = (int)Math.Max(500, (minStock * 2) - currentStock),
                        WorkerId = "Automated Low-Stock Detector",
                        Status = "Pending",
                        Timestamp = DateTime.UtcNow
                    });
                    await _context.SaveChangesAsync();
                }
            }

            return new LowStockItemDto
            {
                MaterialId = material.Id,
                SkuCode = material.SkuCode,
                MaterialName = material.Name,
                CurrentStock = currentStock,
                MinimumStock = minStock,
                BurnRate = burnRate,
                DaysRemaining = daysRemaining,
                LowStock = isLow,
                Severity = severity,
                Reason = isLow ? $"Current stock ({currentStock}) below threshold ({minStock}) or days remaining ({daysRemaining}d) near runout." : "Stock level within normal parameters."
            };
        }

        public async Task<IEnumerable<LowStockItemDto>> GetLowStockItemsAsync()
        {
            var materials = await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .ToListAsync();

            var list = new List<LowStockItemDto>();
            foreach (var m in materials)
            {
                var detected = await DetectLowStockAsync(m.Id);
                if (detected.LowStock)
                {
                    list.Add(detected);
                }
            }
            return list;
        }

        public async Task<IEnumerable<InventoryHistoryItemDto>> GetInventoryHistoryAsync(int rawMaterialId)
        {
            var material = await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .FirstOrDefaultAsync(r => r.Id == rawMaterialId);

            var history = new List<InventoryHistoryItemDto>();
            if (material == null) return history;

            decimal runningStock = 0m;
            foreach (var roll in material.InventoryRolls.OrderBy(r => r.ReceivedDate))
            {
                var prev = runningStock;
                runningStock += roll.InitialQuantity;
                history.Add(new InventoryHistoryItemDto
                {
                    Date = roll.ReceivedDate,
                    TransactionType = "RECEIVED",
                    Quantity = roll.InitialQuantity,
                    PreviousStock = prev,
                    NewStock = runningStock,
                    Reason = $"Received Roll {roll.RollIdentifier}",
                    User = "Floor Receiving Clerk"
                });

                if (roll.InitialQuantity > roll.CurrentQuantity)
                {
                    var consumed = roll.InitialQuantity - roll.CurrentQuantity;
                    var prevAfterReceive = runningStock;
                    runningStock -= consumed;
                    history.Add(new InventoryHistoryItemDto
                    {
                        Date = roll.UpdatedAt,
                        TransactionType = "CONSUMED",
                        Quantity = consumed,
                        PreviousStock = prevAfterReceive,
                        NewStock = runningStock,
                        Reason = $"Production Consumption on Roll {roll.RollIdentifier}",
                        User = "Shop Floor Operator"
                    });
                }
            }

            return history.OrderByDescending(h => h.Date).ToList();
        }

        // ========== Student 1: Proxy AI Replenishment Trigger via ASP.NET Core ==========

        public async Task<object> TriggerAgentReplenishmentAsync(TriggerReplenishmentDto dto)
        {
            var agentBaseUrl = _configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            var objective = !string.IsNullOrWhiteSpace(dto.Objective)
                ? dto.Objective
                : $"Floor Worker Stock Replenishment: Reorder {dto.RequiredQuantity} units of {dto.MaterialId}";

            try
            {
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
                var payload = new
                {
                    objective = objective,
                    material_id = dto.MaterialId,
                    required_quantity = (double)dto.RequiredQuantity
                };

                var resp = await client.PostAsJsonAsync($"{agentBaseUrl}/api/workflows/trigger", payload);
                if (resp.IsSuccessStatusCode)
                {
                    var result = await resp.Content.ReadFromJsonAsync<object>();
                    return result ?? new { status = "Triggered", objective };
                }
                
                _logger.LogWarning("Agent AI returned status code {StatusCode}", resp.StatusCode);
                return new { status = "TriggeredOfflineFallback", objective, note = "Agent reached with non-200" };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to call Agent AI microservice from ASP.NET Core proxy");
                return new { status = "OfflineQueue", objective, error = ex.Message };
            }
        }
    }
}