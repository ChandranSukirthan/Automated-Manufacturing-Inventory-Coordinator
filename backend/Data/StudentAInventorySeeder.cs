using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using backend.Models;

namespace backend.Data
{
    /// <summary>
    /// Seeds the persistent catalogue used by a consumer-food packaging plant.
    /// The client reads these rows through the API; it does not own a list of
    /// packaging types, materials, or SKU prefixes.
    /// </summary>
    public static class StudentAInventorySeeder
    {
        private sealed record PackagingSeed(string Name, string ShortCode);
        private sealed record MaterialSeed(
            string PackagingType,
            string MaterialCode,
            string Name,
            string Description,
            string Unit,
            decimal ReorderThreshold,
            int[] SkuNumbers,
            int[] OpeningStock);

        // Modelled after a Ceylon tea and biscuit manufacturer's packaging
        // operation: flexible pouches, tea bags, biscuit wrappers, cans and
        // PET bottles each use their own compatible source materials.
        private static readonly PackagingSeed[] PackagingTypes =
        {
            new("Box Pouch", "BP"),
            new("Biscuit Packaging", "BIS"),
            new("Tea Bag", "TB"),
            new("Bag", "BAG"),
            new("Can", "CAN"),
            new("Bottle", "BTL"),
            new("Standard Roll", "SR"),
        };

        private static readonly MaterialSeed[] Materials =
        {
            new("Box Pouch", "LAM", "Laminated Barrier Film", "Food-grade laminated film for tea and snack box pouches.", "KG", 180m, new[] { 1, 2 }, new[] { 640, 420 }),
            new("Box Pouch", "INK", "Water-based Flexographic Ink", "Low-migration ink for pouch printing.", "KG", 90m, new[] { 1 }, new[] { 120 }),
            new("Biscuit Packaging", "MOP", "Metallized OPP Film", "Moisture-barrier film for biscuit wrappers.", "KG", 220m, new[] { 1, 2 }, new[] { 780, 510 }),
            new("Biscuit Packaging", "INK", "Food-safe Printing Ink", "Food-contact compliant wrapper printing ink.", "KG", 75m, new[] { 1 }, new[] { 95 }),
            new("Tea Bag", "FIL", "Heat-sealable Filter Paper", "Porous filter paper for tea-bag envelopes.", "ROLL", 60m, new[] { 1, 2 }, new[] { 180, 110 }),
            new("Tea Bag", "THR", "Cotton Tag Thread", "Food-safe cotton string for tagged tea bags.", "SPOOL", 45m, new[] { 1 }, new[] { 70 }),
            new("Bag", "LDP", "LDPE Film", "Food-grade polyethylene film for carry bags.", "KG", 160m, new[] { 1 }, new[] { 360 }),
            new("Can", "TIN", "Tinplate Sheet", "Lacquered tinplate for dry-food cans.", "SHEET", 140m, new[] { 1 }, new[] { 260 }),
            new("Bottle", "PET", "PET Preform", "Food-grade PET preforms for beverage bottles.", "UNITS", 500m, new[] { 1, 2 }, new[] { 1900, 860 }),
            new("Standard Roll", "KRF", "Kraft Paper Liner", "Kraft liner roll for secondary packaging.", "ROLL", 50m, new[] { 1 }, new[] { 125 }),
        };

