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
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;

namespace backend.Services
{
    public class InventoryService : IInventoryService
    {
        private readonly ManufacturingContext _context;
        private readonly ApplicationDbContext? _appContext;
        private readonly IBarcodeService _barcodeService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<InventoryService> _logger;

        public InventoryService(
            ManufacturingContext context,
            IBarcodeService barcodeService,
            IConfiguration configuration,
            ILogger<InventoryService> logger,
            ApplicationDbContext? appContext = null)
        {
            _context = context;
            _barcodeService = barcodeService;
            _configuration = configuration;
            _logger = logger;
            _appContext = appContext;
        }

        // ========== Legacy / Generic Inventory Items ==========

        public async Task<IEnumerable<InventoryItemDto>> GetInventoryItemsAsync()
        {
            var items = await _context.InventoryItems.ToListAsync();
            var skuCodes = items
                .Where(item => !string.IsNullOrWhiteSpace(item.Sku))
                .Select(item => item.Sku.Trim())
                .ToList();
            var existingSkus = await _context.RawMaterials
                .Where(material => skuCodes.Contains(material.SkuCode))
                .Select(material => material.SkuCode)
                .ToListAsync();
            var missingMaterials = items
                .Where(item => !string.IsNullOrWhiteSpace(item.Sku) && !existingSkus.Contains(item.Sku.Trim()))
                .GroupBy(item => item.Sku.Trim(), StringComparer.OrdinalIgnoreCase)
                .Select(group => group.First())
                .Select(item => new RawMaterial
                {
                    SkuCode = item.Sku.Trim(),
                    Name = item.Name,
                    Category = item.Category,
                    UnitOfMeasure = "UNITS",
                    ReorderThreshold = item.ReorderThreshold
                })
                .ToList();
            if (missingMaterials.Count > 0)
            {
                _context.RawMaterials.AddRange(missingMaterials);
                await _context.SaveChangesAsync();
            }

            return items
                .Select(item => new InventoryItemDto
                {
                    Id = item.Id,
                    Sku = item.Sku,
                    Name = item.Name,
                    Category = item.Category,
                    StockLevel = item.StockLevel,
                    ReorderThreshold = item.ReorderThreshold
                })
                .ToList();
        }

        public async Task<InventoryItem?> GetInventoryItemByIdAsync(int id)
        {
            return await _context.InventoryItems.FindAsync(id);
        }

