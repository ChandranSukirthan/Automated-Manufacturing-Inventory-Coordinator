using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using backend.Dtos;
using backend.Services;

namespace ManufacturingCoordinator.Controllers
{
    [ApiController]
    [Route("api/stock-alerts")]
    [Authorize]
    public class StockAlertsController : ControllerBase
    {
        private readonly IInventoryService _inventoryService;

        public StockAlertsController(IInventoryService inventoryService)
        {
            _inventoryService = inventoryService;
        }

        /// <summary>
        /// GET /api/stock-alerts — List all stock alerts with deterministic net deficit.
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<StockAlertResponseDto>), StatusCodes.Status200OK)]
        public async Task<ActionResult<IEnumerable<StockAlertResponseDto>>> GetAllAlerts()
        {
            var alerts = await _inventoryService.GetStockAlertsAsync();
            return Ok(alerts);
        }

        /// <summary>
        /// GET /api/stock-alerts/{id} — Get specific stock alert by ID.
        /// </summary>
        [HttpGet("{id:int}")]
        [ProducesResponseType(typeof(StockAlertResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<StockAlertResponseDto>> GetAlertById(int id)
        {
            var alert = await _inventoryService.GetStockAlertByIdAsync(id);
            if (alert == null)
                return NotFound(new { message = $"Stock alert {id} not found." });

            return Ok(alert);
        }

        /// <summary>
        /// GET /api/stock-alerts/unread — List unread stock alerts for Supply Chain Manager notification banner.
        /// </summary>
        [HttpGet("unread")]
        [ProducesResponseType(typeof(IEnumerable<StockAlertResponseDto>), StatusCodes.Status200OK)]
        public async Task<ActionResult<IEnumerable<StockAlertResponseDto>>> GetUnreadAlerts()
        {
            var alerts = await _inventoryService.GetUnreadStockAlertsAsync();
            return Ok(alerts);
        }

        /// <summary>
        /// PUT /api/stock-alerts/{id}/read — Mark stock alert as read / acknowledged by manager.
        /// </summary>
        [HttpPut("{id:int}/read")]
        [Authorize(Roles = "SupplyChainManager,ITAdmin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var success = await _inventoryService.MarkStockAlertAsReadAsync(id);
            if (!success)
                return NotFound(new { message = $"Stock alert {id} not found." });

            return Ok(new { message = $"Stock alert {id} marked as read.", alertId = id, isRead = true });
        }

        /// <summary>
        /// POST /api/stock-alerts — Submit new stock alert (Floor Worker or IoT sensor).
        /// Deterministically computes NetDeficit: (RequiredQuantity + SafetyStock) - (CurrentStock + OpenPurchaseQuantity).
        /// </summary>
        [HttpPost]
        [ProducesResponseType(typeof(StockAlertResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<StockAlertResponseDto>> CreateAlert([FromBody] CreateStockAlertDto alertDto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var createdAlert = await _inventoryService.CreateStockAlertAsync(alertDto);
            return StatusCode(StatusCodes.Status201Created, createdAlert);
        }
    }
}
