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
        /// Research supplier candidates for a procurement request using the existing list-based API.
        /// </summary>
        Task<List<SupplierCandidateDto>> ResearchProcurementSuppliersAsync(
            string materialName, string specification, decimal requiredQuantity, string? preferredRegion);

        /// <summary>
        /// Research suppliers AND capture the LangGraph WorkflowId for audit trail.
        /// Returns (workflowId, candidates). workflowId may be null if FastAPI is unreachable.
        /// </summary>
        Task<(string? workflowId, List<SupplierCandidateDto> candidates)> ResearchProcurementSuppliersWithWorkflowAsync(
            string materialName, string specification, decimal requiredQuantity, string? preferredRegion);
    }
}
