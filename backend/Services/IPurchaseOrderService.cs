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
        Task<PurchaseOrderResponseDto> ProcessPaymentAsync(int id, Guid? approverId = null, bool forceDispatch = false);
        Task<PurchaseOrderResponseDto> UploadBankSlipAsync(int id, Microsoft.AspNetCore.Http.IFormFile file, string referenceNumber, string? notes = null, Guid? userId = null);
        Task<PurchaseOrderTrackingDto> GetTrackingAsync(int id);
        Task<byte[]> GeneratePdfAsync(int id);
        Task<bool> DeleteAsync(int id);

        // OrderLine sub-resource CRUD (Requirement 5)
        Task<IEnumerable<OrderLineResponseDto>> GetOrderLinesAsync(int poId);
        Task<OrderLineResponseDto> AddOrderLineAsync(int poId, OrderLineDto dto);
        Task<OrderLineResponseDto> UpdateOrderLineAsync(int poId, int lineId, OrderLineDto dto);
        Task<bool> DeleteOrderLineAsync(int poId, int lineId);

        // Explicit business operations (Requirements 1, 2, 3, 4)
        decimal CalculateTotalCost(PurchaseOrder po);
        void ValidateBudget(PurchaseOrder po);
        Task<Supplier> ValidateSupplierAsync(int supplierId);
        Task ValidatePurchaseOrderAsync(PurchaseOrder po);
    }
}
