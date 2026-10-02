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
            // Inventory records are now created from the material catalogue.
            // Do not infer new raw materials from arbitrary legacy item text.
            return await _context.InventoryItems
                .AsNoTracking()
                .OrderBy(item => item.Sku)
                .Select(item => new InventoryItemDto
                {
                    Id = item.Id,
                    Sku = item.Sku,
                    Name = item.Name,
                    Category = item.Category,
                    PackagingTypeId = item.PackagingTypeId,
                    RawMaterialId = item.RawMaterialId,
                    SkuNumber = item.SkuNumber,
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

        public async Task<InventoryItem> CreateInventoryItemFromSkuAsync(CreateInventoryItemRequest request)
        {
            var packagingType = await _context.PackagingTypes
                .FirstOrDefaultAsync(type => type.Id == request.PackagingTypeId && type.IsActive);
            if (packagingType == null)
            {
                throw new InvalidOperationException("The selected packaging type was not found.");
            }

            var materialTemplate = await _context.RawMaterials
                .FirstOrDefaultAsync(material => material.Id == request.RawMaterialId);
            if (materialTemplate == null || materialTemplate.PackagingTypeId != packagingType.Id)
            {
                throw new InvalidOperationException("The selected raw material is not available for that packaging type.");
            }

            var sku = BuildSku(packagingType.ShortCode, materialTemplate.MaterialCode, request.SkuNumber);
            if (await _context.InventoryItems.AnyAsync(item => item.Sku == sku))
            {
                throw new InvalidOperationException($"SKU {sku} already exists. Enter the next sequence number.");
            }

            // A raw-material row represents a traceable, purchasable material
            // SKU. Reuse a seeded row when the requested SKU exists; otherwise
            // clone only its catalogue metadata and let the server set the SKU.
            var materialSku = await _context.RawMaterials
                .FirstOrDefaultAsync(material => material.SkuCode == sku);
            if (materialSku == null)
            {
                materialSku = new RawMaterial
                {
                    SkuCode = sku,
                    Name = materialTemplate.Name,
                    Description = materialTemplate.Description,
                    Category = packagingType.Name,
                    MaterialCode = materialTemplate.MaterialCode,
                    PackagingTypeId = packagingType.Id,
                    UnitOfMeasure = materialTemplate.UnitOfMeasure,
                    ReorderThreshold = request.ReorderThreshold > 0
                        ? request.ReorderThreshold
                        : materialTemplate.ReorderThreshold,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                _context.RawMaterials.Add(materialSku);
                await _context.SaveChangesAsync();
            }

            var item = new InventoryItem
            {
                Sku = sku,
                Name = materialSku.Name,
                Category = packagingType.Name,
                PackagingTypeId = packagingType.Id,
                RawMaterialId = materialSku.Id,
                SkuNumber = request.SkuNumber,
                StockLevel = request.StockLevel,
                ReorderThreshold = request.ReorderThreshold,
            };
            _context.InventoryItems.Add(item);
            await _context.SaveChangesAsync();
            return item;
        }

        public async Task<bool> UpdateInventoryItemAsync(int id, InventoryItem item)
        {
            if (id != item.Id) return false;
            var existing = await _context.InventoryItems.FindAsync(id);
            if (existing == null) return false;

            // Packaging type, raw material and the server-generated SKU are
            // immutable after creation. Stock counts are the only editable
            // values on an existing material SKU.
            existing.StockLevel = item.StockLevel;
            existing.ReorderThreshold = item.ReorderThreshold;
            await _context.SaveChangesAsync();
            return true;
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
            var newestAlertIdsBySku = _context.StockAlerts
                .GroupBy(alert => alert.Sku)
                .Select(group => group.Max(alert => alert.Id));

            return await _context.StockAlerts
                .AsNoTracking()
                // A floor-worker card represents the newest saved alert for a
                // SKU.  The grouped subquery prevents old duplicate rows from
                // appearing as repeated cards in the returned JSON.
                .Where(alert => newestAlertIdsBySku.Contains(alert.Id))
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
            var resolved = await ResolveCatalogueSkuAsync(alertDto);
            alertDto.Sku = resolved.Sku;
            alertDto.PackagingType = resolved.PackagingType;

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
            if (alert == null) return false;
            alert.Status = newStatus;
            await _context.SaveChangesAsync();
            return true;
        }

        // ========== Student 1: Raw Material CRUD ==========

        public async Task<IEnumerable<RawMaterial>> GetRawMaterialsAsync()
        {
            return await _context.RawMaterials
                // The list endpoint only needs the material catalogue.  Loading
                // both child collections here creates a Cartesian join and can
                // duplicate rows (or fail under warning-as-error settings).
                // Detail endpoints load related data only when it is needed.
                .AsNoTracking()
                .OrderBy(r => r.PackagingTypeId)
                .ThenBy(r => r.MaterialCode)
                .ThenBy(r => r.SkuCode)
                .ToListAsync();
        }

        public async Task<IEnumerable<PackagingType>> GetPackagingTypesAsync()
        {
            return await _context.PackagingTypes
                .AsNoTracking()
                .Where(type => type.IsActive)
                .OrderBy(type => type.Name)
                .ToListAsync();
        }

        public async Task<RawMaterial?> GetRawMaterialByIdAsync(int id)
        {
            return await _context.RawMaterials
                .Include(r => r.InventoryRolls)
                .Include(r => r.StockLevels)
                .FirstOrDefaultAsync(r => r.Id == id);
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

        public async Task<bool> UpdateRawMaterialAsync(int id, RawMaterial material)
        {
            if (id != material.Id) return false;
            var existing = await _context.RawMaterials.FindAsync(id);
            if (existing == null) return false;

            existing.Name = material.Name;
            existing.SkuCode = material.SkuCode;
            existing.Description = material.Description;
            existing.Category = material.Category;
            existing.MaterialCode = material.MaterialCode;
            existing.PackagingTypeId = material.PackagingTypeId;
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

        private async Task<(string Sku, string PackagingType)> ResolveCatalogueSkuAsync(CreateStockAlertDto alertDto)
        {
            RawMaterial? material;
            PackagingType? packagingType;

            if (alertDto.PackagingTypeId.HasValue &&
                alertDto.RawMaterialId.HasValue)
            {
                packagingType = await _context.PackagingTypes
                    .FirstOrDefaultAsync(type => type.Id == alertDto.PackagingTypeId.Value && type.IsActive);
                material = await _context.RawMaterials
                    .FirstOrDefaultAsync(rawMaterial => rawMaterial.Id == alertDto.RawMaterialId.Value);

                if (packagingType == null || material == null || material.PackagingTypeId != packagingType.Id)
                {
                    throw new InvalidOperationException("The selected packaging type and raw material do not match.");
                }

                // Older API consumers may still send an SKU sequence number.
                // The floor-worker form does not: its catalogue selection is
                // sufficient to find the traceable inventory SKU.
                var requestedSku = alertDto.SkuNumber.HasValue
                    ? BuildSku(packagingType.ShortCode, material.MaterialCode, alertDto.SkuNumber.Value)
                    : material.SkuCode;
                var inventoryItem = alertDto.SkuNumber.HasValue
                    ? await _context.InventoryItems
                        .FirstOrDefaultAsync(item => item.Sku == requestedSku)
                    : await _context.InventoryItems
                        .FirstOrDefaultAsync(item =>
                            item.Sku == requestedSku || item.RawMaterialId == material.Id);
                if (inventoryItem == null)
                {
                    throw new InvalidOperationException(
                        "The selected raw material is not an inventory item. Add it to stock before reporting low stock.");
                }
                return (inventoryItem.Sku, packagingType.Name);
            }

            material = await _context.RawMaterials
                .FirstOrDefaultAsync(rawMaterial => rawMaterial.SkuCode == alertDto.Sku.Trim());
            if (material == null)
            {
                throw new InvalidOperationException("Select an SKU from the inventory catalogue.");
            }

            packagingType = await _context.PackagingTypes
                .FirstOrDefaultAsync(type => type.Id == material.PackagingTypeId && type.IsActive);
            if (packagingType == null || !await _context.InventoryItems.AnyAsync(item => item.Sku == material.SkuCode))
            {
                throw new InvalidOperationException("The selected SKU is not an active inventory item.");
            }
            return (material.SkuCode, packagingType.Name);
        }

        private static string BuildSku(string packagingCode, string materialCode, int sequence) =>
            $"{packagingCode.Trim().ToUpperInvariant()}-{materialCode.Trim().ToUpperInvariant()}-{sequence:D3}";

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

            var currentSkuStock = await _context.InventoryItems
                .AsNoTracking()
                .Where(item => item.Sku == roll.RawMaterial!.SkuCode)
                .Select(item => (decimal?)item.StockLevel)
                .FirstOrDefaultAsync() ?? 0m;

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
                CurrentSkuStock = currentSkuStock,
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
            if (roll.InitialQuantity != decimal.Truncate(roll.InitialQuantity))
            {
                throw new InvalidOperationException("Roll quantity must be a whole number.");
            }

            var rawMaterial = await _context.RawMaterials.FindAsync(roll.RawMaterialId);
            if (rawMaterial == null)
            {
                throw new InvalidOperationException("The selected raw material was not found.");
            }

            var inventoryItem = await _context.InventoryItems
                .FirstOrDefaultAsync(item => item.Sku == rawMaterial.SkuCode);
            if (inventoryItem == null)
            {
                throw new InvalidOperationException(
                    "The selected SKU is not an inventory item. Add stock before registering a roll.");
            }

            if (string.IsNullOrWhiteSpace(roll.RollIdentifier))
            {
                // The mobile app normally builds ROLL-{SKU}-{roll number}.
                // Keep a safe fallback for older API consumers that omit the
                // identifier while still making the QR code roll-specific.
                roll.RollIdentifier = $"ROLL-{Guid.NewGuid():N}";
            }
            else if (await _context.InventoryRolls.AnyAsync(existingRoll =>
                existingRoll.RollIdentifier.ToUpper() == roll.RollIdentifier.Trim().ToUpper()))
            {
                throw new InvalidOperationException(
                    "That roll identifier is already registered for this SKU.");
            }
            else
            {
                roll.RollIdentifier = roll.RollIdentifier.Trim().ToUpperInvariant();
            }
            // Store only this application's QR endpoint. The mobile app never
            // receives a third-party provider URL or calls a missing helper.
            roll.BarcodeUrl = $"/api/inventory/rolls/{Uri.EscapeDataString(roll.RollIdentifier)}/qr";
            roll.CreatedAt = DateTime.UtcNow;
            roll.UpdatedAt = DateTime.UtcNow;
            if (roll.ReceivedDate == default) roll.ReceivedDate = DateTime.UtcNow;
            roll.CurrentQuantity = roll.InitialQuantity;
            roll.Status = "In Stock";

            // Registering a physical roll is a goods-received event. The roll
            // gives the incoming stock its QR traceability and its quantity is
            // added to the same SKU balance shown by Stock Levels.
            inventoryItem.StockLevel = checked(
                inventoryItem.StockLevel + decimal.ToInt32(roll.InitialQuantity));
            rawMaterial.UpdatedAt = DateTime.UtcNow;
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
            var materialsById = materials.ToDictionary(material => material.Id);
            var inventoryItems = await _context.InventoryItems
                .AsNoTracking()
                .OrderBy(item => item.Sku)
                .ToListAsync();

            var list = new List<StockLevelDetailDto>();

            // Stock Levels is intentionally inventory-item driven. It shows
            // every registered SKU, including stock with no roll yet, and the
            // value is the live balance updated when a roll is received.
            foreach (var item in inventoryItems)
            {
                materialsById.TryGetValue(item.RawMaterialId ?? 0, out var material);
                material ??= materials.FirstOrDefault(candidate =>
                    candidate.SkuCode.Equals(item.Sku, StringComparison.OrdinalIgnoreCase));

                var currentStock = (decimal)item.StockLevel;
                var burnRate = material == null ? 0m : GetBurnRate(material);
                var minStock = item.ReorderThreshold > 0
                    ? item.ReorderThreshold
                    : material?.ReorderThreshold ?? 0m;
                var maxStock = minStock * 5m;
                var daysRemaining = CalculateDaysRemaining(currentStock, burnRate);

                var status = currentStock <= (minStock * 0.5m) || daysRemaining <= 3 ? "CRITICAL" :
                             currentStock <= minStock || daysRemaining <= 7 ? "LOW" : "NORMAL";

                list.Add(new StockLevelDetailDto
                {
                    Id = item.Id,
                    RawMaterialId = material?.Id ?? item.RawMaterialId ?? 0,
                    SkuCode = item.Sku,
                    MaterialName = string.IsNullOrWhiteSpace(item.Name)
                        ? material?.Name ?? item.Sku
                        : item.Name,
                    CurrentStock = currentStock,
                    MinimumStock = minStock,
                    MaximumStock = maxStock,
                    BurnRate = burnRate,
                    DaysRemaining = daysRemaining,
                    Status = status,
                    UpdatedAt = material?.UpdatedAt ?? DateTime.UtcNow
                });
            }

            return list;
        }

        private decimal GetBurnRate(RawMaterial material)
        {
            var rolls = material.InventoryRolls.ToList();
            var historicalConsumption = rolls
                .Where(roll => roll.InitialQuantity > roll.CurrentQuantity)
                .Sum(roll => roll.InitialQuantity - roll.CurrentQuantity);
            var firstRecordedAt = rolls
                .Select(roll => roll.ReceivedDate)
                .DefaultIfEmpty(material.CreatedAt)
                .Min();
            var recordedDays = Math.Max(
                1,
                (int)Math.Ceiling((DateTime.UtcNow - firstRecordedAt).TotalDays));

            return CalculateBurnRate(historicalConsumption, recordedDays);
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

            var inventoryItem = await _context.InventoryItems
                .AsNoTracking()
                .FirstOrDefaultAsync(item =>
                    item.RawMaterialId == material.Id || item.Sku == material.SkuCode);
            var currentStock = (decimal)(inventoryItem?.StockLevel ?? 0);
            var burnRate = GetBurnRate(material);
            var minStock = inventoryItem?.ReorderThreshold > 0
                ? inventoryItem.ReorderThreshold
                : material.ReorderThreshold;
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

        public async Task<object> TriggerAgentReplenishmentAsync(
            TriggerReplenishmentDto dto,
            string? authorizationHeader)
        {
            if (string.IsNullOrWhiteSpace(dto.MaterialId))
            {
                throw new ArgumentException("Select a material before starting the AI workflow.");
            }
            if (dto.RequiredQuantity <= 0)
            {
                throw new ArgumentException("Requested quantity must be greater than zero.");
            }

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
                throw new ArgumentException("The selected material no longer exists. Refresh and choose it again.");
            }

            var materialSku = material.SkuCode;
            var materialName = material.Name;

            string? wfId = null;
            string? currentAgent = null;
            string? workflowStatus = null;
            string? approvalStatus = null;
            bool requiresApproval = false;
            decimal draftQty = dto.RequiredQuantity;
            decimal draftUnitPrice = 0m;
            string? draftSupplierCode = null;
            string? draftSupplierName = null;
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

                using var agentRequest = new HttpRequestMessage(
                    HttpMethod.Post,
                    $"{agentBaseUrl}/api/workflows/trigger")
                {
                    Content = JsonContent.Create(payload)
                };
                if (!string.IsNullOrWhiteSpace(authorizationHeader))
                {
                    agentRequest.Headers.TryAddWithoutValidation("Authorization", authorizationHeader);
                }

                var resp = await client.SendAsync(agentRequest);
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
                    var agentError = await resp.Content.ReadAsStringAsync();
                    throw new HttpRequestException(
                        $"The AI agent could not start the workflow ({(int)resp.StatusCode}). {agentError}".Trim());
                }
            }
            catch (HttpRequestException)
            {
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Agent AI microservice is unavailable");
                throw new HttpRequestException(
                    "The AI agent is unavailable. Start the AI service and try again.", ex);
            }

            if (string.IsNullOrWhiteSpace(wfId))
            {
                throw new HttpRequestException("The AI agent returned a workflow without an ID.");
            }

            // 3. Create or Sync Purchase Order in ApplicationDbContext for Supply Chain Manager
            int? createdPoId = null;
            string? finalPoNumber = null;
            decimal totalAmount = draftQty * draftUnitPrice;

            if (_appContext != null &&
                !string.IsNullOrWhiteSpace(draftSupplierCode) &&
                !string.IsNullOrWhiteSpace(draftSupplierName) &&
                draftUnitPrice > 0)
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
                                PackagingType = material!.Category,
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
