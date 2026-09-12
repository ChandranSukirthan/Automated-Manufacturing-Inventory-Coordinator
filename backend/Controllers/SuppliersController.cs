using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
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
        public async Task<ActionResult<IEnumerable<SupplierResponseDto>>> GetAll()
        {
            var suppliers = await _supplierService.GetAllAsync();
            return Ok(suppliers);
        }

        /// <summary>GET /api/suppliers/{id} — get single supplier</summary>
        [HttpGet("{id:int}")]
        public async Task<ActionResult<SupplierResponseDto>> GetById(int id)
        {
            var supplier = await _supplierService.GetByIdAsync(id);
            if (supplier is null) return NotFound(new { message = $"Supplier {id} not found." });
            return Ok(supplier);
        }

        /// <summary>POST /api/suppliers — create supplier (SupplyChainManager only)</summary>
        [HttpPost]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<SupplierResponseDto>> Create([FromBody] CreateSupplierDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            var supplier = await _supplierService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = supplier.Id }, supplier);
        }

        /// <summary>PUT /api/suppliers/{id} — update supplier (SupplyChainManager only)</summary>
        [HttpPut("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<ActionResult<SupplierResponseDto>> Update(int id, [FromBody] UpdateSupplierDto dto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            var supplier = await _supplierService.UpdateAsync(id, dto);
            if (supplier is null) return NotFound(new { message = $"Supplier {id} not found." });
            return Ok(supplier);
        }

        /// <summary>DELETE /api/suppliers/{id} — soft-delete supplier (SupplyChainManager only)</summary>
        [HttpDelete("{id:int}")]
        [Authorize(Roles = "SupplyChainManager")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _supplierService.DeleteAsync(id);
            if (!deleted) return NotFound(new { message = $"Supplier {id} not found." });
            return NoContent();
        }
    }
}

