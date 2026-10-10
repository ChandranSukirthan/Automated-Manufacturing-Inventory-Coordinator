using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using backend.Services;
using backend.Dtos;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "FloorWorker,SupplyChainManager,QualityInspector,ITAdmin")]
    public class AgentWorkflowController : ControllerBase
    {
        private readonly IInventoryService _inventoryService;
        private readonly IAgentIntegrationService _agentIntegrationService;
        private readonly ILogger<AgentWorkflowController> _logger;
        private readonly ManufacturingCoordinator.Data.ApplicationDbContext _appContext;

        public AgentWorkflowController(
            IInventoryService inventoryService, 
            IAgentIntegrationService agentIntegrationService,
            ILogger<AgentWorkflowController> logger,
            ManufacturingCoordinator.Data.ApplicationDbContext appContext)
        {
            _inventoryService = inventoryService;
            _agentIntegrationService = agentIntegrationService;
            _logger = logger;
            _appContext = appContext;
        }

        // GET: api/agentworkflow/workflows
        // Returns agentic pipeline execution states for monitor view scoped by caller's role & permissions
        [HttpGet("workflows")]
        public async Task<IActionResult> GetWorkflows()
        {
            var isITAdmin = User.IsInRole("ITAdmin");
            var isManager = User.IsInRole("SupplyChainManager");
            var isQA = User.IsInRole("QualityInspector");
            var isWorker = User.IsInRole("FloorWorker");

            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var employeeId = User.FindFirst("employee_id")?.Value;
            var userName = User.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value;

            IQueryable<ManufacturingCoordinator.Models.Administration.AgentWorkflow> query = 
                _appContext.AgentWorkflows.AsNoTracking();

            // 1. IT Admin can see ALL workflows as the center of command
            if (isITAdmin)
            {
                // Unrestricted access for IT Admin
            }
            // 2. Machine Maintenance is strictly for IT Admin - non-admins must never see Maintenance workflows
            else
            {
                query = query.Where(w => w.WorkflowType != "Maintenance" && !w.WorkflowId.StartsWith("WF-MAINT"));

                if (isManager)
                {
                    // Supply Chain Manager sees workflows they are responsible for / need to approve
                    // (Procurement / Replenishment workflows, POs)
                    query = query.Where(w =>
                        w.WorkflowType == "Procurement" ||
                        w.PurchaseOrderId != null ||
                        w.WorkflowId.StartsWith("WF-PO") ||
                        w.WorkflowId.StartsWith("WF-WORKER") ||
                        w.Objective.ToLower().Contains("replenish") ||
                        w.Objective.ToLower().Contains("procure") ||
                        w.Objective.ToLower().Contains("reorder"));
                }
                else if (isQA)
                {
                    // Quality Inspector can only see workflows if QA agent validated it (or quality workflows)
                    query = query.Where(w =>
                        w.ValidationResults != null ||
                        w.WorkflowType == "Quality" ||
                        w.WorkflowId.StartsWith("WF-QA") ||
                        (w.StateJson != null && w.StateJson.Contains("validation_results")));
                }
                else if (isWorker)
                {
                    // Floor Worker can only see the workflows they originally initiated (their history)
                    var workerAlertIds = new System.Collections.Generic.List<string>();
                    var workerKey = employeeId ?? userId;
                    if (!string.IsNullOrWhiteSpace(workerKey))
                    {
                        var alertIds = await _appContext.StockAlerts
                            .Where(a => a.WorkerId == workerKey || (employeeId != null && a.WorkerId == employeeId) || (userId != null && a.WorkerId == userId))
                            .Select(a => a.Id)
                            .ToListAsync();
                        workerAlertIds = alertIds.Select(id => $"WF-WORKER-ALERT-{id}").ToList();
                    }

                    query = query.Where(w =>
                        (w.StateJson != null && (
                            (userId != null && w.StateJson.Contains(userId)) ||
                            (employeeId != null && w.StateJson.Contains(employeeId)) ||
                            (userName != null && w.StateJson.Contains(userName))
                        )) ||
                        workerAlertIds.Contains(w.WorkflowId) ||
                        (employeeId != null && w.WorkflowId.Contains(employeeId)) ||
                        (userId != null && w.WorkflowId.Contains(userId)) ||
                        (userName != null && w.Objective.Contains(userName))
                    );
                }
            }

            var workflows = await query.OrderByDescending(w => w.StartedAt).ToListAsync();
            return Ok(workflows.Select(w => new { w.WorkflowId, w.WorkflowType, w.MachineId,
                w.PurchaseOrderId, w.Objective, w.CurrentAgent, Status = w.Status.ToString(),
                ApprovalStatus = w.ApprovalStatus.ToString(), w.StartedAt, w.CompletedAt, w.FinalOutcome,
                ValidationResults = string.IsNullOrWhiteSpace(w.ValidationResults) ? null : System.Text.Json.JsonSerializer.Deserialize<object>(w.ValidationResults),
                Details = string.IsNullOrWhiteSpace(w.StateJson) ? null : System.Text.Json.JsonSerializer.Deserialize<object>(w.StateJson) }));
        }

        // POST: api/agentworkflow/trigger/{id}
        // Endpoint to manually or systematically trigger the agent to evaluate a specific item
        [HttpPost("trigger/{id}")]
        public async Task<IActionResult> TriggerEvaluation(int id)
        {
            var item = await _inventoryService.GetInventoryItemByIdAsync(id);
            if (item == null)
            {
                return NotFound($"Inventory item with ID {id} not found.");
            }

            try 
            {
                var predictionResult = await _agentIntegrationService.TriggerLowStockEvaluationAsync(item);
                
                // If the agent recommends a reorder, we can immediately create an alert
                foreach (var prediction in predictionResult.Predictions)
                {
                    if (prediction.RecommendedAction == "Reorder")
                    {
                        await _inventoryService.CreateStockAlertAsync(new CreateStockAlertDto
                        {
                            Sku = prediction.Sku,
                            PackagingType = item.Category,
                            QuantityRequested = Math.Max(0, item.ReorderThreshold - item.StockLevel),
                            WorkerId = "Agent-Triggered"
                        });
                        _logger.LogInformation("Agent successfully triggered an alert for SKU {Sku}", prediction.Sku);
                    }
                }

                return Ok(predictionResult);
            }
            catch (System.Exception ex)
            {
                _logger.LogError(ex, "Error communicating with AI Agent Server");
                return StatusCode(500, "Error communicating with AI Agent Server");
            }
        }
        
        // POST: api/agentworkflow/callback
        // Webhook endpoint for the Python AI Agent to send asynchronous state updates
        [HttpPost("callback")]
        public IActionResult AgentStateCallback([FromBody] AgentStateUpdateDto stateUpdate)
        {
            // Simple security check (in production, use a more robust auth scheme)
            var apiKey = Request.Headers["X-API-Key"].ToString();
            // Caller is authenticated by the controller authorization policy.

            _logger.LogInformation("Received workflow state update from Agent. WorkflowId: {WorkflowId}, State: {State}, Message: {Message}", 
                stateUpdate.WorkflowId, stateUpdate.State, stateUpdate.Message);
            
            // Handle the incoming workflow state here
            // e.g., update database records regarding a long-running analysis
            
            return Ok(new { Status = "Success", Message = "State received successfully" });
        }
    }
}

