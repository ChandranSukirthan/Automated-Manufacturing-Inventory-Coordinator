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
    [Authorize(Roles = "QualityInspector,SupplyChainManager,ITAdmin")]
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

            var physicalBatch = await _db.StockRolls.AsNoTracking().Where(r => r.RollIdentifier == value)
                .Select(r => r.BatchId).FirstOrDefaultAsync();
            if (batch == null && physicalBatch != null) batch = await _db.Batches.AsNoTracking().FirstOrDefaultAsync(b => b.Id == physicalBatch);
            if (batch == null) return NotFound(new { message = "Batch was not found." });

            var inventoryRolls = await _db.InventoryRolls
                .AsNoTracking()
                .Where(item => item.BatchId == batch.Id)
                .ToListAsync();

            var physicalRolls = await _db.StockRolls.AsNoTracking().Where(r => r.BatchId == batch.Id).ToListAsync();
            var canonicalIds = physicalRolls.Select(r => r.RollIdentifier).ToHashSet();
            var rollDtos = physicalRolls.Select(r => new InventoryRollDto { Id = r.RollIdentifier, BatchId = batch.Id,
                Status = r.Status == "Quarantined" || r.Status == "On Hold" || r.Status == "Locked" ? ManufacturingCoordinator.Enums.InventoryStatus.Quarantined : ManufacturingCoordinator.Enums.InventoryStatus.Available }).ToList();
            rollDtos.AddRange(inventoryRolls.Where(r => !canonicalIds.Contains(r.Id)).Select(r => new InventoryRollDto { Id = r.Id, BatchId = r.BatchId, Status = r.Status }));
            return Ok(new BatchDetailsDto
            {
                Id = batch.Id,
                ProductType = batch.ProductType,
                InventoryRolls = rollDtos
            });
        }

        [HttpPost]
        [Authorize(Roles = "QualityInspector,ITAdmin")]
        public async Task<IActionResult> CreateBatch([FromBody] ManufacturingCoordinator.Models.Inventory.Batch batch)
        {
            if (batch == null || string.IsNullOrWhiteSpace(batch.Id))
                return BadRequest(new { message = "Batch ID is required." });

            var cleanId = batch.Id.Trim();
            if (await _db.Batches.AnyAsync(b => b.Id.ToLower() == cleanId.ToLower()))
                return Conflict(new { message = $"Batch with ID '{cleanId}' already exists." });

            batch.Id = cleanId;
            _db.Batches.Add(batch);
            await _db.SaveChangesAsync();
            return CreatedAtAction(nameof(GetById), new { id = batch.Id }, new BatchDetailsDto
            {
                Id = batch.Id,
                ProductType = batch.ProductType,
                InventoryRolls = new List<InventoryRollDto>()
            });
        }
    }
}
