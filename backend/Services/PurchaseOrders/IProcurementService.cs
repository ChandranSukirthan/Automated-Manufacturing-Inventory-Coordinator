using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Models.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public interface IProcurementService
    {
        Task<ProcurementResponseDto> CreateRequestAsync(CreateProcurementRequestDto dto, Guid? createdById = null);
        Task<ProcurementResponseDto> RunAiResearchAsync(int procurementRequestId);
        Task<ProcurementResponseDto?> GetByIdAsync(int id);
        Task<IEnumerable<ProcurementResponseDto>> GetAllAsync();
        Task<PurchaseOrderResponseDto> CreateDraftPoFromCandidateAsync(int procurementRequestId, int candidateId, Guid? userId = null);
        Task<ProcurementResponseDto> VerifyAndOnboardSupplierAsync(int procurementRequestId, int candidateId, VerifySupplierCandidateDto dto, Guid? userId = null);

        // Deterministic Mathematical Operations
        decimal CalculateNetRequiredQuantity(decimal prodRequirement, decimal safetyStock, decimal currentStock, decimal openPoQuantity);
        (decimal finalQuantity, decimal totalCost) CalculateOrderQuantityAndCost(decimal netQuantity, decimal moq, decimal packSize, decimal unitPrice);
        CandidateValidationResultDto ValidateCandidate(SupplierCandidate candidate, ProcurementRequest request);
    }
}
