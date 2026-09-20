using backend.Models;
using System.Collections.Generic;
using System.Threading.Tasks;
using backend.Dtos;

namespace backend.Services
{
    public interface IInventoryService
    {
        Task<IEnumerable<InventoryItemDto>> GetInventoryItemsAsync();
        Task<InventoryItem> GetInventoryItemByIdAsync(int id);
        Task<IEnumerable<StockAlertResponseDto>> GetStockAlertsAsync();
        Task<StockAlertResponseDto> CreateStockAlertAsync(CreateStockAlertDto alertDto);
        Task<InventoryItem> CreateInventoryItemAsync(InventoryItem item);
        Task<bool> UpdateInventoryItemAsync(int id, InventoryItem item);
        Task<bool> DeleteInventoryItemAsync(int id);
        
        // Student A - New Method for Inventory Roll and Raw Material
        Task<InventoryRoll> CreateInventoryRollAsync(InventoryRoll roll);
        Task<RawMaterial> CreateRawMaterialAsync(RawMaterial material);
    }
}
