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
        Task<List<SupplierCandidateDto>> ResearchProcurementSuppliersAsync(string materialName, string specification, decimal requiredQuantity, string? preferredRegion);
    }
}
