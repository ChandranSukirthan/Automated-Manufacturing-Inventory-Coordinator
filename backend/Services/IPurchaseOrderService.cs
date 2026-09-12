using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Models.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public interface IPurchaseOrderService
    {
        Task<IEnumerable<PurchaseOrderSummaryDto>> GetAllAsync();
        Task<PurchaseOrderResponseDto?> GetByIdAsync(int id);
        Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto, Guid? createdById = null);
        Task<PurchaseOrderResponseDto?> UpdateAsync(int id, UpdatePurchaseOrderDto dto);
        Task<PurchaseOrderResponseDto> SubmitForApprovalAsync(int id, Guid? userId = null);
        Task<PurchaseOrderResponseDto> ApproveAsync(int id, Guid approverId, string? notes = null);
        Task<PurchaseOrderResponseDto> RejectAsync(int id, Guid approverId, string? reason);
        Task<PurchaseOrderResponseDto> RequestRevisionAsync(int id, Guid approverId, string? reason);

        // Explicit business operations (Requirements 1, 2, 3, 4)
        decimal CalculateTotalCost(PurchaseOrder po);
        void ValidateBudget(PurchaseOrder po);
        Task<Supplier> ValidateSupplierAsync(int supplierId);
        Task ValidatePurchaseOrderAsync(PurchaseOrder po);
    }
}
