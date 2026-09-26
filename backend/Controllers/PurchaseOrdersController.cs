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

        /// <summary>GET /api/purchase-orders — list all purchase orders (summary view)</summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<PurchaseOrderSummaryDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<IEnumerable<PurchaseOrderSummaryDto>>> GetAll()
        {
            var orders = await _poService.GetAllAsync();
            return Ok(orders);
        }

        /// <summary>GET /api/purchase-orders/{id} — full PO details including order lines and audit history</summary>
        [HttpGet("{id:int}")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> GetById(int id)
        {
            var po = await _poService.GetByIdAsync(id);
            if (po is null) return NotFound(new { message = $"Purchase Order {id} not found." });
            return Ok(po);
        }

        /// <summary>GET /api/purchase-orders/{id}/pdf — download or preview generated PO PDF document</summary>
        [HttpGet("{id:int}/pdf")]
        [AllowAnonymous]
        [ProducesResponseType(typeof(FileContentResult), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetPdf(int id)
        {
            try
            {
                var pdfBytes = await _poService.GeneratePdfAsync(id);
                var po = await _poService.GetByIdAsync(id);
                var fileName = $"PurchaseOrder_{po?.PoNumber ?? id.ToString()}.pdf";
                return File(pdfBytes, "application/pdf", fileName);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
        }

        /// <summary>POST /api/purchase-orders — create new PO in Draft status</summary>
        [HttpPost]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Create([FromBody] CreatePurchaseOrderDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var userId = GetCurrentUserId();
                var po = await _poService.CreateAsync(dto, userId);
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

        /// <summary>PUT /api/purchase-orders/{id} — update PO (Draft status only)</summary>
        [HttpPut("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Update(int id, [FromBody] UpdatePurchaseOrderDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var po = await _poService.UpdateAsync(id, dto);
                if (po is null) return NotFound(new { message = $"Purchase Order {id} not found." });
                return Ok(po);
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

        /// <summary>DELETE /api/purchase-orders/{id} — delete purchase order (Draft status only)</summary>
        [HttpDelete("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var deleted = await _poService.DeleteAsync(id);
                if (!deleted) return NotFound(new { message = $"Purchase Order {id} not found." });
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // ── OrderLine Sub-Resource CRUD (Requirement 5) ──────────────────────────

        /// <summary>GET /api/purchase-orders/{id}/lines — list order lines for a purchase order</summary>
        [HttpGet("{id:int}/lines")]
        [ProducesResponseType(typeof(IEnumerable<OrderLineResponseDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<IEnumerable<OrderLineResponseDto>>> GetOrderLines(int id)
        {
            try
            {
                var lines = await _poService.GetOrderLinesAsync(id);
                return Ok(lines);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
        }

        /// <summary>POST /api/purchase-orders/{id}/lines — add an order line to a Draft purchase order</summary>
        [HttpPost("{id:int}/lines")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(OrderLineResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<OrderLineResponseDto>> AddOrderLine(int id, [FromBody] OrderLineDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var created = await _poService.AddOrderLineAsync(id, dto);
                return StatusCode(StatusCodes.Status201Created, created);
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

        /// <summary>PUT /api/purchase-orders/{id}/lines/{lineId} — update an order line on a Draft purchase order</summary>
        [HttpPut("{id:int}/lines/{lineId:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(OrderLineResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<OrderLineResponseDto>> UpdateOrderLine(int id, int lineId, [FromBody] OrderLineDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var updated = await _poService.UpdateOrderLineAsync(id, lineId, dto);
                return Ok(updated);
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

        /// <summary>DELETE /api/purchase-orders/{id}/lines/{lineId} — remove an order line from a Draft purchase order</summary>
        [HttpDelete("{id:int}/lines/{lineId:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> DeleteOrderLine(int id, int lineId)
        {
            try
            {
                var deleted = await _poService.DeleteOrderLineAsync(id, lineId);
                if (!deleted) return NotFound(new { message = $"OrderLine {lineId} not found." });
                return NoContent();
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

        // ── Approval Workflow ─────────────────────────────────────────────────────

        /// <summary>POST /api/purchase-orders/{id}/submit — transition from Draft to PendingApproval</summary>
        [HttpPost("{id:int}/submit")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Submit(int id)
        {
            try
            {
                var userId = GetCurrentUserId();
                var po = await _poService.SubmitForApprovalAsync(id, userId);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>
        /// POST /api/purchase-orders/{id}/approve — transition PendingApproval → Approved → Payment → Sent
        /// Only SupplyChainManager can approve. Executes payment and sends PO PDF document to supplier.
        /// </summary>
        [HttpPost("{id:int}/approve")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> Approve(int id, [FromBody] ApprovalActionDto? dto = null)
        {
            var approverId = GetCurrentUserId();
            if (approverId is null)
                return Unauthorized(new { message = "Cannot resolve approver identity from token." });

            try
            {
                var po = await _poService.ApproveAsync(id, approverId.Value, dto?.Notes);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>
        /// POST /api/purchase-orders/{id}/process-payment — execute payment settlement & PO dispatch
        /// Used to settle payment or retry for orders in Approved or Payment status.
        /// </summary>
        [HttpPost("{id:int}/process-payment")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> ProcessPayment(int id, [FromQuery] bool forceDispatch = true)
        {
            var approverId = GetCurrentUserId();
            try
            {
                var po = await _poService.ProcessPaymentAsync(id, approverId, forceDispatch);
                return Ok(po);
            }
            catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        }

        /// <summary>POST /api/purchase-orders/{id}/reject — transition PendingApproval → Rejected</summary>
        [HttpPost("{id:int}/reject")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
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
        /// POST /api/purchase-orders/{id}/revise — transition PendingApproval → RevisionRequested → Draft
        /// Returns purchase order back to Draft for requester adjustment.
        /// </summary>
        [HttpPost("{id:int}/revise")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
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

        /// <summary>Extracts the user ID Guid from the JWT NameIdentifier claim.</summary>
        private Guid? GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(claim, out var id) ? id : null;
        }

        /// <summary>
        /// POST /api/purchase-orders/{id}/request-revision — Alias for /revise.
        /// Allows the React Supply Chain Manager UI to use RESTful naming.
        /// </summary>
        [HttpPost("{id:int}/request-revision")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(PurchaseOrderResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderResponseDto>> RequestRevision(int id, [FromBody] ApprovalActionDto dto)
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

        /// <summary>
        /// GET /api/purchase-orders/{id}/delivery-status — Tracking incoming supply delivery for Floor Workers.
        /// </summary>
        [HttpGet("{id:int}/delivery-status")]
        [ProducesResponseType(typeof(PurchaseOrderDeliveryStatusDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PurchaseOrderDeliveryStatusDto>> GetDeliveryStatus(int id)
        {
            var po = await _poService.GetByIdAsync(id);
            if (po == null) return NotFound(new { message = $"Purchase order {id} not found." });

            var primaryLine = po.OrderLines.Count > 0 ? po.OrderLines[0] : null;
            var deliveryStatus = po.Status switch
            {
                "Sent" => "IN_TRANSIT",
                "Payment" => "EXPECTED",
                "Approved" => "EXPECTED",
                "Received" => "RECEIVED",
                "Completed" => "COMPLETED",
                _ => "EXPECTED"
            };

            var dto = new PurchaseOrderDeliveryStatusDto
            {
                PurchaseOrderId = po.Id,
                PoNumber = po.PoNumber,
                SupplierName = po.SupplierName,
                MaterialName = primaryLine?.RawMaterialName ?? "Raw Material Supplies",
                Quantity = primaryLine?.Quantity ?? 0,
                ExpectedDelivery = po.CreatedAt.AddDays(7),
                DeliveryStatus = deliveryStatus,
                TrackingNumber = $"TRK-{po.PoNumber}",
                StatusRemarks = $"Delivery status for PO {po.PoNumber} from {po.SupplierName}"
            };
            return Ok(dto);
        }

        /// <summary>
        /// GET /api/purchase-orders/incoming-supplies — List active incoming supplies for Floor Workers.
        /// </summary>
        [HttpGet("incoming-supplies")]
        [ProducesResponseType(typeof(IEnumerable<PurchaseOrderDeliveryStatusDto>), StatusCodes.Status200OK)]
        public async Task<ActionResult<IEnumerable<PurchaseOrderDeliveryStatusDto>>> GetIncomingSupplies()
        {
            var orders = await _poService.GetAllAsync();
            var list = new List<PurchaseOrderDeliveryStatusDto>();
            foreach (var po in orders)
            {
                var deliveryStatus = po.Status switch
                {
                    "Sent" => "IN_TRANSIT",
                    "Payment" => "EXPECTED",
                    "Approved" => "EXPECTED",
                    "Received" => "RECEIVED",
                    "Completed" => "COMPLETED",
                    _ => null
                };

                if (deliveryStatus != null)
                {
                    list.Add(new PurchaseOrderDeliveryStatusDto
                    {
                        PurchaseOrderId = po.Id,
                        PoNumber = po.PoNumber,
                        SupplierName = po.SupplierName,
                        MaterialName = "Raw Material Supplies",
                        Quantity = 1000,
                        ExpectedDelivery = po.CreatedAt.AddDays(7),
                        DeliveryStatus = deliveryStatus,
                        TrackingNumber = $"TRK-{po.PoNumber}",
                        StatusRemarks = $"Supplier: {po.SupplierName} | Status: {deliveryStatus}"
                    });
                }
            }
            return Ok(list);
        }

        /// <summary>
        /// PUT /api/purchase-orders/{id}/delivery-status — Update delivery tracking status from mobile (Floor Worker / Logistics).
        /// </summary>
        [HttpPut("{id:int}/delivery-status")]
        [ProducesResponseType(typeof(PurchaseOrderDeliveryStatusDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<PurchaseOrderDeliveryStatusDto>> UpdateDeliveryStatus(int id, [FromBody] UpdateDeliveryStatusDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var updated = await _poService.UpdateDeliveryStatusAsync(id, dto.DeliveryStatus, dto.Remarks);
            if (updated == null) return NotFound(new { message = $"Purchase order {id} not found." });

            var primaryLine = updated.OrderLines.Count > 0 ? updated.OrderLines[0] : null;
            var normalizedStatus = dto.DeliveryStatus.Trim().ToUpperInvariant();

            return Ok(new PurchaseOrderDeliveryStatusDto
            {
                PurchaseOrderId = id,
                PoNumber = updated.PoNumber,
                SupplierName = updated.SupplierName,
                MaterialName = primaryLine?.RawMaterialName ?? "Raw Material Supplies",
                Quantity = primaryLine?.Quantity ?? 1000,
                ExpectedDelivery = updated.CreatedAt.AddDays(7),
                DeliveryStatus = normalizedStatus,
                TrackingNumber = $"TRK-{updated.PoNumber}",
                StatusRemarks = dto.Remarks ?? $"Status updated to {normalizedStatus}."
            });
        }
    }
}
