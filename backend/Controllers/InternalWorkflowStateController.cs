using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

// FastAPI publishes execution summaries through this bounded backend contract.
// It cannot create orders, quarantine inventory, pay, or send notifications here.
[ApiController]
[Route("api/internal/workflows")]
[Authorize(Roles = "FloorWorker,SupplyChainManager,QualityInspector,ITAdmin")]
public sealed class InternalWorkflowStateController(ApplicationDbContext db, IConfiguration configuration) : ControllerBase
{
    public sealed class Publication
    {
        [Required] public JsonElement State { get; set; }
    }

    [HttpPut("{workflowId}/state")]
    [RequestSizeLimit(262144)]
    public async Task<IActionResult> Publish(string workflowId, Publication publication, CancellationToken cancellationToken)
    {
        if (!Regex.IsMatch(workflowId, @"^[A-Za-z0-9_-]{1,100}$")) return BadRequest("Invalid workflow identifier.");
        var secret = configuration["JwtSettings:SecretKey"];
        var timestamp = Request.Headers["X-AI-Timestamp"].ToString();
        if (string.IsNullOrEmpty(secret) || !long.TryParse(timestamp, out var sentAt) ||
            Math.Abs(DateTimeOffset.UtcNow.ToUnixTimeSeconds() - sentAt) > 60) return Unauthorized();
        if (publication.State.ValueKind != JsonValueKind.Object) return BadRequest("State must be an object.");
        var expected = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(timestamp + "\n" + publication.State.GetRawText()));
        byte[] supplied;
        try { supplied = Convert.FromHexString(Request.Headers["X-AI-Signature"].ToString()); }
        catch (FormatException) { return Unauthorized(); }
        if (!CryptographicOperations.FixedTimeEquals(expected, supplied)) return Unauthorized();
        var state = JsonNode.Parse(publication.State.GetRawText())!.AsObject();
        if (state["workflow_id"]?.GetValue<string>() != workflowId) return BadRequest("Workflow identifier mismatch.");
        if (state.ToJsonString().Length > 250000 || ContainsPrivateFields(state)) return BadRequest("Invalid execution summary.");
        if (!Enum.TryParse<WorkflowStatus>(state["status"]?.GetValue<string>(), out var status) || !Enum.IsDefined(status))
            return BadRequest("Invalid workflow status.");
        var type = state["workflow_type"]?.GetValue<string>() ?? "Procurement";
        if (type is not ("Procurement" or "Maintenance")) return BadRequest("Invalid workflow type.");
        if (type == "Maintenance" && !User.IsInRole("ITAdmin")) return Forbid();
        var objective = state["objective"]?.GetValue<string>() ?? "";
        if (objective.Length is < 1 or > 4000) return BadRequest("Invalid objective.");
        var workflow = await db.AgentWorkflows.SingleOrDefaultAsync(w => w.WorkflowId == workflowId, cancellationToken);
        if (workflow == null && User.IsInRole("QualityInspector")) return Forbid();
        if (workflow != null && (workflow.Objective != objective || workflow.WorkflowType != type))
            return Conflict("Workflow identifier belongs to a different request.");
        workflow ??= new AgentWorkflow { WorkflowId = workflowId, Objective = objective, WorkflowType = type };
        if (db.Entry(workflow).State == EntityState.Detached) db.AgentWorkflows.Add(workflow);
        // Human financial authorization remains owned by the backend order APIs.
        // AI publication must never turn a workflow into an approved order.
        if (state["approval_status"]?.GetValue<string>() == "Approved" && !User.IsInRole("SupplyChainManager")) return Forbid();
        if (state["machine_id"]?.GetValue<string>() is { } machine)
        {
            if (!Guid.TryParse(machine, out var machineId)) return BadRequest("Invalid machine identifier.");
            workflow.MachineId = machineId;
        }
        state["synchronization_pending"] = false;
        state.Remove("synchronization_error");
        workflow.Status = status;
        workflow.CurrentAgent = state["current_agent"]?.GetValue<string>() ?? "Planner";
        workflow.FinalOutcome = state["final_outcome"]?.GetValue<string>();
        workflow.CompletedAt = status is WorkflowStatus.Completed or WorkflowStatus.Failed ? DateTime.UtcNow : null;
        if (state["validation_results"] is JsonObject validation)
        {
            var previous = string.IsNullOrWhiteSpace(workflow.ValidationResults) ? null : JsonNode.Parse(workflow.ValidationResults) as JsonObject;
            // QA decisions are written only by the QA controller, never supplied
            // by an AI request or copied from a stale local session.
            var sameDefect = previous?["defectFingerprint"]?.ToJsonString() == validation["defectFingerprint"]?.ToJsonString();
            foreach (var field in new[] { "manualResolutionStatus", "manualResolutionNote", "resolvedBy", "resolvedAt" })
            {
                validation.Remove(field);
                if (sameDefect && previous?[field] is { } decision) validation[field] = decision.DeepClone();
            }
            validation["manualResolutionStatus"] ??= validation["qualitySafetyStatus"]?.GetValue<string>() is "CLEAR" or "PASSED" ? "NOT_REQUIRED" : "PENDING_REVIEW";
            workflow.ValidationResults = validation.ToJsonString();
        }
        workflow.StateJson = state.ToJsonString();
        await db.SaveChangesAsync(cancellationToken);
        return Ok(new { workflowId, synchronized = true });
    }

    private static bool ContainsPrivateFields(JsonNode? node) => node switch
    {
        JsonObject obj => obj.Any(pair => pair.Key is "messages" or "prompt" or "chain_of_thought" or "authorization" or "accessToken" or "refreshToken" or "password" or "api_key" || ContainsPrivateFields(pair.Value)),
        JsonArray array => array.Any(ContainsPrivateFields),
        _ => false
    };
}
