using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Models.PurchaseOrders;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ManufacturingCoordinator.Api.Controllers;

[ApiController, Route("api/suppliers/{supplierId:int}/quotes")]
[Authorize(Roles = "SupplyChainManager")]
public sealed class SupplierQuotesController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(int supplierId) => Ok(await db.SupplierMaterialQuotes
        .Where(q => q.SupplierId == supplierId).ToListAsync());

    [HttpPost]
    public async Task<IActionResult> Create(int supplierId, SupplierMaterialQuote quote)
    {
        if (!await db.Suppliers.AnyAsync(s => s.Id == supplierId && s.IsActive) ||
            !await db.RawMaterials.AnyAsync(m => m.Id == quote.RawMaterialId))
            return BadRequest(new { message = "Choose an active supplier and an existing material." });
        quote.Id = 0;
        quote.SupplierId = supplierId;
        quote.UpdatedAt = DateTime.UtcNow;
        db.SupplierMaterialQuotes.Add(quote);
        await db.SaveChangesAsync();
        return Ok(quote);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int supplierId, int id, SupplierMaterialQuote quote)
    {
        var existing = await db.SupplierMaterialQuotes.SingleOrDefaultAsync(q => q.Id == id && q.SupplierId == supplierId);
        if (existing == null) return NotFound();
        if (quote.RawMaterialId != existing.RawMaterialId)
            return BadRequest(new { message = "A quote's material is immutable. Add a new quote for another material." });
        existing.UnitPrice = quote.UnitPrice;
        existing.MinimumOrderQuantity = quote.MinimumOrderQuantity;
        existing.PackSize = quote.PackSize;
        existing.AvailableQuantity = quote.AvailableQuantity;
        existing.LeadTimeDays = quote.LeadTimeDays;
        existing.QualityEvidence = quote.QualityEvidence;
        existing.Currency = quote.Currency;
        existing.IsActive = quote.IsActive;
        existing.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return Ok(existing);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Deactivate(int supplierId, int id)
    {
        var quote = await db.SupplierMaterialQuotes.SingleOrDefaultAsync(q => q.Id == id && q.SupplierId == supplierId);
        if (quote == null) return NotFound();
        quote.IsActive = false;
        quote.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return NoContent();
    }
}
