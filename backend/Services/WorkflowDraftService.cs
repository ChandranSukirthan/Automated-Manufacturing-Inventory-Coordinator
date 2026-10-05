using System.Text.Json;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;
using Microsoft.EntityFrameworkCore;

namespace ManufacturingCoordinator.Services.PurchaseOrders;

public sealed class WorkflowDraftService(ApplicationDbContext db)
{
    public async Task<int?> FinalizeAsync(string workflowId)
    {
        var workflow = await db.AgentWorkflows.SingleOrDefaultAsync(w => w.WorkflowId == workflowId);
        if (workflow == null || workflow.WorkflowType != "Procurement") return null;
        if (workflow.PurchaseOrderId.HasValue) return workflow.PurchaseOrderId;
        if (workflow.Status != WorkflowStatus.WaitingForApproval || string.IsNullOrWhiteSpace(workflow.StateJson)) return null;
        using var document = JsonDocument.Parse(workflow.StateJson);
        var state = document.RootElement;
        var requestId = state.TryGetProperty("procurement_request_id", out var requestValue) && requestValue.ValueKind == JsonValueKind.Number && requestValue.TryGetInt32(out var parsedRequestId)
            ? (int?)parsedRequestId : null;
        if (requestId.HasValue)
        {
            var prior = await db.PurchaseOrders.SingleOrDefaultAsync(p => p.ProcurementRequestId == requestId);
            if (prior != null) { workflow.PurchaseOrderId = prior.Id; await db.SaveChangesAsync(); return prior.Id; }
        }
        if (!state.TryGetProperty("draft_po", out var draft) || draft.ValueKind != JsonValueKind.Object) return null;
        if (!state.TryGetProperty("validation_results", out var validation) ||
            !validation.TryGetProperty("isValid", out var valid) || valid.ValueKind != JsonValueKind.True) return null;
        if (!ManufacturingCoordinator.Api.Helpers.QualityValidationPolicy.NonQualityChecksPassed(
                JsonSerializer.Deserialize<Dictionary<string, object?>>(validation.GetRawText()) ?? new())) return null;
        if (validation.TryGetProperty("qualitySafetyStatus", out var quality) && quality.GetString() is not ("CLEAR" or "PASSED")) return null;
        var sku = state.GetProperty("material_id").GetString();
        var material = await db.RawMaterials.SingleOrDefaultAsync(m => m.SkuCode == sku || m.Id.ToString() == sku)
            ?? throw new InvalidOperationException("The workflow material is not in the catalogue.");
        var code = draft.GetProperty("supplierId").ToString();
        var supplier = await db.Suppliers.SingleOrDefaultAsync(s => s.SupplierCode == code && s.IsActive)
            ?? throw new InvalidOperationException("The recommended supplier must be onboarded before creating a PO.");
        var quantity = draft.GetProperty("quantity").GetDecimal();
        var price = draft.GetProperty("unitPrice").GetDecimal();
        var budget = state.TryGetProperty("budget_limit", out var b) && b.ValueKind == JsonValueKind.Number ? b.GetDecimal() : 0;
        if (quantity <= 0 || price <= 0 || budget <= 0 || quantity * price > budget)
            throw new InvalidOperationException("A positive quantity, price and authorized budget are required.");
        // This PO number is deterministic per durable workflow, so retries cannot create another order.
        var number = $"PO-{workflow.StartedAt:yyyy}-{workflow.Id:N}";
        var existing = await db.PurchaseOrders.SingleOrDefaultAsync(p => p.PoNumber == number);
        if (existing != null) { workflow.PurchaseOrderId = existing.Id; await db.SaveChangesAsync(); return existing.Id; }
        var po = new PurchaseOrder { PoNumber = number, SupplierId = supplier.Id, BudgetLimit = budget,
            ProcurementRequestId = requestId,
            Currency = draft.TryGetProperty("currency", out var currency) ? currency.GetString() ?? "USD" : "USD",
            Status = PurchaseOrderStatus.PendingApproval, RequiresApproval = true,
            TotalCost = Math.Round(quantity * price, 2), Notes = $"[AI workflow] {workflow.WorkflowId}" };
        po.OrderLines.Add(new OrderLine { RawMaterialId = material.Id, Description = material.Name,
            Quantity = quantity, UnitPrice = price, TotalPrice = po.TotalCost });
        db.PurchaseOrders.Add(po);
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync() : null;
        await db.SaveChangesAsync();
        workflow.PurchaseOrderId = po.Id;
        var alerts = await db.StockAlerts.Where(a => a.Sku == material.SkuCode &&
            (a.Status == "Pending" || a.Status == "Acknowledged")).ToListAsync();
        foreach (var alert in alerts) alert.Status = "Processing";
        await db.SaveChangesAsync();
        if (transaction != null) await transaction.CommitAsync();
        return po.Id;
    }
}

public sealed class WorkflowDraftWorker(IServiceScopeFactory scopes, ILogger<WorkflowDraftWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                var ids = await db.AgentWorkflows.Where(w => w.WorkflowType == "Procurement" &&
                    w.PurchaseOrderId == null && w.StateJson != null && w.Status == WorkflowStatus.WaitingForApproval)
                    .Select(w => w.WorkflowId).ToListAsync(stoppingToken);
                foreach (var id in ids)
                {
                    // Each job has an independent unit of work; one bad result cannot poison the next.
                    using var jobScope = scopes.CreateScope();
                    try { await jobScope.ServiceProvider.GetRequiredService<WorkflowDraftService>().FinalizeAsync(id); }
                    catch (Exception error) { logger.LogWarning(error, "Draft creation failed for {WorkflowId}", id); }
                }
            }
            catch (Exception error) { logger.LogWarning(error, "Workflow draft polling failed"); }
            try { await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}
