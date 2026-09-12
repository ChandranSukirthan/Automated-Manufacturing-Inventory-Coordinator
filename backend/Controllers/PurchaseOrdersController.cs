using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;

namespace ManufacturingCoordinator.Controllers
{
    [ApiController]
    [Route("api/purchase-orders")]
    [Authorize]
    public class PurchaseOrdersController : ControllerBase
    {
        private readonly IPurchaseOrderService _poService;

        public PurchaseOrdersController(IPurchaseOrderService poService)
        {
            _poService = poService;
        }

        // ── CRUD ──────────────────────────────────────────────────────────────────

        /// <summary>GET /api/purchase-orders — list all POs (summary)</summary>
        [HttpGet]
        public async Task<ActionResult<IEnumerable<PurchaseOrderSummaryDto>>> GetAll()
        {
            var orders = await _poService.GetAllAsync();
            return Ok(orders);
        }

        /// <summary>GET /api/purchase-orders/{id} — full PO with order lines</summary>
        [HttpGet("{id:int}")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> GetById(int id)
        {
            var po = await _poService.GetByIdAsync(id);
            if (po is null) return NotFound(new { message = $"Purchase Order {id} not found." });
            return Ok(po);
        }

        /// <summary>POST /api/purchase-orders — create new PO in Draft</summary>
        [HttpPost]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Create([FromBody] CreatePurchaseOrderDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var po = await _poService.CreateAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = po.Id }, po);
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

        /// <summary>PUT /api/purchase-orders/{id} — update PO (Draft only)</summary>
        [HttpPut("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Update(int id, [FromBody] UpdatePurchaseOrderDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var po = await _poService.UpdateAsync(id, dto);
                if (po is null) return NotFound(new { message = $"Purchase Order {id} not found." });
                return Ok(po);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // ── Approval Workflow ─────────────────────────────────────────────────────

        /// <summary>POST /api/purchase-orders/{id}/submit — Draft → PendingApproval</summary>
        [HttpPost("{id:int}/submit")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Submit(int id)
        {
            try
            {
                var po = await _poService.SubmitForApprovalAsync(id);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>
        /// POST /api/purchase-orders/{id}/approve — PendingApproval → Approved → Payment → Sent
        /// Only SupplyChainManager can approve. JWT enforced server-side.
        /// </summary>
        [HttpPost("{id:int}/approve")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Approve(int id)
        {
            var approverId = GetCurrentUserId();
            if (approverId is null)
                return Unauthorized(new { message = "Cannot resolve approver identity from token." });

            try
            {
                var po = await _poService.ApproveAsync(id, approverId.Value);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>POST /api/purchase-orders/{id}/reject — PendingApproval → Rejected</summary>
        [HttpPost("{id:int}/reject")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Reject(int id, [FromBody] ApprovalActionDto dto)
        {
            var approverId = GetCurrentUserId();
            if (approverId is null)
                return Unauthorized(new { message = "Cannot resolve approver identity from token." });

            try
            {
                var po = await _poService.RejectAsync(id, approverId.Value, dto.Notes);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>
        /// POST /api/purchase-orders/{id}/revise — PendingApproval → RevisionRequested → Draft
        /// Manager requests changes; PO returns to Draft for editing.
        /// </summary>
        [HttpPost("{id:int}/revise")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Revise(int id, [FromBody] ApprovalActionDto dto)
        {
            var approverId = GetCurrentUserId();
            if (approverId is null)
                return Unauthorized(new { message = "Cannot resolve approver identity from token." });

            try
            {
                var po = await _poService.RequestRevisionAsync(id, approverId.Value, dto.Notes);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        // ── Helpers ───────────────────────────────────────────────────────────────

        /// <summary>Extracts the numeric user ID from the JWT NameIdentifier claim.</summary>
        private int? GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return int.TryParse(claim, out var id) ? id : null;
        }
    }
}

