using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public interface IPurchaseOrderService
    {
        Task<IEnumerable<PurchaseOrderSummaryDto>> GetAllAsync();
        Task<PurchaseOrderResponseDto?> GetByIdAsync(int id);
        Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto);
        Task<PurchaseOrderResponseDto?> UpdateAsync(int id, UpdatePurchaseOrderDto dto);
        Task<PurchaseOrderResponseDto> SubmitForApprovalAsync(int id);
        Task<PurchaseOrderResponseDto> ApproveAsync(int id, int approverId);
        Task<PurchaseOrderResponseDto> RejectAsync(int id, int approverId, string? reason);
        Task<PurchaseOrderResponseDto> RequestRevisionAsync(int id, int approverId, string? reason);
    }
}

