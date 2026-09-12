using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;

namespace ManufacturingCoordinator.Controllers
{
    [ApiController]
    [Route("api/suppliers")]
    [Authorize]
    public class SuppliersController : ControllerBase
    {
        private readonly ISupplierService _supplierService;

        public SuppliersController(ISupplierService supplierService)
        {
            _supplierService = supplierService;
        }

        /// <summary>GET /api/suppliers — list all suppliers</summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<SupplierResponseDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<IEnumerable<SupplierResponseDto>>> GetAll()
        {
            var suppliers = await _supplierService.GetAllAsync();
            return Ok(suppliers);
        }

        /// <summary>GET /api/suppliers/analytics — supplier overall spend & performance analytics</summary>
        [HttpGet("analytics")]
        [ProducesResponseType(typeof(SupplierAnalyticsDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<SupplierAnalyticsDto>> GetAnalytics()
        {
            var analytics = await _supplierService.GetAnalyticsAsync();
            return Ok(analytics);
        }

        /// <summary>GET /api/suppliers/{id} — get single supplier by ID</summary>
        [HttpGet("{id:int}")]
        [ProducesResponseType(typeof(SupplierResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<SupplierResponseDto>> GetById(int id)
        {
            var supplier = await _supplierService.GetByIdAsync(id);
            if (supplier is null) return NotFound(new { message = $"Supplier {id} not found." });
            return Ok(supplier);
        }

        /// <summary>GET /api/suppliers/{id}/performance — get single supplier performance metrics</summary>
        [HttpGet("{id:int}/performance")]
        [ProducesResponseType(typeof(SupplierPerformanceDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<SupplierPerformanceDto>> GetPerformance(int id)
        {
            var performance = await _supplierService.GetPerformanceAsync(id);
            if (performance is null) return NotFound(new { message = $"Supplier {id} not found." });
            return Ok(performance);
        }

        /// <summary>POST /api/suppliers — create supplier (SupplyChainManager only)</summary>
        [HttpPost]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(SupplierResponseDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<SupplierResponseDto>> Create([FromBody] CreateSupplierDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var supplier = await _supplierService.CreateAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = supplier.Id }, supplier);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>PUT /api/suppliers/{id} — update supplier (SupplyChainManager only)</summary>
        [HttpPut("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(typeof(SupplierResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<SupplierResponseDto>> Update(int id, [FromBody] UpdateSupplierDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var supplier = await _supplierService.UpdateAsync(id, dto);
                if (supplier is null) return NotFound(new { message = $"Supplier {id} not found." });
                return Ok(supplier);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>DELETE /api/suppliers/{id} — soft-delete supplier (SupplyChainManager only)</summary>
        [HttpDelete("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _supplierService.DeleteAsync(id);
            if (!deleted) return NotFound(new { message = $"Supplier {id} not found." });
            return NoContent();
        }
    }
}
