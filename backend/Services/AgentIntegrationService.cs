using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using backend.Models;
using backend.Dtos;
using System;

namespace backend.Services
{
    public class AgentIntegrationService : IAgentIntegrationService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<AgentIntegrationService> _logger;
        private readonly string _agentApiKey;

        public AgentIntegrationService(HttpClient httpClient, IConfiguration configuration, ILogger<AgentIntegrationService> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
            
            var agentBaseUrl = configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            _httpClient.BaseAddress = new Uri(agentBaseUrl);
            
            // For security, an API key or bearer token should be passed to the Python subsystem
            _agentApiKey = configuration["AgentServer:ApiKey"] ?? "default-dev-key";
            if (!_httpClient.DefaultRequestHeaders.Contains("X-API-Key"))
            {
                _httpClient.DefaultRequestHeaders.Add("X-API-Key", _agentApiKey);
            }
        }

        public async Task<AgentPredictionResponseDto> TriggerLowStockEvaluationAsync(InventoryItem item)
        {
            try
            {
                // We wrap the item in a list since the agent_server expects List[InventoryItem]
                var payload = new List<InventoryItem> { item };
                
                var response = await _httpClient.PostAsJsonAsync("/api/predict", payload);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadFromJsonAsync<AgentPredictionResponseDto>();
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to trigger agent evaluation for SKU {Sku}", item.Sku);
                throw;
            }
        }
    }
}

