using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

public sealed class ListQuery
{
    [Range(1, 100000)] public int Page { get; set; } = 1;
    [Range(1, 100)] public int PageSize { get; set; } = 20;
    [StringLength(100)] public string? Search { get; set; }
    [RegularExpression("^(name|date|id)$")] public string Sort { get; set; } = "name";
    [RegularExpression("^(asc|desc)$")] public string Direction { get; set; } = "asc";
    [RegularExpression("^(active|inactive|all)$")] public string Status { get; set; } = "all";
}

[ApiController]
[Authorize]
public sealed class PagedListsController(ApplicationDbContext db) : ControllerBase
{
    // Existing array endpoints remain compatible with both clients. These routes
    // perform filtering, deterministic ordering and limiting before materialization.
    [HttpGet("api/suppliers/paged")]
    public async Task<IActionResult> Suppliers([FromQuery] ListQuery q)
    {
        var query = db.Suppliers.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q.Search)) { var term = q.Search.Trim().ToLower(); query = query.Where(s => s.Name.ToLower().Contains(term) || s.SupplierCode.ToLower().Contains(term) || s.ContactEmail.ToLower().Contains(term) || s.ContactPhone.ToLower().Contains(term) || s.Address.ToLower().Contains(term)); }
        if (q.Status != "all") query = query.Where(s => s.IsActive == (q.Status == "active"));
        query = q.Sort == "date" ? (q.Direction == "desc" ? query.OrderByDescending(s => s.CreatedAt).ThenBy(s => s.Id) : query.OrderBy(s => s.CreatedAt).ThenBy(s => s.Id)) :
            q.Sort == "id" ? (q.Direction == "desc" ? query.OrderByDescending(s => s.Id) : query.OrderBy(s => s.Id)) :
            q.Direction == "desc" ? query.OrderByDescending(s => s.Name).ThenBy(s => s.Id) : query.OrderBy(s => s.Name).ThenBy(s => s.Id);
        return await Page(query.Select(s => new { s.Id, s.Name, s.SupplierCode, s.ContactEmail, s.ContactPhone, s.Address, s.PaymentTerms, s.LeadTimeDays, s.IsActive, s.CreatedAt, s.UpdatedAt }), q);
    }

    [HttpGet("api/inventory/paged")]
    [Authorize(Roles = "FloorWorker,QualityInspector,SupplyChainManager,ITAdmin")]
    public async Task<IActionResult> Inventory([FromQuery] ListQuery q)
    {
        var query = db.InventoryItems.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q.Search)) { var term = q.Search.Trim().ToLower(); query = query.Where(s => s.Name.ToLower().Contains(term) || s.Sku.ToLower().Contains(term)); }
        query = q.Sort == "id" ? (q.Direction == "desc" ? query.OrderByDescending(s => s.Id) : query.OrderBy(s => s.Id)) : q.Direction == "desc" ? query.OrderByDescending(s => s.Name).ThenBy(s => s.Id) : query.OrderBy(s => s.Name).ThenBy(s => s.Id);
        return await Page(query.Select(s => new { s.Id, s.Name, s.Sku, s.Category, s.StockLevel, s.ReorderThreshold, s.RawMaterialId }), q);
    }

    [HttpGet("api/machines/paged")]
    public async Task<IActionResult> Machines([FromQuery] ListQuery q)
    {
        var query = db.Machines.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q.Search)) { var term = q.Search.Trim().ToLower(); query = query.Where(s => s.Name.ToLower().Contains(term) || s.Location.ToLower().Contains(term)); }
        query = q.Sort == "date" ? (q.Direction == "desc" ? query.OrderByDescending(s => s.CreatedAt).ThenBy(s => s.Id) : query.OrderBy(s => s.CreatedAt).ThenBy(s => s.Id)) : q.Direction == "desc" ? query.OrderByDescending(s => s.Name).ThenBy(s => s.Id) : query.OrderBy(s => s.Name).ThenBy(s => s.Id);
        return await Page(query.Select(s => new { s.Id, s.Name, status = s.Status.ToString(), s.Location, s.UptimeHours, s.MaintenanceIntervalHours, s.CreatedAt }), q);
    }

    [HttpGet("api/defects/paged")]
    [Authorize(Roles = "QualityInspector,SupplyChainManager,ITAdmin")]
    public async Task<IActionResult> Defects([FromQuery] ListQuery q)
    {
        var query = db.DefectReports.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q.Search)) { var term = q.Search.Trim().ToLower(); query = query.Where(s => s.SkuCode.ToLower().Contains(term) || s.BatchId.ToLower().Contains(term) || s.Description.ToLower().Contains(term)); }
        query = q.Direction == "desc" ? query.OrderByDescending(s => s.CreatedAt).ThenBy(s => s.Id) : query.OrderBy(s => s.CreatedAt).ThenBy(s => s.Id);
        return await Page(query.Select(s => new { s.Id, s.SkuCode, s.BatchId, s.Description, severity = s.Severity.ToString(), status = s.Status.ToString(), s.CreatedAt }), q);
    }

    [HttpGet("api/purchase-orders/paged")]
    [Authorize(Roles = "FloorWorker,SupplyChainManager,ITAdmin")]
    public async Task<IActionResult> PurchaseOrders([FromQuery] ListQuery q)
    {
        var query = db.PurchaseOrders.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q.Search)) { var term = q.Search.Trim().ToLower(); query = query.Where(s => s.PoNumber.ToLower().Contains(term) || s.Supplier.Name.ToLower().Contains(term)); }
        query = q.Sort == "name" ? (q.Direction == "desc" ? query.OrderByDescending(s => s.PoNumber).ThenBy(s => s.Id) : query.OrderBy(s => s.PoNumber).ThenBy(s => s.Id)) : q.Direction == "desc" ? query.OrderByDescending(s => s.CreatedAt).ThenBy(s => s.Id) : query.OrderBy(s => s.CreatedAt).ThenBy(s => s.Id);
        return await Page(query.Select(s => new { s.Id, s.PoNumber, supplierName = s.Supplier.Name, status = s.Status.ToString(), s.Currency, s.TotalCost, s.BudgetLimit, s.RequiresApproval, s.CreatedAt, s.UpdatedAt }), q);
    }

    private async Task<IActionResult> Page<T>(IQueryable<T> query, ListQuery q)
    {
        var totalCount = await query.CountAsync();
        var items = await query.Skip((q.Page - 1) * q.PageSize).Take(q.PageSize).ToListAsync();
        return Ok(new { items, totalCount, page = q.Page, pageSize = q.PageSize });
    }
}
