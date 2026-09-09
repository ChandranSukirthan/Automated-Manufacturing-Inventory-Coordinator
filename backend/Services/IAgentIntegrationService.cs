using System.Threading.Tasks;
using backend.Models;
using backend.Dtos;

namespace backend.Services
{
    public interface IAgentIntegrationService
    {
        Task<AgentPredictionResponseDto> TriggerLowStockEvaluationAsync(InventoryItem item);
    }
}

