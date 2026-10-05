using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using backend.Dtos;
using backend.Models;
using ManufacturingCoordinator.DTOs.PurchaseOrders;

namespace backend.Services
{
    public class AgentIntegrationService : IAgentIntegrationService
    {
        private readonly Microsoft.AspNetCore.Http.IHttpContextAccessor? _httpContext;
        private readonly HttpClient _httpClient;
        private readonly ILogger<AgentIntegrationService> _logger;
        private readonly string _agentApiKey;

        public AgentIntegrationService(
            HttpClient httpClient,
            IConfiguration configuration,
            ILogger<AgentIntegrationService> logger, Microsoft.AspNetCore.Http.IHttpContextAccessor? httpContext = null)
        {
            _httpContext = httpContext;
            _httpClient = httpClient;
            _logger = logger;

            var agentBaseUrl = configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            _httpClient.BaseAddress = new Uri(agentBaseUrl);
            var authorization = _httpContext?.HttpContext?.Request.Headers.Authorization.ToString();
            if (!string.IsNullOrEmpty(authorization))
                _httpClient.DefaultRequestHeaders.TryAddWithoutValidation("Authorization", authorization);

            _agentApiKey = configuration["AgentServer:ApiKey"] ?? "default-dev-key";
            if (!_httpClient.DefaultRequestHeaders.Contains("X-API-Key"))
                _httpClient.DefaultRequestHeaders.Add("X-API-Key", _agentApiKey);
        }

        public async Task<AgentPredictionResponseDto> TriggerLowStockEvaluationAsync(InventoryItem item)
        {
            try
            {
                var payload = new List<InventoryItem> { item };
                var response = await _httpClient.PostAsJsonAsync("/api/predict", payload);
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<AgentPredictionResponseDto>();
                    if (result?.Predictions != null && result.Predictions.Count > 0)
                    {
                        return result;
                    }
                }
                else
                {
                    _logger.LogWarning("AI Agent server /api/predict responded with status {StatusCode}", response.StatusCode);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to connect to agent evaluation endpoint for SKU {Sku}. Using deterministic fallback.", item.Sku);
            }

            // High-reliability deterministic fallback when agent service is restarting or unavailable
            var isLow = item.StockLevel <= item.ReorderThreshold;
            var deficit = Math.Max(0, item.ReorderThreshold - item.StockLevel);
            var riskScore = isLow ? Math.Min(1.0, 0.65 + ((double)deficit / (item.ReorderThreshold + 1)) * 0.35) : 0.15;

            return new AgentPredictionResponseDto
            {
                Status = "Success",
                Predictions = new List<AgentPredictionDto>
                {
                    new AgentPredictionDto
                    {
                        Sku = item.Sku,
                        RiskScore = Math.Round(riskScore, 2),
                        RecommendedAction = isLow ? "Reorder" : "Maintain"
                    }
                }
            };
        }

        public async Task<List<SupplierCandidateDto>> ResearchProcurementSuppliersAsync(
            string materialName, string specification, decimal requiredQuantity, string? preferredRegion)
        {
            var (_, candidates) = await ResearchProcurementSuppliersWithWorkflowAsync(
                materialName, specification, requiredQuantity, preferredRegion,
                netDeficit: requiredQuantity);
            return candidates;
        }

