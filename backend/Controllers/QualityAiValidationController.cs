using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Api.DTOs.Quality;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/quality")]
    [Authorize]
    public class QualityAiValidationController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IHttpClientFactory? _clients;
        private readonly IConfiguration? _configuration;

        public QualityAiValidationController(ApplicationDbContext context, IHttpClientFactory? clients = null, IConfiguration? configuration = null)
        {
            _context = context;
            _clients = clients;
            _configuration = configuration;
        }

        [HttpGet("ai-validation")]
        public async Task<IActionResult> GetLatest([FromQuery] string? workflowId, CancellationToken cancellationToken)
        {
            IQueryable<AgentWorkflow> query = _context.AgentWorkflows
                .AsNoTracking()
                .Where(w => w.ValidationResults != null);

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

            var po = wf.PurchaseOrderId.HasValue ? await _context.PurchaseOrders.AsNoTracking()
                .Include(p => p.OrderLines).ThenInclude(l => l.RawMaterial)
                .SingleOrDefaultAsync(p => p.Id == wf.PurchaseOrderId, cancellationToken) : null;
            return Ok(MapWorkflowToValidationDto(wf, po));
        }

        [HttpGet("ai-validation/history")]
        public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
        {
            var workflows = await _context.AgentWorkflows
                .AsNoTracking()
                .Where(w => w.ValidationResults != null)
                .OrderByDescending(w => w.StartedAt)
                .ToListAsync(cancellationToken);

            var poIds = workflows.Where(w => w.PurchaseOrderId.HasValue).Select(w => w.PurchaseOrderId!.Value).Distinct().ToList();
            var orders = await _context.PurchaseOrders.AsNoTracking().Where(p => poIds.Contains(p.Id))
                .Include(p => p.OrderLines).ThenInclude(l => l.RawMaterial).ToDictionaryAsync(p => p.Id, cancellationToken);
            var historyList = workflows.Select(w => MapWorkflowToValidationDto(w,
                w.PurchaseOrderId.HasValue ? orders.GetValueOrDefault(w.PurchaseOrderId.Value) : null)).ToList();

            return Ok(historyList);
        }

        [HttpPost("ai-validation/{workflowId}/resolve")]
        [Authorize(Roles = "QualityInspector")]
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
                                resultsDict[prop.Name] = prop.Value.Clone();
                                break;
                        }
                    }
                }
                catch { }
            }

            var resolvedTime = DateTime.UtcNow.ToString("o");
            var decision = dto.Decision?.Trim();

            if (decision is not ("Clear" or "QACleared" or "Reject" or "QARejected" or "Keep on Hold" or "OnHold" or "Hold"))
                return BadRequest(new { message = "Choose Clear, Reject or Hold." });

            var allFourChecksPassed = ManufacturingCoordinator.Api.Helpers.QualityValidationPolicy.NonQualityChecksPassed(resultsDict);

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

            // Sync with PurchaseOrder entity if found
            PurchaseOrder? linkedPo = null;
            if (wf.PurchaseOrderId.HasValue)
                linkedPo = await _context.PurchaseOrders.FirstOrDefaultAsync(p => p.Id == wf.PurchaseOrderId, cancellationToken);
            var poNumMatch = Regex.Match(wf.WorkflowId, @"(PO-\d{4}-\d+)");
            if (linkedPo == null && poNumMatch.Success)
            {
                linkedPo = await _context.PurchaseOrders.FirstOrDefaultAsync(p => p.PoNumber == poNumMatch.Value, cancellationToken);
            }
            if (linkedPo == null)
            {
                linkedPo = await _context.PurchaseOrders.FirstOrDefaultAsync(p => p.Notes != null && p.Notes.Contains(wf.WorkflowId), cancellationToken);
            }
            if (linkedPo != null)
            {
                if (resultsDict["manualResolutionStatus"]?.ToString() == "RESOLVED")
                {
                    linkedPo.RejectionReason = null;
                }
                else if (resultsDict["manualResolutionStatus"]?.ToString() == "REJECTED")
                {
                    linkedPo.RejectionReason = $"QA validation rejected by {userName}: {dto.Note.Trim()}";
                }
                else if (resultsDict["manualResolutionStatus"]?.ToString() == "ON_HOLD")
                {
                    linkedPo.RejectionReason = $"QA validation on hold: {dto.Note.Trim()}";
                }
            }

            // Release active quarantines ONLY if explicitly requested and decision was Clear
            if (dto.ReleaseQuarantine && resultsDict["manualResolutionStatus"]?.ToString() == "RESOLVED")
            {
                // A material link permits safety checks, never a bulk release of every roll.
                var rollIds = new List<string>();
                if (resultsDict.TryGetValue("historicalRisk", out var history) && history != null)
                {
                    using var historyDoc = JsonDocument.Parse(history.ToString()!);
                    if (historyDoc.RootElement.TryGetProperty("relatedRoll", out var related) && related.ValueKind == JsonValueKind.String)
                        rollIds.Add(related.GetString()!);
                }
                var holds = await _context.Quarantines.Include(q => q.DefectReport)
                    .Where(q => q.Status == QuarantineStatus.Active).ToListAsync(cancellationToken);
                var relevant = holds.Where(q => rollIds.Contains(q.InventoryRollId)).ToList();
                if (relevant.Count == 0)
                    return Conflict(new { message = "No explicitly linked active quarantine was found. Release the specific quarantine from its details page." });
                var quarantineService = new ManufacturingCoordinator.Api.Services.QuarantineService(_context);
                foreach (var hold in relevant)
                    await quarantineService.ReleaseAsync(hold.Id, dto.Note, userName);
            }

            if (resultsDict["manualResolutionStatus"]?.ToString() == "RESOLVED")
            {
                var materialIds = linkedPo == null ? new List<int>() : await _context.OrderLines
                    .Where(l => l.PurchaseOrderId == linkedPo.Id).Select(l => l.RawMaterialId).ToListAsync(cancellationToken);
                var rollIds = await _context.StockRolls.Where(r => materialIds.Contains(r.RawMaterialId))
                    .Select(r => r.RollIdentifier).ToListAsync(cancellationToken);
                var skus = await _context.RawMaterials.Where(m => materialIds.Contains(m.Id))
                    .Select(m => m.SkuCode).ToListAsync(cancellationToken);
                if (resultsDict.TryGetValue("historicalRisk", out var risk) && risk != null)
                {
                    using var historyDoc = JsonDocument.Parse(risk.ToString()!);
                    if (historyDoc.RootElement.TryGetProperty("relatedRoll", out var roll) && roll.ValueKind == JsonValueKind.String)
                        rollIds.Add(roll.GetString()!);
                }
                var remaining = await _context.Quarantines.CountAsync(q => q.Status == QuarantineStatus.Active &&
                    (rollIds.Contains(q.InventoryRollId) || skus.Contains(q.DefectReport.SkuCode)), cancellationToken);
                resultsDict["quarantinedRollsCount"] = remaining;
                resultsDict["qualitySafetyStatus"] = remaining > 0 ? "QUARANTINE_ACTIVE" : "CLEAR";
                resultsDict["isValid"] = allFourChecksPassed && remaining == 0;
                if (remaining > 0) resultsDict["rejectionReason"] = "Active quarantine remains. Release the specific held rolls after inspection.";
            }
            wf.ValidationResults = JsonSerializer.Serialize(resultsDict);

            await _context.SaveChangesAsync(cancellationToken);

            // Persist QA evidence first. Python revalidates finance and live holds before routing.
            if (_clients != null && resultsDict["manualResolutionStatus"]?.ToString() == "RESOLVED" &&
                wf.PurchaseOrderId == null && !string.IsNullOrWhiteSpace(wf.StateJson))
            {
                var baseUrl = (_configuration?["AgentServer:BaseUrl"] ?? "http://localhost:8000").TrimEnd('/');
                try
                {
                    using var request = new HttpRequestMessage(HttpMethod.Post,
                        $"{baseUrl}/api/workflows/{Uri.EscapeDataString(workflowId)}/revalidate");
                    request.Headers.TryAddWithoutValidation("Authorization", Request.Headers.Authorization.ToString());
                    using var response = await _clients.CreateClient().SendAsync(request, cancellationToken);
                    if (response.IsSuccessStatusCode)
                    {
                        await _context.Entry(wf).ReloadAsync(cancellationToken);
                        await new ManufacturingCoordinator.Services.PurchaseOrders.WorkflowDraftService(_context).FinalizeAsync(workflowId);
                    }
                    else
                        return Ok(new { review = MapWorkflowToValidationDto(wf), revalidationPending = true,
                            message = "QA decision saved. Retry the workflow to complete fresh validation." });
                }
                catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
                {
                    return Ok(new { review = MapWorkflowToValidationDto(wf), revalidationPending = true,
                        message = "QA decision saved. AI revalidation is unavailable; retry the workflow when the service returns." });
                }
            }
            return Ok(MapWorkflowToValidationDto(wf));
        }

        private static object MapWorkflowToValidationDto(AgentWorkflow wf, PurchaseOrder? purchaseOrder = null)
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
            object? checkedSupplier = null;
            object? validationHistory = null;
            string? bestChoiceCheck = null;
            int? attemptNumber = null;
            int? maxAttempts = null;

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
                    bestChoiceCheck        = GetString(root, "bestChoiceCheck");
                    attemptNumber          = GetInt32(root, "attemptNumber");
                    maxAttempts            = GetInt32(root, "maxAttempts");

                    if (root.TryGetProperty("historicalRisk", out var hrElem) && hrElem.ValueKind == JsonValueKind.Object)
                    {
                        historicalRisk = JsonSerializer.Deserialize<object>(hrElem.GetRawText());
                    }
                    if (root.TryGetProperty("checkedSupplier", out var supplierElem) && supplierElem.ValueKind == JsonValueKind.Object)
                    {
                        checkedSupplier = JsonSerializer.Deserialize<object>(supplierElem.GetRawText());
                    }
                    if (root.TryGetProperty("validationHistory", out var historyElem) && historyElem.ValueKind == JsonValueKind.Array)
                    {
                        validationHistory = JsonSerializer.Deserialize<object>(historyElem.GetRawText());
                    }
                }
                catch
                {
                    // ignored
                }
            }

            string workflowStatus;
            if (isValid == true)
            {
                workflowStatus = "Verified";
            }
            else if (isValid == false)
            {
                workflowStatus = "Failed";
            }
            else if (manualResolutionStatus == "REJECTED")
            {
                workflowStatus = "Rejected";
            }
            else if (manualResolutionStatus == "ON_HOLD")
            {
                workflowStatus = "OnHold";
            }
            else
            {
                workflowStatus = wf.Status.ToString();
            }

            var assessedTime = resolvedAt ?? wf.CompletedAt?.ToString("o") ?? wf.StartedAt.ToString("o");
            string? materialId = null, materialName = null, unit = null;
            decimal? quantity = null;
            var validationExecuted = supplierValidation != null || materialValidation != null;
            if (!string.IsNullOrWhiteSpace(wf.StateJson))
            {
                try
                {
                    using var stateDocument = JsonDocument.Parse(wf.StateJson);
                    var state = stateDocument.RootElement;
                    materialId = GetString(state, "material_id");
                    materialName = GetString(state, "material_name");
                    unit = GetString(state, "unit");
                    if (state.TryGetProperty("required_quantity", out var requested) && requested.ValueKind == JsonValueKind.Number)
                        quantity = requested.GetDecimal();
                    if (state.TryGetProperty("draft_po", out var draft) && draft.ValueKind == JsonValueKind.Object &&
                        draft.TryGetProperty("quantity", out var purchased) && purchased.ValueKind == JsonValueKind.Number)
                        quantity = purchased.GetDecimal();
                    if (state.TryGetProperty("completed_steps", out var steps) && steps.ValueKind == JsonValueKind.Array)
                        validationExecuted |= steps.EnumerateArray().Any(s => s.ValueKind == JsonValueKind.String &&
                            s.GetString()!.StartsWith("Validation/Safety:", StringComparison.Ordinal));
                }
                catch (JsonException) { }
            }

            if (purchaseOrder?.OrderLines.Count == 1)
            {
                var line = purchaseOrder.OrderLines.Single();
                materialId ??= line.RawMaterial?.SkuCode;
                materialName ??= line.RawMaterial?.Name ?? line.Description;
                quantity ??= line.Quantity;
                unit ??= line.RawMaterial?.UnitOfMeasure;
            }

            return new
            {
                workflowId             = wf.WorkflowId,
                workflowType           = wf.WorkflowType,
                workflowStatus         = wf.Status.ToString(),
                objective              = wf.Objective,
                purchaseOrderId        = wf.PurchaseOrderId,
                materialId,
                materialName,
                quantity,
                unit,
                validationExecuted,
                purchaseOrderNumber    = purchaseOrder?.PoNumber,
                items                  = purchaseOrder?.OrderLines.Select(l => new {
                    materialId = l.RawMaterial?.SkuCode, materialName = l.RawMaterial?.Name ?? l.Description,
                    quantity = l.Quantity, unit = l.RawMaterial?.UnitOfMeasure
                }).ToArray(),
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
                checkedSupplier        = checkedSupplier,
                validationHistory      = validationHistory,
                bestChoiceCheck        = bestChoiceCheck,
                attemptNumber          = attemptNumber,
                maxAttempts            = maxAttempts,
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
