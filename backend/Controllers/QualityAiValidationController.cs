using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Api.DTOs.Quality;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/quality")]
    [Authorize]
    public class QualityAiValidationController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public QualityAiValidationController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet("ai-validation")]
        public async Task<IActionResult> GetLatest([FromQuery] string? workflowId, CancellationToken cancellationToken)
        {
            IQueryable<AgentWorkflow> query = _context.AgentWorkflows
                .AsNoTracking()
                .Where(w => w.ValidationResults != null || w.WorkflowId.StartsWith("WF-QA-") || w.WorkflowId.StartsWith("WF-DEFECT-") || w.WorkflowId.StartsWith("WF-"));

            if (!string.IsNullOrWhiteSpace(workflowId))
            {
                query = query.Where(w => w.WorkflowId == workflowId);
            }
            else
            {
                query = query.OrderByDescending(w => w.ValidationResults != null).ThenByDescending(w => w.StartedAt);
            }

            var wf = await (string.IsNullOrWhiteSpace(workflowId)
                ? query.FirstOrDefaultAsync(cancellationToken)
                : query.OrderByDescending(w => w.StartedAt).FirstOrDefaultAsync(cancellationToken));

            if (wf is null) return NoContent();

            return Ok(MapWorkflowToValidationDto(wf));
        }

        [HttpGet("ai-validation/history")]
        public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
        {
            var workflows = await _context.AgentWorkflows
                .AsNoTracking()
                .Where(w => w.ValidationResults != null || w.WorkflowId.StartsWith("WF-QA-") || w.WorkflowId.StartsWith("WF-DEFECT-") || w.WorkflowId.StartsWith("WF-"))
                .OrderByDescending(w => w.StartedAt)
                .ToListAsync(cancellationToken);

            var historyList = workflows.Select(MapWorkflowToValidationDto).ToList();

            return Ok(historyList);
        }

        [HttpPost("ai-validation/{workflowId}/resolve")]
        [Authorize(Roles = "QualityInspector,ITAdmin")]
        public async Task<IActionResult> ResolveWorkflow(string workflowId, [FromBody] ResolveValidationRequestDto dto, CancellationToken cancellationToken)
        {
            var wf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowId == workflowId, cancellationToken);
            if (wf == null) return NotFound(new { message = $"Workflow {workflowId} not found." });

            if (string.IsNullOrWhiteSpace(dto.Note))
            {
                return BadRequest(new { message = "A manual resolution note is required." });
            }

            var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            string? userName = null;
            if (!string.IsNullOrEmpty(currentUserId) && Guid.TryParse(currentUserId, out var uid))
            {
                var user = await _context.Users.FindAsync(new object[] { uid }, cancellationToken);
                userName = user?.FullName;
            }
            userName ??= User.FindFirstValue(ClaimTypes.Name) 
                         ?? User.FindFirstValue(ClaimTypes.Email) 
                         ?? "QualityInspector";

            var resultsDict = new Dictionary<string, object?>();
            if (!string.IsNullOrWhiteSpace(wf.ValidationResults))
            {
                try
                {
                    using var doc = JsonDocument.Parse(wf.ValidationResults);
                    foreach (var prop in doc.RootElement.EnumerateObject())
                    {
                        switch (prop.Value.ValueKind)
                        {
                            case JsonValueKind.String:
                                resultsDict[prop.Name] = prop.Value.GetString();
                                break;
                            case JsonValueKind.Number:
                                if (prop.Value.TryGetInt32(out var i)) resultsDict[prop.Name] = i;
                                else if (prop.Value.TryGetDouble(out var d)) resultsDict[prop.Name] = d;
                                break;
                            case JsonValueKind.True:
                                resultsDict[prop.Name] = true;
                                break;
                            case JsonValueKind.False:
                                resultsDict[prop.Name] = false;
                                break;
                            case JsonValueKind.Null:
                                resultsDict[prop.Name] = null;
                                break;
                            default:
                                resultsDict[prop.Name] = prop.Value.GetRawText();
                                break;
                        }
                    }
                }
                catch { }
            }

            var resolvedTime = DateTime.UtcNow.ToString("o");
            resultsDict["manualResolutionStatus"] = "RESOLVED";
            resultsDict["manualResolutionNote"] = dto.Note.Trim();
            resultsDict["resolvedBy"] = userName;
            resultsDict["resolvedAt"] = resolvedTime;

            // Preserve original AI finding and reason in ValidationResults
            if (!resultsDict.ContainsKey("qualitySafetyStatus") || resultsDict["qualitySafetyStatus"] == null)
            {
                resultsDict["qualitySafetyStatus"] = "QUARANTINE_REQUIRED";
            }

            wf.ValidationResults = JsonSerializer.Serialize(resultsDict);

            // Release active quarantines if requested
            if (dto.ReleaseQuarantine)
            {
                var activeQuarantines = await _context.Quarantines
                    .Where(q => q.Status == QuarantineStatus.Active)
                    .ToListAsync(cancellationToken);

                foreach (var q in activeQuarantines)
                {
                    q.Status = QuarantineStatus.Released;
                    q.ReleasedAt = DateTime.UtcNow;

                    var roll = await _context.InventoryRolls.FirstOrDefaultAsync(r => r.Id == q.InventoryRollId, cancellationToken);
                    if (roll != null)
                    {
                        roll.Status = InventoryStatus.Available;
                    }
                }
            }

            await _context.SaveChangesAsync(cancellationToken);

            return Ok(MapWorkflowToValidationDto(wf));
        }

        private static object MapWorkflowToValidationDto(AgentWorkflow wf)
        {
            string? qualitySafetyStatus = null;
            string? supplierValidation = null;
            string? budgetCheck = null;
            string? poMathematicalCheck = null;
            string? materialValidation = null;
            int? quarantinedRollsCount = null;
            bool? isHighImpact = null;
            string? impactReason = null;
            string? rejectionReason = null;
            string? manualResolutionStatus = null;
            string? manualResolutionNote = null;
            string? resolvedBy = null;
            string? resolvedAt = null;
            bool? isValid = null;

            if (!string.IsNullOrWhiteSpace(wf.ValidationResults))
            {
                try
                {
                    using var doc = JsonDocument.Parse(wf.ValidationResults);
                    var root = doc.RootElement;
                    isValid                = GetBoolean(root, "isValid");
                    qualitySafetyStatus    = GetString(root, "qualitySafetyStatus");
                    supplierValidation     = GetString(root, "supplierValidation");
                    budgetCheck            = GetString(root, "budgetCheck");
                    poMathematicalCheck    = GetString(root, "poMathematicalCheck");
                    materialValidation     = GetString(root, "materialValidation");
                    quarantinedRollsCount  = GetInt32(root, "quarantinedRollsCount");
                    isHighImpact           = GetBoolean(root, "isHighImpact");
                    impactReason           = GetString(root, "impactReason");
                    rejectionReason        = GetString(root, "rejectionReason");
                    manualResolutionStatus = GetString(root, "manualResolutionStatus");
                    manualResolutionNote   = GetString(root, "manualResolutionNote");
                    resolvedBy             = GetString(root, "resolvedBy");
                    resolvedAt             = GetString(root, "resolvedAt");
                }
                catch
                {
                    // ignored
                }
            }

            return new
            {
                workflowId             = wf.WorkflowId,
                status                 = wf.Status.ToString(),
                isValid                = isValid,
                qualitySafetyStatus    = qualitySafetyStatus,
                supplierValidation     = supplierValidation,
                budgetCheck            = budgetCheck,
                poMathematicalCheck    = poMathematicalCheck,
                materialValidation     = materialValidation,
                quarantinedRollsCount  = quarantinedRollsCount,
                isHighImpact           = isHighImpact,
                impactReason           = impactReason,
                rejectionReason        = rejectionReason,
                manualResolutionStatus = manualResolutionStatus,
                manualResolutionNote   = manualResolutionNote,
                resolvedBy             = resolvedBy,
                resolvedAt             = resolvedAt
            };
        }

        private static string? GetString(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        private static int? GetInt32(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out var r) ? r : (int?)null;
        private static bool? GetBoolean(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && (v.ValueKind == JsonValueKind.True || v.ValueKind == JsonValueKind.False) ? v.GetBoolean() : (bool?)null;
    }
}
