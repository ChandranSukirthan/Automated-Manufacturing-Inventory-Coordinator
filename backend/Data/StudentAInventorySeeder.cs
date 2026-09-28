using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using backend.Models;

namespace backend.Data
{
    /// <summary>
    /// Ensures the Student A material catalogue exists in the inventory database.
    /// These are persisted database records, not client-side fallback data.
    /// </summary>
    public static class StudentAInventorySeeder
    {
        private sealed record MaterialSeed(
            string Sku,
            string Name,
            string Category,
            string Unit,
            decimal ReorderThreshold);

        private static readonly MaterialSeed[] Materials =
        {
            new("PAPER-A1", "High Gloss Label Paper", "Label", "KG", 150m),
            new("CR-001", "Custom Roll", "BoxPouch", "UNITS", 100m),
            new("BISCUIT-001", "Biscuit Packaging", "BiscuitPackaging", "UNITS", 100m),
            new("CAN-001", "can90", "Can", "UNITS", 100m),
            new("080", "Tea-ceylon", "TeaBag", "UNITS", 70m),
            new("BAG-001", "Packaging Bag", "Bag", "UNITS", 100m),
            new("BOTTLE-001", "Bottle", "Bottle", "UNITS", 100m),
            new("STANDARD-ROLL-001", "Standard Roll", "Standard Roll", "UNITS", 100m),
        };

        public static async Task SeedAsync(ManufacturingContext context)
        {
            var existingMaterialSkus = (await context.RawMaterials
                    .Select(material => material.SkuCode)
                    .ToListAsync())
                .Select(NormalizeSku)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var seed in Materials.Where(seed => !existingMaterialSkus.Contains(NormalizeSku(seed.Sku))))
            {
                context.RawMaterials.Add(new RawMaterial
                {
                    SkuCode = seed.Sku,
                    Name = seed.Name,
                    Category = seed.Category,
                    UnitOfMeasure = seed.Unit,
                    Description = $"{seed.Category} material used by the manufacturing floor.",
                    ReorderThreshold = seed.ReorderThreshold,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            await context.SaveChangesAsync();

            var existingItemSkus = (await context.InventoryItems
                    .Select(item => item.Sku)
                    .ToListAsync())
                .Select(NormalizeSku)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var seed in Materials.Where(seed => !existingItemSkus.Contains(NormalizeSku(seed.Sku))))
            {
                context.InventoryItems.Add(new InventoryItem
                {
                    Sku = seed.Sku,
                    Name = seed.Name,
                    Category = seed.Category,
                    StockLevel = 0,
                    ReorderThreshold = (int)seed.ReorderThreshold,
                });
            }
            await context.SaveChangesAsync();
        }

        private static string NormalizeSku(string value) => value
            .Replace("-", string.Empty, StringComparison.Ordinal)
            .Replace(" ", string.Empty, StringComparison.Ordinal)
            .Trim();
    }
}
