using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using backend.Services;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    /// <summary>
    /// Background service that continuously evaluates inventory stock levels.
    /// When any raw material or stock item enters low stock (at or below reorder threshold),
    /// this service automatically triggers the agentic replenishment workflow (LangGraph)
    /// without requiring manual Floor Worker button clicks.
    /// Deduplicates active workflows and open POs to prevent redundant orders.
    /// </summary>
    public sealed class AutoReplenishmentWorker(IServiceScopeFactory scopes, ILogger<AutoReplenishmentWorker> logger) : BackgroundService
    {
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Initial warm-up delay to allow the application and AI service to initialize
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = scopes.CreateScope();
                    var inventoryService = scope.ServiceProvider.GetRequiredService<IInventoryService>();
                    await inventoryService.ProcessAutomatedLowStockReplenishmentAsync();
                }
                catch (Exception error)
                {
                    logger.LogWarning(error, "Automated low stock replenishment check encountered an issue");
                }

                try
                {
                    // Check every 10 seconds for any low stock requiring replenishment
                    await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
            }
        }
    }
}