        /// <summary>
        /// Posts to the internal Python FastAPI LangGraph route:
        ///   POST /api/workflows/run
        /// Returns (workflowId, candidates). If the AI service is unreachable, returns (null, fallback_candidates).
        ///
        /// ARCHITECTURE:
        ///   React/Flutter → ASP.NET Core → THIS METHOD → Python FastAPI
        ///   React and Flutter NEVER call FastAPI directly.
        /// </summary>
        public async Task<(string? workflowId, List<SupplierCandidateDto> candidates)> ResearchProcurementSuppliersWithWorkflowAsync(
            string materialName, string specification, decimal requiredQuantity, string? preferredRegion,
            string? materialId = null, decimal? currentStock = null, decimal? safetyStock = null,
            decimal? openPOQuantity = null, decimal? netDeficit = null, decimal? budgetLimit = null,
            string? unit = null, string? qualityRequirement = null, string? requiredByDate = null,
            int? procurementRequestId = null)
        {
            string workflowId = "wf-" + Guid.NewGuid().ToString("N")[..12];

            try
            {
                var payload = new
                {
                    objective = $"Procure raw material '{materialName}' ({specification}) — net deficit {netDeficit ?? requiredQuantity} {unit ?? "units"} — budget LKR {budgetLimit ?? 0:F2}",
                    workflowId,
                    procurementRequestId,
                    triggerType = "Manual",
                    requestedQuantity = requiredQuantity,
                    materialId,
                    materialName,
                    specification,
                    currentStock,
                    requiredQuantity,
                    safetyStock,
                    openPOQuantity,
                    netDeficit = netDeficit ?? requiredQuantity,   // authoritative deficit
                    budgetLimit,
                    currency = "LKR",
                    unit,
                    qualityRequirement,
                    preferredRegion = preferredRegion ?? "Sri Lanka",
                    requiredByDate
                };

                var response = await _httpClient.PostAsJsonAsync("/api/workflows/run", payload);

                if (response.IsSuccessStatusCode)
                {
                    var rawJson = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(rawJson);
                    var root = doc.RootElement;

                    // Extract workflowId from response if provided
                    if (root.TryGetProperty("workflow_id", out var wfElement) && wfElement.GetString() is string wfFromServer)
                        workflowId = wfFromServer;

                    // Parse candidates from purchasing_data or supplierCandidates / supplier_candidates
                    var candidates = new List<SupplierCandidateDto>();
                    JsonElement suppliersEl = default;
                    bool hasSuppliers = false;

                    if (root.TryGetProperty("supplierCandidates", out var scEl) && scEl.ValueKind == JsonValueKind.Array && scEl.GetArrayLength() > 0)
                    {
                        suppliersEl = scEl;
                        hasSuppliers = true;
                    }
                    else if (root.TryGetProperty("supplier_candidates", out var scEl2) && scEl2.ValueKind == JsonValueKind.Array && scEl2.GetArrayLength() > 0)
                    {
                        suppliersEl = scEl2;
                        hasSuppliers = true;
                    }
                    else if (root.TryGetProperty("purchasing_data", out var pdElement) && pdElement.ValueKind == JsonValueKind.Object &&
                             pdElement.TryGetProperty("suppliers", out var scEl3) && scEl3.ValueKind == JsonValueKind.Array && scEl3.GetArrayLength() > 0)
                    {
                        suppliersEl = scEl3;
                        hasSuppliers = true;
                    }

                    if (hasSuppliers)
                    {
                        foreach (var s in suppliersEl.EnumerateArray())
                        {
                            candidates.Add(new SupplierCandidateDto
                            {
                                SupplierName = GetString(s, "supplierName", "supplier_name", "supplier") ?? "Unknown Supplier",
                                MaterialName = GetString(s, "materialName", "material_name") ?? materialName,
                                UnitPrice = GetDecimal(s, 0m, "unitPrice", "unit_price"),
                                Currency = GetString(s, "currency") ?? "LKR",
                                MinimumOrderQuantity = GetDecimal(s, 0m, "minimumOrderQuantity", "minimum_order_quantity", "moq"),
                                PackSize = GetDecimal(s, 1m, "packSize", "pack_size"),
                                LeadTimeDays = GetInt(s, 0, "leadTimeDays", "lead_time_days"),
                                QualityEvidence = GetString(s, "qualityEvidence", "quality_evidence", "certification") ?? string.Empty,
                                Availability = GetString(s, "availabilityStatus", "availability", "stock_status") ?? "Unknown",
                                SupplierStatus = GetString(s, "supplierStatus", "verificationStatus") ?? "UNVERIFIED",
                                ConfidenceScore = GetDecimal(s, 0m, "confidenceScore", "confidence_score"),
                                SourceUrl = GetString(s, "sourceUrl", "source_url", "url")
                            });
                        }
                    }
                    else if ((root.TryGetProperty("recommendedSupplier", out var recEl) || root.TryGetProperty("recommended_supplier", out recEl)) &&
                             recEl.ValueKind == JsonValueKind.Object)
                    {
                        candidates.Add(new SupplierCandidateDto
                        {
                            SupplierName = GetString(recEl, "supplierName", "supplier_name", "supplier") ?? "Unknown Supplier",
                            MaterialName = GetString(recEl, "materialName", "material_name") ?? materialName,
                            UnitPrice = GetDecimal(recEl, 0m, "unitPrice", "unit_price"),
                            Currency = GetString(recEl, "currency") ?? "LKR",
                            MinimumOrderQuantity = GetDecimal(recEl, 0m, "minimumOrderQuantity", "minimum_order_quantity", "moq"),
                            PackSize = GetDecimal(recEl, 1m, "packSize", "pack_size"),
                            LeadTimeDays = GetInt(recEl, 0, "leadTimeDays", "lead_time_days"),
                            QualityEvidence = GetString(recEl, "qualityEvidence", "quality_evidence") ?? string.Empty,
                            Availability = GetString(recEl, "availabilityStatus", "availability") ?? "Unknown",
                            SupplierStatus = GetString(recEl, "supplierStatus", "verificationStatus") ?? "UNVERIFIED",
                            ConfidenceScore = GetDecimal(recEl, 0m, "confidenceScore", "confidence_score"),
                            SourceUrl = GetString(recEl, "sourceUrl", "source_url")
                        });
                    }

                    if (candidates.Count > 0)
                        return (workflowId, candidates);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "AI service unreachable during procurement research for '{Material}'. Returning empty candidates.",
                    materialName);
            }

            // ── No Fallback Mock Data Permitted ───────────────────────────
            return (workflowId, new List<SupplierCandidateDto>());
        }

        // ── Helpers ───────────────────────────────────────────────────────────────

        private static string? GetString(JsonElement element, params string[] keys)
        {
            foreach (var key in keys)
                if (element.TryGetProperty(key, out var prop) && prop.ValueKind == JsonValueKind.String)
                    return prop.GetString();
            return null;
        }

        private static decimal GetDecimal(JsonElement element, decimal @default, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (element.TryGetProperty(key, out var prop))
                {
                    if (prop.ValueKind == JsonValueKind.Number) return prop.GetDecimal();
                    if (prop.ValueKind == JsonValueKind.String && decimal.TryParse(prop.GetString(), out var d)) return d;
                }
            }
            return @default;
        }

        private static int GetInt(JsonElement element, int @default, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (element.TryGetProperty(key, out var prop))
                {
                    if (prop.ValueKind == JsonValueKind.Number) return prop.GetInt32();
                    if (prop.ValueKind == JsonValueKind.String && int.TryParse(prop.GetString(), out var i)) return i;
                }
            }
            return @default;
        }
    }
}
