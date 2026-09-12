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
        // Returns agentic pipeline execution states for monitor view
        [HttpGet("workflows")]
        public async Task<IActionResult> GetWorkflows()
        {
            var pos = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
                _appContext.PurchaseOrders
                    .Include(p => p.Supplier)
                    .OrderByDescending(p => p.CreatedAt)
            );

            var workflows = pos.Select((po, idx) =>
            {
                var isPending = po.Status == ManufacturingCoordinator.Enums.PurchaseOrderStatus.PendingApproval;
                var isApproved = po.Status == ManufacturingCoordinator.Enums.PurchaseOrderStatus.Approved ||
                                 po.Status == ManufacturingCoordinator.Enums.PurchaseOrderStatus.Payment ||
                                 po.Status == ManufacturingCoordinator.Enums.PurchaseOrderStatus.Sent;
                var isRejected = po.Status == ManufacturingCoordinator.Enums.PurchaseOrderStatus.Rejected;

                var stepIdx = isApproved ? 5 : isPending ? 4 : isRejected ? 4 : 3;
                var statusText = isApproved ? "Completed" : isPending ? "WaitingForApproval" : isRejected ? "Rejected" : "Active";

                return new
                {
                    workflowId = $"WF-2026-{(100 + po.Id):D3}",
                    objective = $"Replenish raw material for {po.Supplier?.Name ?? "Supplier"} under budget {po.BudgetLimit:C}",
                    currentAgent = isApproved ? "Dispatch Agent" : isPending ? "Human Approval Gate" : "Validation Agent",
                    currentStep = isApproved ? "Order Dispatched" : isPending ? "Waiting For Manager Approval" : "Validating SLA & Budget",
                    status = statusText,
                    startedAt = po.CreatedAt,
                    completedAt = isApproved ? po.UpdatedAt : (System.DateTime?)null,
                    approvalStatus = po.Status.ToString(),
                    finalOutcome = isApproved ? $"PO {po.PoNumber} approved & dispatched (${po.TotalCost:F2})" : isRejected ? $"PO {po.PoNumber} rejected ({po.RejectionReason})" : $"PO {po.PoNumber} in evaluation (${po.TotalCost:F2})",
                    steps = new[] { "PLANNER", "DATA EXTRACTION", "PURCHASING", "VALIDATION", "WAITING FOR APPROVAL" },
                    currentStepIndex = stepIdx,
                    purchaseOrderId = po.Id,
                    poNumber = po.PoNumber,
                    supplierName = po.Supplier?.Name ?? "—",
                    totalCost = po.TotalCost
                };
            }).ToList();

            return Ok(workflows);
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
                            QuantityRequested = 500, // This could be determined dynamically or by the agent
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
            // TODO: Validate apiKey against configuration...

            _logger.LogInformation("Received workflow state update from Agent. WorkflowId: {WorkflowId}, State: {State}, Message: {Message}", 
                stateUpdate.WorkflowId, stateUpdate.State, stateUpdate.Message);
            
            // Handle the incoming workflow state here
            // e.g., update database records regarding a long-running analysis
            
            return Ok(new { Status = "Success", Message = "State received successfully" });
        }
    }
}

