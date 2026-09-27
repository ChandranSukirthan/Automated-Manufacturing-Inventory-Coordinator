using System;
using System.Linq;
using backend.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;

namespace backend
{
    public static class Patcher
    {
        public static async System.Threading.Tasks.Task Run(IServiceProvider services)
        {
            using var scope = services.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ManufacturingContext>();
            var appDb = scope.ServiceProvider.GetRequiredService<ManufacturingCoordinator.Data.ApplicationDbContext>();
            
            var suppliers = await appDb.Suppliers.Where(s => s.IsActive).ToListAsync();
            var candidates = await appDb.SupplierCandidates.Where(c => c.SupplierStatus == "UNVERIFIED").ToListAsync();
            
            int count = 0;
            foreach (var c in candidates)
            {
                var match = suppliers.FirstOrDefault(s => s.Name.ToLower() == c.SupplierName.ToLower());
                if (match != null)
                {
                    c.SupplierId = match.Id;
                    c.SupplierStatus = "APPROVED";
                    c.IsValidated = true;
                    count++;
                }
            }
            if (count > 0) await appDb.SaveChangesAsync();
            
            var readAlerts = await context.StockAlerts.Where(a => !a.IsRead).ToListAsync();
            foreach (var a in readAlerts)
            {
                // check if PO exists for this material
                var hasPo = await appDb.OrderLines.AnyAsync(l => l.RawMaterialId == a.MaterialId && l.PurchaseOrder != null && l.PurchaseOrder.Status != ManufacturingCoordinator.Enums.PurchaseOrderStatus.Rejected);
                if (hasPo)
                {
                    a.IsRead = true;
                    a.Status = "Resolved";
                }
            }
            await context.SaveChangesAsync();
            Console.WriteLine($"Patched {count} candidates.");
        }
    }
}
