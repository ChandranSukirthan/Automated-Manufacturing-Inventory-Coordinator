using backend.Models;
using System.Collections.Generic;
using System.Threading.Tasks;
using backend.Dtos;

namespace backend.Services
{
    public interface IInventoryService
    {
        // Legacy/Generic Inventory Items
        Task<IEnumerable<InventoryItemDto>> GetInventoryItemsAsync();
        Task<InventoryItem?> GetInventoryItemByIdAsync(int id);
        Task<InventoryItem> CreateInventoryItemAsync(InventoryItem item);
        Task<bool> UpdateInventoryItemAsync(int id, InventoryItem item);
        Task<bool> DeleteInventoryItemAsync(int id);
        Task<InventoryItem> CreateInventoryItemFromSkuAsync(CreateInventoryItemRequest request);

        // Stock Alerts
        Task<IEnumerable<StockAlertResponseDto>> GetStockAlertsAsync();
        Task<StockAlertResponseDto?> GetStockAlertByIdAsync(int id);
        Task<IEnumerable<StockAlertResponseDto>> GetUnreadStockAlertsAsync();
        Task<bool> MarkStockAlertAsReadAsync(int id);
        Task<StockAlertResponseDto> CreateStockAlertAsync(CreateStockAlertDto alertDto);
        Task<bool> UpdateAlertStatusAsync(int id, string newStatus);
        Task ResolveAlertsForMaterialsAsync(IEnumerable<int> materialIds);

        // Student 1: Raw Material CRUD
        Task<IEnumerable<RawMaterial>> GetRawMaterialsAsync();
        Task<RawMaterial?> GetRawMaterialByIdAsync(int id);
        Task<RawMaterial> CreateRawMaterialAsync(RawMaterial material);
        Task<bool> UpdateRawMaterialAsync(int id, RawMaterial material);
        Task<bool> DeleteRawMaterialAsync(int id);
        Task<IEnumerable<PackagingType>> GetPackagingTypesAsync();

        // Student 1: Inventory Roll CRUD & QR Lookup
        Task<IEnumerable<InventoryRoll>> GetInventoryRollsAsync();
        Task<InventoryRoll?> GetInventoryRollByIdAsync(int id);
        Task<InventoryRoll?> GetInventoryRollByIdentifierAsync(string rollIdentifier);
        Task<QrLookupResultDto?> GetInventoryRollByQrAsync(string qrCode);
        Task<InventoryRoll> CreateInventoryRollAsync(InventoryRoll roll);
        Task<bool> UpdateInventoryRollAsync(int id, InventoryRoll roll);
        Task<bool> DeleteInventoryRollAsync(int id);

        // Student 1: Stock Levels & Business Calculations
        Task<IEnumerable<StockLevelDetailDto>> GetStockLevelsAsync();
        Task<StockLevel> CreateStockLevelAsync(StockLevel stockLevel);
        decimal CalculateBurnRate(decimal historicalConsumption, int numberOfDays);
        decimal CalculateDaysRemaining(decimal currentStock, decimal burnRate);
        Task<LowStockItemDto> DetectLowStockAsync(int rawMaterialId);
        Task<IEnumerable<LowStockItemDto>> GetLowStockItemsAsync();
        Task<IEnumerable<InventoryHistoryItemDto>> GetInventoryHistoryAsync(int rawMaterialId);

        // Student 1: Proxy AI Trigger via ASP.NET Core
        Task<object> TriggerAgentReplenishmentAsync(TriggerReplenishmentDto dto, string? authorizationHeader);
    }
}
