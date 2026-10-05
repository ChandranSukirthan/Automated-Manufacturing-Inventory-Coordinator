using System.Collections.Generic;
using System.Threading.Tasks;
using backend.Models;
using backend.Dtos;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace backend.Services
{
    public interface IAgentIntegrationService
    {
        Task<AgentPredictionResponseDto> TriggerLowStockEvaluationAsync(InventoryItem item);

        /// <summary>
        /// Research supplier candidates for a procurement request.
        /// </summary>
        Task<List<SupplierCandidateDto>> ResearchProcurementSuppliersAsync(
            string materialName, string specification, decimal requiredQuantity, string? preferredRegion);

        /// <summary>
        /// Research suppliers AND capture the LangGraph WorkflowId for audit trail.
        /// All authoritative procurement values are passed to the Python AI service.
        /// The AI never invents netDeficit, currentStock, budgetLimit, or safetyStock.
        /// Returns (workflowId, candidates). workflowId may be null if FastAPI is unreachable.
        /// </summary>
        Task<(string? workflowId, List<SupplierCandidateDto> candidates)> ResearchProcurementSuppliersWithWorkflowAsync(
            string materialName,
            string specification,
            decimal requiredQuantity,
            string? preferredRegion,
            string? materialId = null,
            decimal? currentStock = null,
            decimal? safetyStock = null,
            decimal? openPOQuantity = null,
            decimal? netDeficit = null,
            decimal? budgetLimit = null,
            string? unit = null,
            string? qualityRequirement = null,
            string? requiredByDate = null,
            int? procurementRequestId = null);
    }
}
