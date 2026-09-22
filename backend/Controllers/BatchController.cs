using System.Threading.Tasks;
using System.Linq;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Inventory;
using ManufacturingCoordinator.Data;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/batches")]
    [Authorize(Roles = "QualityInspector")]
    public class BatchController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public BatchController(ApplicationDbContext db)
        {
            _db = db;
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(string id)
        {
            var value = id.Trim();
            var batch = await _db.Batches
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.Id == value);

            if (batch == null)
            {
                var relatedBatchId = await _db.InventoryRolls
                    .Where(item => item.Id == value)
                    .Select(item => item.BatchId)
                    .FirstOrDefaultAsync();
                if (!string.IsNullOrWhiteSpace(relatedBatchId))
                {
                    batch = await _db.Batches
                        .AsNoTracking()
                        .FirstOrDefaultAsync(item => item.Id == relatedBatchId);
                }
            }

            if (batch == null) return NotFound(new { message = "Batch was not found." });

            var inventoryRolls = await _db.InventoryRolls
                .AsNoTracking()
                .Where(item => item.BatchId == batch.Id)
                .ToListAsync();

            return Ok(new BatchDetailsDto
            {
                Id = batch.Id,
                ProductType = batch.ProductType,
                InventoryRolls = inventoryRolls.Select(roll => new InventoryRollDto
                {
                    Id = roll.Id,
                    BatchId = roll.BatchId,
                    Status = roll.Status
                }).ToList()
            });
        }
    }
}