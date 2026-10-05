using System.Security.Claims;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Services.PurchaseOrders;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ManufacturingCoordinator.Api.Controllers;

[ApiController, Route("api/purchase-orders/{poId:int}/receipts")]
[Authorize(Roles = "FloorWorker,SupplyChainManager,ITAdmin")]
public sealed class GoodsReceiptsController(GoodsReceiptService service, ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(int poId) => Ok(await db.GoodsReceipts
        .Where(r => r.PurchaseOrderId == poId).OrderBy(r => r.ReceivedAt).ToListAsync());

    [HttpPost]
    public async Task<IActionResult> Receive(int poId, ReceiveGoodsRequest request)
    {
        try
        {
            Guid? userId = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsed) ? parsed : null;
            return Ok(await service.ReceiveAsync(poId, request, userId));
        }
        catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
        catch (InvalidOperationException ex) { return Conflict(new { message = ex.Message }); }
        catch (DbUpdateException) { return Conflict(new { message = "This delivery changed concurrently or was already recorded. Refresh and retry with the same receipt key." }); }
        catch (Npgsql.PostgresException ex) when (ex.SqlState is "40001" or "40P01")
        { return Conflict(new { message = "Another delivery changed this order. Refresh and retry with the same receipt key." }); }
    }
}
