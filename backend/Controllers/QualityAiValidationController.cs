using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Models.Administration;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/quality")]
    [Authorize(Roles = "QualityInspector,ITAdmin")]
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
                .Where(w => w.WorkflowId.StartsWith("WF-QA-") || w.WorkflowId.StartsWith("WF-DEFECT-"));

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

            string? qualitySafetyStatus = null;
            int? quarantinedRollsCount = null;
            bool? isHighImpact = null;
            string? impactReason = null;

            if (!string.IsNullOrWhiteSpace(wf.ValidationResults))
            {
                try
                {
                    using var doc = JsonDocument.Parse(wf.ValidationResults);
                    var root = doc.RootElement;
                    qualitySafetyStatus = GetString(root, "qualitySafetyStatus");
                    quarantinedRollsCount = GetInt32(root, "quarantinedRollsCount");
                    isHighImpact = GetBoolean(root, "isHighImpact");
                    impactReason = GetString(root, "impactReason");
                }
                catch
                {
                    // ignored
                }
            }

            return Ok(new
            {
                workflowId            = wf.WorkflowId,
                status                = wf.Status.ToString(),
                qualitySafetyStatus   = qualitySafetyStatus,
                quarantinedRollsCount = quarantinedRollsCount,
                isHighImpact          = isHighImpact,
                impactReason          = impactReason
            });
        }

        [HttpGet("ai-validation/history")]
        public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
        {
            var workflows = await _context.AgentWorkflows
                .AsNoTracking()
                .Where(w => w.WorkflowId.StartsWith("WF-QA-") || w.WorkflowId.StartsWith("WF-DEFECT-"))
                .OrderByDescending(w => w.StartedAt)
                .ToListAsync(cancellationToken);

            var historyList = new List<object>();
            foreach (var wf in workflows)
            {
                string? qualitySafetyStatus = null;
                int? quarantinedRollsCount = null;
                bool? isHighImpact = null;
                string? impactReason = null;

                if (!string.IsNullOrWhiteSpace(wf.ValidationResults))
                {
                    try
                    {
                        using var doc = JsonDocument.Parse(wf.ValidationResults);
                        var root = doc.RootElement;
                        qualitySafetyStatus = GetString(root, "qualitySafetyStatus");
                        quarantinedRollsCount = GetInt32(root, "quarantinedRollsCount");
                        isHighImpact = GetBoolean(root, "isHighImpact");
                        impactReason = GetString(root, "impactReason");
                    }
                    catch
                    {
                        // ignored
                    }
                }

                historyList.Add(new
                {
                    workflowId            = wf.WorkflowId,
                    status                = wf.Status.ToString(),
                    qualitySafetyStatus   = qualitySafetyStatus,
                    quarantinedRollsCount = quarantinedRollsCount,
                    isHighImpact          = isHighImpact,
                    impactReason          = impactReason
                });
            }

            return Ok(historyList);
        }

        private static string? GetString(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        private static int? GetInt32(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out var r) ? r : (int?)null;
        private static bool? GetBoolean(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && (v.ValueKind == JsonValueKind.True || v.ValueKind == JsonValueKind.False) ? v.GetBoolean() : (bool?)null;
    }
}