        public async Task<InventoryItem> CreateInventoryItemAsync(InventoryItem item)
        {
            _context.InventoryItems.Add(item);
            await _context.SaveChangesAsync();
            if (!string.IsNullOrWhiteSpace(item.Sku) && !await _context.RawMaterials.AnyAsync(material => material.SkuCode == item.Sku.Trim()))
            {
                _context.RawMaterials.Add(new RawMaterial
                {
                    SkuCode = item.Sku.Trim(),
                    Name = item.Name,
                    Category = item.Category,
                    UnitOfMeasure = "UNITS",
                    ReorderThreshold = item.ReorderThreshold
                });
                await _context.SaveChangesAsync();
            }
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
            var existingPending = await _context.StockAlerts
                .FirstOrDefaultAsync(a => a.Sku == alertDto.Sku && (a.Status == "Pending" || a.Status == "Processing" || a.Status == "Acknowledged"));

            if (existingPending != null)
            {
                return new StockAlertResponseDto
                {
                    Id = existingPending.Id,
                    Sku = existingPending.Sku,
                    PackagingType = existingPending.PackagingType,
                    QuantityRequested = existingPending.QuantityRequested,
                    Status = existingPending.Status,
                    Timestamp = existingPending.Timestamp,
                    WorkerId = existingPending.WorkerId
                };
            }

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

        public async Task<InventoryRoll?> GetInventoryRollByIdAsync(string id)
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
            if (roll.InitialQuantity <= 0)
            {
                throw new InvalidOperationException("Roll quantity must be greater than zero.");
            }

            var rawMaterial = await _context.RawMaterials.FindAsync(roll.RawMaterialId);
            if (rawMaterial == null)
            {
                throw new InvalidOperationException("The selected raw material was not found.");
            }

            var inventoryItem = await _context.InventoryItems
                .FirstOrDefaultAsync(item => item.Sku == rawMaterial.SkuCode);
            if (inventoryItem != null)
            {
                var allocatedQuantity = await _context.InventoryRolls
                    .Where(existingRoll => existingRoll.RawMaterialId == roll.RawMaterialId)
                    .SumAsync(existingRoll => (decimal?)existingRoll.CurrentQuantity) ?? 0m;
                var remainingStock = inventoryItem.StockLevel - allocatedQuantity;
                if (roll.InitialQuantity > remainingStock)
                {
                    throw new InvalidOperationException(
                        $"Roll quantity ({roll.InitialQuantity}) exceeds remaining stock ({Math.Max(remainingStock, 0)} of {inventoryItem.StockLevel}) for {rawMaterial.SkuCode}.");
                }
            }

            if (_context.Database.IsRelational())
            {
                var requestedBatchId = roll.BatchId ?? string.Empty;
                var batchId = await _context.Database
                    .SqlQueryRaw<string>("SELECT \"Id\" AS \"Value\" FROM \"Batches\" WHERE \"Id\" = {0} LIMIT 1", requestedBatchId)
                    .FirstOrDefaultAsync();
                if (batchId == null)
                {
                    batchId = await _context.Database
                        .SqlQueryRaw<string>("SELECT \"Id\" AS \"Value\" FROM \"Batches\" ORDER BY \"Id\" LIMIT 1")
                        .FirstOrDefaultAsync();
                }
                if (batchId == null)
                {
                    throw new InvalidOperationException("No batch is available for the new inventory roll.");
                }
                roll.BatchId = batchId;
            }

            if (string.IsNullOrWhiteSpace(roll.RollIdentifier))
            {
                roll.RollIdentifier = $"ROLL-{DateTime.UtcNow:yyyyMMddHHmmss}-{new Random().Next(100, 999)}";
            }
            if (string.IsNullOrWhiteSpace(roll.Id))
            {
                roll.Id = roll.RollIdentifier;
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

        public async Task<bool> UpdateInventoryRollAsync(string id, InventoryRoll roll)
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

        public async Task<bool> DeleteInventoryRollAsync(string id)
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
                // Calculate stock from active available rolls (strictly excluding Depleted and Quarantined)
                var activeRolls = m.InventoryRolls.Where(r => 
                    !r.Status.Equals("Depleted", StringComparison.OrdinalIgnoreCase) &&
                    !r.Status.Equals("Quarantined", StringComparison.OrdinalIgnoreCase));
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

            var activeRolls = material.InventoryRolls.Where(r => 
                !r.Status.Equals("Depleted", StringComparison.OrdinalIgnoreCase) &&
                !r.Status.Equals("Quarantined", StringComparison.OrdinalIgnoreCase));
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
                    .AnyAsync(a => a.Sku == material.SkuCode && (a.Status == "Pending" || a.Status == "Processing" || a.Status == "Acknowledged"));

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

            // 1. Resolve Raw Material from database
            backend.Models.RawMaterial? material = null;
            if (int.TryParse(dto.MaterialId, out int parsedId))
            {
                material = await _context.RawMaterials.FindAsync(parsedId);
            }
            if (material == null && !string.IsNullOrWhiteSpace(dto.MaterialId))
            {
                var clean = dto.MaterialId.Trim().ToLower();
                material = await _context.RawMaterials
                    .FirstOrDefaultAsync(m => m.SkuCode.ToLower() == clean || m.Name.ToLower().Contains(clean));
            }
            if (material == null)
            {
                material = await _context.RawMaterials.FirstOrDefaultAsync();
            }

            var materialSku = material?.SkuCode ?? (!string.IsNullOrWhiteSpace(dto.MaterialId) ? dto.MaterialId : "RM-STEEL-001");
            var materialName = material?.Name ?? "Cold Rolled Steel Sheet";

            string? wfId = null;
            string? currentAgent = "Purchasing";
            string? workflowStatus = "WaitingForApproval";
            string? approvalStatus = "Pending";
            bool requiresApproval = true;
            decimal draftQty = dto.RequiredQuantity > 0 ? dto.RequiredQuantity : 2000m;
            decimal draftUnitPrice = 4.50m;
            string draftSupplierCode = "SUP-001";
            string draftSupplierName = "Apex Industrial Metals";
            string? draftPoNumber = null;
            object? agentRawResult = null;

            // 2. Invoke Agentic AI microservice
            try
            {
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
                var payload = new
                {
                    objective = objective,
                    material_id = materialSku,
                    required_quantity = (double)draftQty
                };

                var resp = await client.PostAsJsonAsync($"{agentBaseUrl}/api/workflows/trigger", payload);
                if (resp.IsSuccessStatusCode)
                {
                    var jsonDoc = await resp.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
                    agentRawResult = jsonDoc;

                    if (jsonDoc.TryGetProperty("workflow_id", out var wIdProp))
                        wfId = wIdProp.GetString();
                    if (jsonDoc.TryGetProperty("current_agent", out var agentProp))
                        currentAgent = agentProp.GetString();
                    if (jsonDoc.TryGetProperty("status", out var stProp))
                        workflowStatus = stProp.GetString();
                    if (jsonDoc.TryGetProperty("approval_status", out var appStProp))
                        approvalStatus = appStProp.GetString();
                    if (jsonDoc.TryGetProperty("requires_approval", out var reqProp))
                        requiresApproval = reqProp.GetBoolean();

                    if (jsonDoc.TryGetProperty("purchasing_data", out var purchData))
                    {
                        if (purchData.TryGetProperty("supplier", out var supData))
                        {
                            if (supData.TryGetProperty("supplierId", out var sId)) draftSupplierCode = sId.GetString() ?? draftSupplierCode;
                            if (supData.TryGetProperty("name", out var sName)) draftSupplierName = sName.GetString() ?? draftSupplierName;
                            if (supData.TryGetProperty("pricePerUnit", out var pUnit)) draftUnitPrice = (decimal)pUnit.GetDouble();
                        }
                        if (purchData.TryGetProperty("draft_po", out var draftPo))
                        {
                            if (draftPo.TryGetProperty("poNumber", out var poNum)) draftPoNumber = poNum.GetString();
                            if (draftPo.TryGetProperty("quantity", out var dQty)) draftQty = (decimal)dQty.GetDouble();
                            if (draftPo.TryGetProperty("unitPrice", out var dPrice)) draftUnitPrice = (decimal)dPrice.GetDouble();
                        }
                    }
                }
                else
                {
                    _logger.LogWarning("Agent AI returned non-success code {StatusCode}", resp.StatusCode);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Agent AI microservice unavailable; operating in autonomous queue fallback");
            }

            // Fallback workflow ID if none returned
            wfId ??= $"WF-AI-{DateTime.UtcNow:yyyyMMdd}-{new Random().Next(1000, 9999)}";

            // 3. Create or Sync Purchase Order in ApplicationDbContext for Supply Chain Manager
            int? createdPoId = null;
            string? finalPoNumber = null;
            decimal totalAmount = draftQty * draftUnitPrice;

            if (_appContext != null)
            {
                try
                {
                    // Find matching Supplier in Database
                    var supplier = await _appContext.Suppliers
                        .FirstOrDefaultAsync(s => s.SupplierCode == draftSupplierCode)
                        ?? await _appContext.Suppliers
                            .FirstOrDefaultAsync(s => s.Name.ToLower().Contains(draftSupplierName.ToLower()))
                        ?? await _appContext.Suppliers.FirstOrDefaultAsync(s => s.IsActive)
                        ?? await _appContext.Suppliers.FirstOrDefaultAsync();

                    if (supplier != null && material != null)
                    {
                        var poCount = await _appContext.PurchaseOrders.CountAsync();
                        finalPoNumber = !string.IsNullOrWhiteSpace(draftPoNumber)
                            ? draftPoNumber
                            : $"PO-{DateTime.UtcNow:yyyy}-{(poCount + 1):D4}";

                        // Check if PO exists with this number
                        var existingPo = await _appContext.PurchaseOrders.FirstOrDefaultAsync(p => p.PoNumber == finalPoNumber);
                        if (existingPo == null)
                        {
                            var po = new ManufacturingCoordinator.Models.PurchaseOrders.PurchaseOrder
                            {
                                PoNumber = finalPoNumber,
                                SupplierId = supplier.Id,
                                Currency = "USD",
                                BudgetLimit = 15000m,
                                ApprovalThreshold = 5000m,
                                RequiresApproval = true,
                                Status = PurchaseOrderStatus.PendingApproval,
                                Notes = $"[AI Replenishment Order] Workflow: {wfId}. {objective}",
                                TotalCost = totalAmount,
                                CreatedAt = DateTime.UtcNow,
                                UpdatedAt = DateTime.UtcNow
                            };

                            po.OrderLines.Add(new ManufacturingCoordinator.Models.PurchaseOrders.OrderLine
                            {
                                RawMaterialId = material.Id,
                                Description = $"AI Multi-Agent Autonomous Replenishment for {material.Name} ({material.SkuCode})",
                                Quantity = draftQty,
                                UnitPrice = draftUnitPrice,
                                TotalPrice = totalAmount,
                                CreatedAt = DateTime.UtcNow,
                                UpdatedAt = DateTime.UtcNow
                            });

                            _appContext.PurchaseOrders.Add(po);
                            await _appContext.SaveChangesAsync();
                            createdPoId = po.Id;

                            // Add audit trail record
                            _appContext.PurchaseOrderApprovals.Add(new ManufacturingCoordinator.Models.PurchaseOrders.PurchaseOrderApproval
                            {
                                PurchaseOrderId = po.Id,
                                Action = "PendingApproval",
                                Notes = $"Autonomous AI workflow {wfId} generated replenishment draft. Pending Supply Chain Manager approval.",
                                Timestamp = DateTime.UtcNow
                            });
                            await _appContext.SaveChangesAsync();

                            _logger.LogInformation("Created PendingApproval PurchaseOrder {PoNumber} (ID: {PoId}) from AI workflow {WfId}", po.PoNumber, po.Id, wfId);
                        }
                        else
                        {
                            createdPoId = existingPo.Id;
                            finalPoNumber = existingPo.PoNumber;
                        }
                    }

                    // Sync or update StockAlert status to 'Processing' so UI shows active replenishment
                    var alertsToUpdate = await _context.StockAlerts
                        .Where(a => a.Sku == materialSku && (a.Status == "Pending" || a.Status == "Acknowledged"))
                        .ToListAsync();

                    if (alertsToUpdate.Any())
                    {
                        foreach (var a in alertsToUpdate)
                        {
                            a.Status = "Processing";
                        }
                    }
                    else
                    {
                        var hasProcessing = await _context.StockAlerts
                            .AnyAsync(a => a.Sku == materialSku && a.Status == "Processing");
                        if (!hasProcessing)
                        {
                            _context.StockAlerts.Add(new StockAlert
                            {
                                Sku = materialSku,
                                PackagingType = "Standard Roll",
                                QuantityRequested = (int)draftQty,
                                Status = "Processing",
                                WorkerId = "Auto-Replenish-Bot",
                                Timestamp = DateTime.UtcNow
                            });
                        }
                    }
                    await _context.SaveChangesAsync();
                }
                catch (Exception dbEx)
                {
                    _logger.LogError(dbEx, "Failed to persist pending PurchaseOrder for AI replenishment workflow");
                }
            }

            return new
            {
                workflow_id = wfId,
                status = workflowStatus,
                current_agent = currentAgent,
                requires_approval = requiresApproval,
                approval_status = approvalStatus,
                purchase_order_id = createdPoId,
                po_number = finalPoNumber ?? draftPoNumber ?? "PO-PENDING",
                supplier_name = draftSupplierName,
                material_name = materialName,
                material_sku = materialSku,
                quantity = draftQty,
                unit_price = draftUnitPrice,
                total_amount = totalAmount,
                agent_result = agentRawResult,
                objective = objective
            };
        }
    }
}