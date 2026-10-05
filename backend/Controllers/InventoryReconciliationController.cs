using ManufacturingCoordinator.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ManufacturingCoordinator.Api.Controllers;

[ApiController, Route("api/inventory/reconciliation")]
[Authorize(Roles = "ITAdmin,SupplyChainManager,QualityInspector")]
public sealed class InventoryReconciliationController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var materials = await db.RawMaterials.AsNoTracking().ToListAsync();
        var balances = await db.InventoryItems.AsNoTracking().ToListAsync();
        var physical = await db.StockRolls.AsNoTracking().ToListAsync();
        var qa = await db.InventoryRolls.AsNoTracking().ToListAsync();
        var holds = await db.Quarantines.AsNoTracking().Where(q => q.Status == ManufacturingCoordinator.Enums.QuarantineStatus.Active).ToListAsync();
        var identifiers = physical.Select(r => r.RollIdentifier).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return Ok(new {
            unmappedCatalogueMaterials = materials.Where(m => m.PackagingTypeId == -1 || string.IsNullOrWhiteSpace(m.MaterialCode))
                .Select(m => new { m.Id, m.SkuCode, m.Name, m.PackagingTypeId }),
            unmatchedQualityRolls = qa.Where(r => !identifiers.Contains(r.Id)).Select(r => new { r.Id, r.BatchId }),
            unmatchedActiveQuarantines = holds.Where(q => !identifiers.Contains(q.InventoryRollId)).Select(q => new { q.Id, q.InventoryRollId, q.DefectReportId }),
            missingBatchIdentity = physical.Where(r => string.IsNullOrWhiteSpace(r.BatchId)).Select(r => new { r.Id, r.RollIdentifier, r.RawMaterialId }),
            balanceDifferences = balances.Select(i => {
                var material = materials.SingleOrDefault(m => m.SkuCode == i.Sku);
                var quantity = material == null ? 0 : physical.Where(r => r.RawMaterialId == material.Id && (r.Status == "In Stock" || r.Status == "In Production")).Sum(r => r.CurrentQuantity);
                return new { i.Id, i.Sku, i.StockLevel, physicalAvailableQuantity = quantity, difference = i.StockLevel - quantity };
            }).Where(i => i.difference != 0),
            message = "Historical mismatches are retained. Review supporting receipt and QA records before adjusting stock or linking identifiers."
        });
    }
}
