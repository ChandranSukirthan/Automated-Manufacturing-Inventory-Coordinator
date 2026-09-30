using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.Dtos;
using backend.Services;
using backend.Models;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    // Stock-level routes are defined in this controller as well as inventory
    // routes. Keep the worker role read/write access explicit at the boundary.
    [Authorize(Roles = "FloorWorker,SupplyChainManager,ITAdmin")]
    public class InventoryController : ControllerBase
    {
        private readonly IInventoryService _inventoryService;
        private readonly IBarcodeService _barcodeService;

        public InventoryController(
            IInventoryService inventoryService,
            IBarcodeService barcodeService)
        {
            _inventoryService = inventoryService;
            _barcodeService = barcodeService;
        }

        // =========================================================================
        // Generic / Legacy Inventory Items
        // =========================================================================

        // GET: api/inventory
        [HttpGet]
        public async Task<ActionResult<IEnumerable<InventoryItemDto>>> GetInventory()
        {
            var items = await _inventoryService.GetInventoryItemsAsync();
            return Ok(items);
        }

        // GET: api/inventory/{id}
        [HttpGet("{id:int}")]
        public async Task<ActionResult<InventoryItem>> GetItem(int id)
        {
            var item = await _inventoryService.GetInventoryItemByIdAsync(id);
            if (item == null) return NotFound($"Item with ID {id} not found.");
            return Ok(item);
        }

        // POST: api/inventory
        [HttpPost]
        public async Task<ActionResult<InventoryItem>> CreateItem([FromBody] CreateInventoryItemRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            try
            {
                var created = await _inventoryService.CreateInventoryItemFromSkuAsync(request);
                return CreatedAtAction(nameof(GetItem), new { id = created.Id }, created);
            }
            catch (System.Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/inventory/{id}
        [HttpPut("{id:int}")]
        public async Task<IActionResult> PutItem(int id, [FromBody] InventoryItem item)
        {
            if (id != item.Id) return BadRequest("ID mismatch.");
            var success = await _inventoryService.UpdateInventoryItemAsync(id, item);
            if (!success) return NotFound();
            return NoContent();
        }

        // DELETE: api/inventory/{id}
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> DeleteItem(int id)
        {
            var success = await _inventoryService.DeleteInventoryItemAsync(id);
            if (!success) return NotFound();
            return NoContent();
        }

        // =========================================================================
        // Student 1: Raw Material CRUD
        // =========================================================================

        // GET: api/inventory/rawmaterials
        [HttpGet("rawmaterials")]
        public async Task<ActionResult<IEnumerable<RawMaterial>>> GetRawMaterials()
        {
            var materials = await _inventoryService.GetRawMaterialsAsync();
            return Ok(materials);
        }

        // GET: api/inventory/packaging-types
        [HttpGet("packaging-types")]
        public async Task<ActionResult<IEnumerable<PackagingType>>> GetPackagingTypes()
        {
            var packagingTypes = await _inventoryService.GetPackagingTypesAsync();
            return Ok(packagingTypes);
        }

        // GET: api/inventory/rawmaterials/{id}
        [HttpGet("rawmaterials/{id:int}")]
        public async Task<ActionResult<RawMaterial>> GetRawMaterialById(int id)
        {
            var material = await _inventoryService.GetRawMaterialByIdAsync(id);
            if (material == null) return NotFound($"Raw Material {id} not found.");
            return Ok(material);
        }

        // POST: api/inventory/rawmaterials
        [HttpPost("rawmaterials")]
        public async Task<ActionResult<RawMaterial>> CreateRawMaterial([FromBody] RawMaterial material)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            try
            {
                var created = await _inventoryService.CreateRawMaterialAsync(material);
                return CreatedAtAction(nameof(GetRawMaterialById), new { id = created.Id }, created);
            }
            catch (System.Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/inventory/rawmaterials/{id}
        [HttpPut("rawmaterials/{id:int}")]
        public async Task<IActionResult> UpdateRawMaterial(int id, [FromBody] RawMaterial material)
        {
            if (id != material.Id) return BadRequest("ID mismatch.");
            var updated = await _inventoryService.UpdateRawMaterialAsync(id, material);
            if (!updated) return NotFound();
            return NoContent();
        }

        // DELETE: api/inventory/rawmaterials/{id}
        [HttpDelete("rawmaterials/{id:int}")]
        public async Task<IActionResult> DeleteRawMaterial(int id)
        {
            var deleted = await _inventoryService.DeleteRawMaterialAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }

        // =========================================================================
        // Student 1: Inventory Roll CRUD & QR Lookup
        // =========================================================================

        // GET: api/inventory/rolls
        [HttpGet("rolls")]
        public async Task<ActionResult<IEnumerable<InventoryRoll>>> GetRolls()
        {
            var rolls = await _inventoryService.GetInventoryRollsAsync();
            return Ok(rolls);
        }

        // GET: api/inventory/rolls/{id}
        [HttpGet("rolls/{id:int}")]
        public async Task<ActionResult<InventoryRoll>> GetRollById(int id)
        {
            var roll = await _inventoryService.GetInventoryRollByIdAsync(id);
            if (roll == null) return NotFound($"Roll {id} not found.");
            return Ok(roll);
        }

        // GET: api/inventory/rolls/{rollIdentifier}/qr
        // The Flutter client loads this authenticated local endpoint; the API
        // keeps the QR provider URL and response validation server-side.
        [HttpGet("rolls/{rollIdentifier}/qr")]
        [Produces("image/png")]
        public async Task<IActionResult> GetInventoryRollQrCode(
            string rollIdentifier,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(rollIdentifier) ||
                rollIdentifier.Length is < 2 or > 64 ||
                !rollIdentifier.All(character =>
                    char.IsLetterOrDigit(character) || character is '-' or '_'))
            {
                return BadRequest("Invalid inventory-roll identifier.");
            }

            var roll = await _inventoryService.GetInventoryRollByIdentifierAsync(rollIdentifier);
            if (roll is null) return NotFound();

            try
            {
                var image = await _barcodeService.GenerateInventoryRollQrAsync(
                    roll.RollIdentifier,
                    cancellationToken);
                return File(image.Bytes, image.ContentType);
            }
            catch (QrCodeProviderException)
            {
                return Problem(
                    statusCode: StatusCodes.Status502BadGateway,
                    title: "QR code provider is unavailable.");
            }
            catch (ArgumentException)
            {
                return BadRequest("Invalid inventory-roll identifier.");
            }
        }

        // POST: api/inventory/rolls
        [HttpPost("rolls")]
        public async Task<ActionResult<InventoryRoll>> CreateRoll([FromBody] InventoryRoll roll)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            try
            {
                var created = await _inventoryService.CreateInventoryRollAsync(roll);
                return CreatedAtAction(nameof(GetRollById), new { id = created.Id }, created);
            }
            catch (System.Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/inventory/rolls/{id}
        [HttpPut("rolls/{id:int}")]
        public async Task<IActionResult> UpdateRoll(int id, [FromBody] InventoryRoll roll)
        {
            if (id != roll.Id) return BadRequest("ID mismatch.");
            var updated = await _inventoryService.UpdateInventoryRollAsync(id, roll);
            if (!updated) return NotFound();
            return NoContent();
        }

        // DELETE: api/inventory/rolls/{id}
        [HttpDelete("rolls/{id:int}")]
        public async Task<IActionResult> DeleteRoll(int id)
        {
            var deleted = await _inventoryService.DeleteInventoryRollAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }

        // GET: api/inventory/roll/qr/{qrCode}
        [HttpGet("roll/qr/{qrCode}")]
        public async Task<ActionResult<QrLookupResultDto>> GetRollByQr(string qrCode)
        {
            var result = await _inventoryService.GetInventoryRollByQrAsync(qrCode);
            if (result == null) return NotFound($"No inventory roll matched QR/barcode '{qrCode}'.");
            return Ok(result);
        }

        // =========================================================================
        // Student 1: Stock Levels & Calculations
        // =========================================================================

        // GET: api/inventory/stock-levels
        [HttpGet("stock-levels")]
        public async Task<ActionResult<IEnumerable<StockLevelDetailDto>>> GetStockLevels()
        {
            var levels = await _inventoryService.GetStockLevelsAsync();
            return Ok(levels);
        }

        // POST: api/inventory/stock-levels
        [HttpPost("stock-levels")]
        public async Task<ActionResult<StockLevel>> CreateStockLevel([FromBody] StockLevel stockLevel)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            var created = await _inventoryService.CreateStockLevelAsync(stockLevel);
            return Ok(created);
        }

        // =========================================================================
        // Student 1: Low Stock & Alerts
        // =========================================================================

        // GET: api/inventory/low-stock
        [HttpGet("low-stock")]
        public async Task<ActionResult<IEnumerable<LowStockItemDto>>> GetLowStock()
        {
            var lowStock = await _inventoryService.GetLowStockItemsAsync();
            return Ok(lowStock);
        }

        // POST: api/inventory/low-stock-alert
        [HttpPost("low-stock-alert")]
        public async Task<ActionResult<StockAlertResponseDto>> CreateLowStockAlert([FromBody] CreateStockAlertDto alertDto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!AssignWorkerEmployeeId(alertDto))
            {
                return BadRequest("Floor worker employee ID is missing. Please sign in again.");
            }
            var created = await _inventoryService.CreateStockAlertAsync(alertDto);
            return Ok(created);
        }

        // GET: api/inventory/alerts
        [HttpGet("alerts")]
        public async Task<ActionResult<IEnumerable<StockAlertResponseDto>>> GetAlerts()
        {
            var alerts = await _inventoryService.GetStockAlertsAsync();
            return Ok(alerts);
        }

        // POST: api/inventory/alerts
        [HttpPost("alerts")]
        public async Task<ActionResult<StockAlertResponseDto>> CreateAlert([FromBody] CreateStockAlertDto alertDto)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!AssignWorkerEmployeeId(alertDto))
            {
                return BadRequest("Floor worker employee ID is missing. Please sign in again.");
            }
            var created = await _inventoryService.CreateStockAlertAsync(alertDto);
            return CreatedAtAction(nameof(GetAlerts), new { id = created.Id }, created);
        }

        // PUT: api/inventory/alerts/{id}
        [HttpPut("alerts/{id:int}")]
        public async Task<IActionResult> UpdateAlertStatus(int id, [FromBody] UpdateAlertStatusDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto?.Status)) return BadRequest("Status cannot be empty.");
            var success = await _inventoryService.UpdateAlertStatusAsync(id, dto.Status);
            if (!success) return NotFound();
            return NoContent();
        }

        // =========================================================================
        // Student 1: Inventory History
        // =========================================================================

        // GET: api/inventory/{id}/history
        [HttpGet("{id:int}/history")]
        public async Task<ActionResult<IEnumerable<InventoryHistoryItemDto>>> GetHistory(int id)
        {
            var history = await _inventoryService.GetInventoryHistoryAsync(id);
            return Ok(history);
        }

        // =========================================================================
        // Student 1: Proxy Trigger for AI Agent Workflow via ASP.NET Core
        // =========================================================================

        // POST: api/inventory/trigger-replenishment
        [HttpPost("trigger-replenishment")]
        public async Task<IActionResult> TriggerReplenishment([FromBody] TriggerReplenishmentDto dto)
        {
            if (dto == null) return BadRequest("Replenishment request is empty.");
            try
            {
                var result = await _inventoryService.TriggerAgentReplenishmentAsync(
                    dto,
                    Request.Headers.Authorization.ToString());
                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (System.Net.Http.HttpRequestException ex)
            {
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new { message = ex.Message });
            }
        }

        private bool AssignWorkerEmployeeId(CreateStockAlertDto alertDto)
        {
            var employeeId = User.FindFirst("employee_id")?.Value;
            if (string.IsNullOrWhiteSpace(employeeId)) return false;
            alertDto.WorkerId = employeeId;
            return true;
        }
    }
}
