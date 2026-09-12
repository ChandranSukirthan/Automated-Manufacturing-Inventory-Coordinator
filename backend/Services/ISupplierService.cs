using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public interface ISupplierService
    {
        Task<IEnumerable<SupplierResponseDto>> GetAllAsync();
        Task<SupplierResponseDto?> GetByIdAsync(int id);
        Task<SupplierResponseDto> CreateAsync(CreateSupplierDto dto);
        Task<SupplierResponseDto?> UpdateAsync(int id, UpdateSupplierDto dto);
        Task<bool> DeleteAsync(int id);
    }
}

