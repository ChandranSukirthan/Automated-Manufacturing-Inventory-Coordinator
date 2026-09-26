using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Models.PurchaseOrders;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public interface IProcurementService
    {
        // ── Request Lifecycle ─────────────────────────────────────────────────────
        Task<ProcurementResponseDto> CreateRequestAsync(CreateProcurementRequestDto dto, Guid? createdById = null);
        Task<ProcurementResponseDto> RunAiResearchAsync(int procurementRequestId);
        Task<ProcurementResponseDto?> GetByIdAsync(int id);
        Task<IEnumerable<ProcurementResponseDto>> GetAllAsync();

        // ── Candidates ────────────────────────────────────────────────────────────
        Task<IEnumerable<SupplierCandidateDto>> GetCandidatesAsync(int procurementRequestId);
        Task<ProcurementRecommendationDto> GetRecommendationAsync(int procurementRequestId);

        // ── Draft PO Generation ───────────────────────────────────────────────────
        Task<PurchaseOrderResponseDto> CreateDraftPoFromCandidateAsync(int procurementRequestId, int candidateId, Guid? userId = null);

        // ── Supplier Verification ─────────────────────────────────────────────────
        Task<ProcurementResponseDto> VerifyAndOnboardSupplierAsync(int procurementRequestId, int candidateId, VerifySupplierCandidateDto dto, Guid? userId = null);

        // ── Flutter Status Tracking ───────────────────────────────────────────────
        Task<ProcurementStatusTrackingDto?> GetStatusTrackingAsync(int procurementRequestId);

        // ── Future Learning Outcomes Dataset (Requirement 12) ────────────────────
        Task<IEnumerable<ProcurementOutcome>> GetOutcomesAsync();

        // ── Deterministic Mathematical Operations (used by validation engine) ─────
        decimal CalculateNetRequiredQuantity(decimal prodRequirement, decimal safetyStock, decimal currentStock, decimal openPoQuantity);
        (decimal finalQuantity, decimal totalCost) CalculateOrderQuantityAndCost(decimal netQuantity, decimal moq, decimal packSize, decimal unitPrice);
        CandidateValidationResultDto ValidateCandidate(SupplierCandidate candidate, ProcurementRequest request);
    }
}
