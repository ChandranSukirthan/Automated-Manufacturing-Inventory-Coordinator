using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using backend.Dtos;
using backend.Services;
using backend.Models;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class InventoryController : ControllerBase
    {
        private readonly IInventoryService _inventoryService;

        public InventoryController(IInventoryService inventoryService)
        {
            _inventoryService = inventoryService;
        }

        // GET: api/inventory
        [HttpGet]
        public async Task<ActionResult<IEnumerable<InventoryItemDto>>> GetInventory()
        {
            var items = await _inventoryService.GetInventoryItemsAsync();
            return Ok(items);
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
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var createdAlert = await _inventoryService.CreateStockAlertAsync(alertDto);
            return CreatedAtAction(nameof(GetAlerts), new { id = createdAlert.Id }, createdAlert);
        }

        // PUT: api/inventory/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> PutItem(int id, [FromBody] InventoryItem item)
        {
            if (id != item.Id)
            {
                return BadRequest("ID mismatch");
            }

            var success = await _inventoryService.UpdateInventoryItemAsync(id, item);
            if (!success)
            {
                return NotFound();
            }

            return NoContent();
        }

        // DELETE: api/inventory/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteItem(int id)
        {
            var success = await _inventoryService.DeleteInventoryItemAsync(id);
            if (!success)
            {
                return NotFound();
            }

            return NoContent();
        }

        // POST: api/inventory
        [HttpPost]
        public async Task<ActionResult<InventoryItem>> CreateItem([FromBody] InventoryItem item)
        {
            var createdItem = await _inventoryService.CreateInventoryItemAsync(item);
            return CreatedAtAction(nameof(GetInventory), new { id = createdItem.Id }, createdItem);
        }

        // GET: api/inventory/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<InventoryItem>> GetItem(int id)
        {
            var item = await _inventoryService.GetInventoryItemByIdAsync(id);

            if (item == null)
            {
                return NotFound(); // Returns a 404 if the ID doesn't exist
            }

            return Ok(item); // Returns a 200 OK with the item data
        }
    }
}