using System.Linq;
using System.Net.Http;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/quality")]
    [Authorize(Roles = "QualityInspector,ITAdmin")]
    public class QualityAiValidationController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;

        public QualityAiValidationController(
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
        }

        [HttpGet("ai-validation")]
        public async Task<IActionResult> GetLatest(CancellationToken cancellationToken)
        {
            var baseUrl = _configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(5);
            try
            {
                using var response = await client.GetAsync($"{baseUrl.TrimEnd('/')}/api/workflows", cancellationToken);
                if (!response.IsSuccessStatusCode)
                    return StatusCode(502, new { message = "AI workflow service error." });
                await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
                using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
                if (document.RootElement.ValueKind != JsonValueKind.Array)
                    return StatusCode(502, new { message = "Unexpected response." });
                JsonElement? latestWorkflow = null;
                var latestValidation = default(JsonElement);
                foreach (var workflow in document.RootElement.EnumerateArray())
                {
                    if (workflow.ValueKind != JsonValueKind.Object) continue;
                    var wfId = GetString(workflow, "workflow_id") ?? string.Empty;
                    if (!wfId.StartsWith("WF-QA-", StringComparison.OrdinalIgnoreCase) &&
                        !wfId.StartsWith("WF-DEFECT-", StringComparison.OrdinalIgnoreCase)) continue;
                    if (!workflow.TryGetProperty("validation_results", out var validation) ||
                        validation.ValueKind != JsonValueKind.Object ||
                        !validation.EnumerateObject().Any()) continue;
                    latestWorkflow = workflow;
                    latestValidation = validation;
                }
                if (latestWorkflow is null) return NoContent();
                return Ok(new {
                    workflowId            = GetString(latestWorkflow.Value, "workflow_id"),
                    status                = GetString(latestWorkflow.Value, "status"),
                    qualitySafetyStatus   = GetString(latestValidation, "qualitySafetyStatus"),
                    quarantinedRollsCount = GetInt32(latestValidation, "quarantinedRollsCount"),
                    isHighImpact          = GetBoolean(latestValidation, "isHighImpact"),
                    impactReason          = GetString(latestValidation, "impactReason")
                });
            }
            catch (HttpRequestException) { return StatusCode(503, new { message = "AI service unavailable." }); }
            catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return StatusCode(504, new { message = "AI service timeout." }); }
            catch (JsonException) { return StatusCode(502, new { message = "Invalid AI service response." }); }
        }

        [HttpGet("ai-validation/history")]
        public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
        {
            var baseUrl = _configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(5);
            try
            {
                using var response = await client.GetAsync($"{baseUrl.TrimEnd('/')}/api/workflows", cancellationToken);
                if (!response.IsSuccessStatusCode)
                    return StatusCode(502, new { message = "AI workflow service error." });
                await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
                using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
                if (document.RootElement.ValueKind != JsonValueKind.Array)
                    return StatusCode(502, new { message = "Unexpected response." });
                var historyList = new List<object>();
                foreach (var workflow in document.RootElement.EnumerateArray())
                {
                    if (workflow.ValueKind != JsonValueKind.Object) continue;
                    var wfId = GetString(workflow, "workflow_id") ?? string.Empty;
                    if (!wfId.StartsWith("WF-QA-", StringComparison.OrdinalIgnoreCase) &&
                        !wfId.StartsWith("WF-DEFECT-", StringComparison.OrdinalIgnoreCase)) continue;
                    if (!workflow.TryGetProperty("validation_results", out var validation) ||
                        validation.ValueKind != JsonValueKind.Object ||
                        !validation.EnumerateObject().Any()) continue;
                    historyList.Add(new {
                        workflowId            = wfId,
                        status                = GetString(workflow, "status"),
                        qualitySafetyStatus   = GetString(validation, "qualitySafetyStatus"),
                        quarantinedRollsCount = GetInt32(validation, "quarantinedRollsCount"),
                        isHighImpact          = GetBoolean(validation, "isHighImpact"),
                        impactReason          = GetString(validation, "impactReason")
                    });
                }
                historyList.Reverse();
                return Ok(historyList);
            }
            catch (HttpRequestException) { return StatusCode(503, new { message = "AI service unavailable." }); }
            catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return StatusCode(504, new { message = "AI service timeout." }); }
            catch (JsonException) { return StatusCode(502, new { message = "Invalid AI service response." }); }
        }

        private static string? GetString(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        private static int? GetInt32(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out var r) ? r : (int?)null;
        private static bool? GetBoolean(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && (v.ValueKind == JsonValueKind.True || v.ValueKind == JsonValueKind.False) ? v.GetBoolean() : (bool?)null;
    }
}
