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
            var decision = dto.Decision?.Trim();

            var supplierPassed = !resultsDict.TryGetValue("supplierValidation", out var sv) || sv?.ToString() == "PASSED";
            var budgetPassed = !resultsDict.TryGetValue("budgetCheck", out var bc) || bc?.ToString() == "PASSED";
            var poMathPassed = !resultsDict.TryGetValue("poMathematicalCheck", out var pm) || pm?.ToString() == "PASSED";
            var materialPassed = !resultsDict.TryGetValue("materialValidation", out var mv) || mv?.ToString() == "PASSED";
            var allFourChecksPassed = supplierPassed && budgetPassed && poMathPassed && materialPassed;

            if (string.Equals(decision, "Reject", StringComparison.OrdinalIgnoreCase) || 
                string.Equals(decision, "QARejected", StringComparison.OrdinalIgnoreCase))
            {
                resultsDict["manualResolutionStatus"] = "REJECTED";
                resultsDict["qualitySafetyStatus"] = "REJECTED";
                resultsDict["isValid"] = false;
                resultsDict["rejectionReason"] = $"Manual QA Review rejected by QA Inspector: {dto.Note.Trim()}";
            }
            else if (string.Equals(decision, "Keep on Hold", StringComparison.OrdinalIgnoreCase) || 
                     string.Equals(decision, "OnHold", StringComparison.OrdinalIgnoreCase) ||
                     string.Equals(decision, "Hold", StringComparison.OrdinalIgnoreCase))
            {
                resultsDict["manualResolutionStatus"] = "ON_HOLD";
                resultsDict["qualitySafetyStatus"] = "ON_HOLD";
                resultsDict["isValid"] = false;
                resultsDict["rejectionReason"] = $"Manual QA Review placed on hold: {dto.Note.Trim()}";
            }
            else
            {
                // Clear / QACleared
                resultsDict["manualResolutionStatus"] = "RESOLVED";
                resultsDict["qualitySafetyStatus"] = "CLEAR";
                resultsDict["isValid"] = allFourChecksPassed;
                if (allFourChecksPassed)
                {
                    resultsDict["rejectionReason"] = null;
                }
            }

            resultsDict["manualResolutionNote"] = dto.Note.Trim();
            resultsDict["resolvedBy"] = userName;
            resultsDict["resolvedAt"] = resolvedTime;

            wf.ValidationResults = JsonSerializer.Serialize(resultsDict);

            // Release active quarantines ONLY if explicitly requested and decision was Clear
            if (dto.ReleaseQuarantine && resultsDict["manualResolutionStatus"]?.ToString() == "RESOLVED")
            {
                string? targetRoll = null;
                string? targetMaterial = null;

                if (resultsDict.TryGetValue("historicalRisk", out var hrObj) && hrObj != null)
                {
                    if (hrObj is JsonElement hrElem && hrElem.ValueKind == JsonValueKind.Object)
                    {
                        if (hrElem.TryGetProperty("relatedRoll", out var rr)) targetRoll = rr.GetString();
                        if (hrElem.TryGetProperty("material", out var mat)) targetMaterial = mat.GetString();
                    }
                    else if (hrObj is Dictionary<string, object?> hrDict)
                    {
                        if (hrDict.TryGetValue("relatedRoll", out var rr)) targetRoll = rr?.ToString();
                        if (hrDict.TryGetValue("material", out var mat)) targetMaterial = mat?.ToString();
                    }
                    else if (hrObj is string hrStr && !string.IsNullOrWhiteSpace(hrStr))
                    {
                        try
                        {
                            using var doc = JsonDocument.Parse(hrStr);
                            if (doc.RootElement.TryGetProperty("relatedRoll", out var rr)) targetRoll = rr.GetString();
                            if (doc.RootElement.TryGetProperty("material", out var mat)) targetMaterial = mat.GetString();
                        }
                        catch { }
                    }
                }

                var activeQuarantines = await _context.Quarantines
                    .Include(q => q.DefectReport)
                    .Where(q => q.Status == QuarantineStatus.Active)
                    .ToListAsync(cancellationToken);

                foreach (var q in activeQuarantines)
                {
                    bool isRelevant = false;
                    if (!string.IsNullOrEmpty(targetRoll) && (q.InventoryRollId == targetRoll || q.InventoryRollId.Contains(targetRoll, StringComparison.OrdinalIgnoreCase)))
                    {
                        isRelevant = true;
                    }
                    else if (!string.IsNullOrEmpty(targetMaterial) && q.DefectReport != null && q.DefectReport.Description.Contains(targetMaterial, StringComparison.OrdinalIgnoreCase))
                    {
                        isRelevant = true;
                    }
                    else if (string.IsNullOrEmpty(targetRoll) && string.IsNullOrEmpty(targetMaterial))
                    {
                        isRelevant = true;
                    }

                    if (isRelevant)
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
            string? impactReason = null;
            string? rejectionReason = null;
            string? manualResolutionStatus = null;
            string? manualResolutionNote = null;
            string? resolvedBy = null;
            string? resolvedAt = null;
            bool? isValid = null;
            object? historicalRisk = null;

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
                    impactReason           = GetString(root, "impactReason");
                    rejectionReason        = GetString(root, "rejectionReason");
                    manualResolutionStatus = GetString(root, "manualResolutionStatus");
                    manualResolutionNote   = GetString(root, "manualResolutionNote");
                    resolvedBy             = GetString(root, "resolvedBy");
                    resolvedAt             = GetString(root, "resolvedAt");

                    if (root.TryGetProperty("historicalRisk", out var hrElem) && hrElem.ValueKind == JsonValueKind.Object)
                    {
                        historicalRisk = JsonSerializer.Deserialize<object>(hrElem.GetRawText());
                    }
                }
                catch
                {
                    // ignored
                }
            }

            string workflowStatus;
            if (manualResolutionStatus == "RESOLVED")
            {
                workflowStatus = "Resolved";
            }
            else if (manualResolutionStatus == "REJECTED")
            {
                workflowStatus = "Rejected";
            }
            else if (manualResolutionStatus == "ON_HOLD")
            {
                workflowStatus = "OnHold";
            }
            else if (isValid == true && (qualitySafetyStatus == "CLEAR" || qualitySafetyStatus == "PASSED") && (quarantinedRollsCount == null || quarantinedRollsCount == 0))
            {
                workflowStatus = "Verified";
            }
            else if (qualitySafetyStatus == "MANUAL_REVIEW_REQUIRED" || manualResolutionStatus == "PENDING_REVIEW")
            {
                workflowStatus = "ManualReviewRequired";
            }
            else if (isValid == false || (quarantinedRollsCount != null && quarantinedRollsCount > 0) || qualitySafetyStatus?.Contains("QUARANTINE", StringComparison.OrdinalIgnoreCase) == true)
            {
                workflowStatus = "PendingReview";
            }
            else
            {
                workflowStatus = wf.Status.ToString();
            }

            var assessedTime = resolvedAt ?? wf.CompletedAt?.ToString("o") ?? wf.StartedAt.ToString("o");

            return new
            {
                workflowId             = wf.WorkflowId,
                status                 = workflowStatus,
                isValid                = isValid,
                qualitySafetyStatus    = qualitySafetyStatus,
                supplierValidation     = supplierValidation,
                budgetCheck            = budgetCheck,
                poMathematicalCheck    = poMathematicalCheck,
                materialValidation     = materialValidation,
                quarantinedRollsCount  = quarantinedRollsCount,
                impactReason           = impactReason,
                rejectionReason        = rejectionReason,
                manualResolutionStatus = manualResolutionStatus,
                manualResolutionNote   = manualResolutionNote,
                resolvedBy             = resolvedBy,
                resolvedAt             = resolvedAt,
                historicalRisk         = historicalRisk,
                startedAt              = wf.StartedAt.ToString("o"),
                completedAt            = wf.CompletedAt?.ToString("o"),
                assessedAt             = assessedTime
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