        public static async Task SeedAsync(ManufacturingContext context)
        {
            var existingPackagingNames = await context.PackagingTypes
                .Select(type => type.Name)
                .ToListAsync();
            var existingPackagingNameSet = existingPackagingNames
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            var missingPackagingTypes = PackagingTypes
                .Where(seed => !existingPackagingNameSet.Contains(seed.Name))
                .Select(seed => new PackagingType
                {
                    Name = seed.Name,
                    ShortCode = seed.ShortCode,
                    IsActive = true,
                })
                .ToArray();

            if (missingPackagingTypes.Length > 0)
            {
                context.PackagingTypes.AddRange(missingPackagingTypes);
                await context.SaveChangesAsync();
            }

            // Keep normal application restarts non-destructive. The database
            // migration deliberately removes the old catalogue once; this only
            // fills a brand-new database or an empty development catalogue.
            if (!await context.RawMaterials.AnyAsync() && !await context.InventoryItems.AnyAsync())
            {
                var packagingByName = await context.PackagingTypes
                    .ToDictionaryAsync(type => type.Name, StringComparer.OrdinalIgnoreCase);

                foreach (var seed in Materials)
                {
                    var packaging = packagingByName[seed.PackagingType];
                    for (var index = 0; index < seed.SkuNumbers.Length; index++)
                    {
                        var number = seed.SkuNumbers[index];
                        var sku = BuildSku(packaging.ShortCode, seed.MaterialCode, number);
                        var material = new RawMaterial
                        {
                            SkuCode = sku,
                            Name = seed.Name,
                            Description = seed.Description,
                            Category = packaging.Name,
                            MaterialCode = seed.MaterialCode,
                            PackagingTypeId = packaging.Id,
                            UnitOfMeasure = seed.Unit,
                            ReorderThreshold = seed.ReorderThreshold,
                            CreatedAt = DateTime.UtcNow,
                            UpdatedAt = DateTime.UtcNow,
                        };
                        context.RawMaterials.Add(material);
                        await context.SaveChangesAsync();

                        context.InventoryItems.Add(new InventoryItem
                        {
                            Sku = sku,
                            Name = seed.Name,
                            Category = packaging.Name,
                            PackagingTypeId = packaging.Id,
                            RawMaterialId = material.Id,
                            SkuNumber = number,
                            StockLevel = seed.OpeningStock[index],
                            ReorderThreshold = (int)seed.ReorderThreshold,
                        });
                    }
                }
                await context.SaveChangesAsync();
            }

            // QA evaluates physical rolls, while the stock page is backed by
            // aggregate InventoryItems. Keep those two views reconciled so a
            // SKU offered by the defect form always has a real roll and batch.
            // The operation is additive and preserves all existing roll data.
            var inventoryItems = await context.InventoryItems
                .Where(item => item.RawMaterialId.HasValue && item.StockLevel > 0)
                .OrderBy(item => item.Sku)
                .ToListAsync();
            var materialIds = inventoryItems.Select(item => item.RawMaterialId!.Value).Distinct().ToList();
            var materialsById = await context.RawMaterials
                .Where(material => materialIds.Contains(material.Id))
                .ToDictionaryAsync(material => material.Id);
            var existingRolls = await context.InventoryRolls
                .Where(roll => materialIds.Contains(roll.RawMaterialId))
                .OrderBy(roll => roll.Id)
                .ToListAsync();
            var rollIdentifierSet = existingRolls
                .Select(roll => roll.RollIdentifier)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            var now = DateTime.UtcNow;

            foreach (var item in inventoryItems)
            {
                if (!materialsById.TryGetValue(item.RawMaterialId!.Value, out var material)) continue;

                var batchId = $"BATCH-{material.SkuCode}";
                var materialRolls = existingRolls.Where(roll => roll.RawMaterialId == material.Id).ToList();
                foreach (var roll in materialRolls.Where(roll => string.IsNullOrWhiteSpace(roll.BatchId)))
                {
                    roll.BatchId = batchId;
                    roll.UpdatedAt = now;
                }

                var registeredQuantity = materialRolls.Sum(roll => Math.Max(0m, roll.CurrentQuantity));
                var missingQuantity = Math.Max(0m, item.StockLevel - registeredQuantity);
                if (missingQuantity <= 0) continue;

                var sequence = materialRolls.Count + 1;
                string identifier;
                do
                {
                    identifier = $"ROLL-{material.SkuCode}-{sequence:D2}";
                    sequence++;
                } while (rollIdentifierSet.Contains(identifier));

                var newRoll = new InventoryRoll
                {
                    RawMaterialId = material.Id,
                    BatchId = batchId,
                    RollIdentifier = identifier,
                    BarcodeUrl = $"/api/inventory/rolls/{identifier}/qr",
                    InitialQuantity = missingQuantity,
                    CurrentQuantity = missingQuantity,
                    Status = "In Stock",
                    ReceivedDate = now,
                    CreatedAt = now,
                    UpdatedAt = now,
                };
                context.InventoryRolls.Add(newRoll);
                existingRolls.Add(newRoll);
                rollIdentifierSet.Add(identifier);
            }

            await context.SaveChangesAsync();
        }

        private static string BuildSku(string packagingCode, string materialCode, int number) =>
            $"{packagingCode}-{materialCode}-{number:D3}";
    }
}
