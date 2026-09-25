using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;

namespace ManufacturingCoordinator.Controllers
{
    [ApiController]
    [Route("api/procurement")]
    [Authorize]
    public class ProcurementController : ControllerBase
    {
        private readonly IProcurementService _procurementService;

        public ProcurementController(IProcurementService procurementService)
        {
            _procurementService = procurementService;
        }

        /// <summary>
        /// POST /api/procurement/request — Initialize AI-assisted raw-material procurement request.
        /// Deterministically calculates net required quantity.
        /// </summary>
        [HttpPost("request")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(ProcurementResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<ProcurementResponseDto>> CreateRequest([FromBody] CreateProcurementRequestDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var userId = GetCurrentUserId();
                var result = await _procurementService.CreateRequestAsync(dto, userId);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// POST /api/procurement/{id}/research — Trigger AI agent market research & candidate validation.
        /// Validates candidates, computes deterministic MOQ/cost, and auto-drafts PO for approved suppliers.
        /// </summary>
        [HttpPost("{id:int}/research")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(ProcurementResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<ProcurementResponseDto>> RunResearch(int id)
        {
            try
            {
                var result = await _procurementService.RunAiResearchAsync(id);
                return Ok(result);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// GET /api/procurement/{id} — Retrieve procurement request with evaluated supplier candidates.
        /// </summary>
        [HttpGet("{id:int}")]
        [ProducesResponseType(typeof(ProcurementResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ProcurementResponseDto>> GetById(int id)
        {
            var result = await _procurementService.GetByIdAsync(id);
            if (result == null) return NotFound(new { message = $"Procurement request {id} not found." });
            return Ok(result);
        }

        /// <summary>
        /// GET /api/procurement — List all procurement requests.
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<ProcurementResponseDto>), StatusCodes.Status200OK)]
        public async Task<ActionResult<IEnumerable<ProcurementResponseDto>>> GetAll()
        {
            var list = await _procurementService.GetAllAsync();
            return Ok(list);
        }

        /// <summary>
        /// POST /api/procurement/{id}/create-draft-po — Create Draft PO from a specific validated candidate.
        /// </summary>
        [HttpPost("{id:int}/create-draft-po")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> CreateDraftPo(int id, [FromQuery] int candidateId)
        {
            try
            {
                var userId = GetCurrentUserId();
                var po = await _procurementService.CreateDraftPoFromCandidateAsync(id, candidateId, userId);
                return CreatedAtAction(
                    actionName: "GetById",
                    controllerName: "PurchaseOrders",
                    routeValues: new { id = po.Id },
                    value: po);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// POST /api/procurement/{id}/verify-supplier — Onboard and approve an unverified candidate.
        /// </summary>
        [HttpPost("{id:int}/verify-supplier")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(ProcurementResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ProcurementResponseDto>> VerifySupplier(
            int id, 
            [FromQuery] int candidateId, 
            [FromBody] VerifySupplierCandidateDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var userId = GetCurrentUserId();
                var result = await _procurementService.VerifyAndOnboardSupplierAsync(id, candidateId, dto, userId);
                return Ok(result);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        private Guid? GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return Guid.TryParse(claim, out var id) ? id : null;
        }

        /// <summary>
        /// GET /api/procurement/{id}/candidates — Return all evaluated supplier candidates for a procurement request.
        /// </summary>
        [HttpGet("{id:int}/candidates")]
        [ProducesResponseType(typeof(IEnumerable<SupplierCandidateDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<IEnumerable<SupplierCandidateDto>>> GetCandidates(int id)
        {
            try
            {
                var candidates = await _procurementService.GetCandidatesAsync(id);
                return Ok(candidates);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
        }

        /// <summary>
        /// GET /api/procurement/{id}/recommendation — Return AI recommendation summary and rationale.
        /// Used by React Supply Chain Manager dashboard and Flutter status screen.
        /// </summary>
        [HttpGet("{id:int}/recommendation")]
        [ProducesResponseType(typeof(ProcurementRecommendationDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ProcurementRecommendationDto>> GetRecommendation(int id)
        {
            try
            {
                var recommendation = await _procurementService.GetRecommendationAsync(id);
                return Ok(recommendation);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
        }

        /// <summary>
        /// GET /api/procurement/{id}/status — End-to-end status tracking for Flutter monitoring screen.
        /// Returns procurement + PO + Stripe payment + SendGrid notification status in one payload.
        /// </summary>
        [HttpGet("{id:int}/status")]
        [ProducesResponseType(typeof(ProcurementStatusTrackingDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ProcurementStatusTrackingDto>> GetStatusTracking(int id)
        {
            var tracking = await _procurementService.GetStatusTrackingAsync(id);
            if (tracking == null) return NotFound(new { message = $"Procurement request {id} not found." });
            return Ok(tracking);
        }

        /// <summary>
        /// POST /api/procurement/{id}/start — Alias for /research. Starts AI research workflow.
        /// </summary>
        [HttpPost("{id:int}/start")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(ProcurementResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ProcurementResponseDto>> StartResearch(int id)
        {
            try
            {
                var result = await _procurementService.RunAiResearchAsync(id);
                return Ok(result);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// POST /api/procurement/{id}/generate-draft-po — Alias for /create-draft-po.
        /// Creates Draft PO from a validated APPROVED supplier candidate.
        /// </summary>
        [HttpPost("{id:int}/generate-draft-po")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> GenerateDraftPo(int id, [FromQuery] int candidateId)
        {
            try
            {
                var userId = GetCurrentUserId();
                var po = await _procurementService.CreateDraftPoFromCandidateAsync(id, candidateId, userId);
                return CreatedAtAction(
                    actionName: "GetById",
                    controllerName: "PurchaseOrders",
                    routeValues: new { id = po.Id },
                    value: po);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
