using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Quality;
using backend.Data;
using backend.Models;

namespace ManufacturingCoordinator.Api.Services
{
    public class DefectReportService : IDefectReportService
    {
        private readonly ApplicationDbContext _db;
        public DefectReportService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<IEnumerable<DefectReportDto>> GetAllAsync()
        {
            return await _db.DefectReports
                .OrderByDescending(d => d.CreatedAt)
                .Select(d => new DefectReportDto
                {
                    Id = d.Id,
                    SkuCode = d.SkuCode,
                    BatchId = d.BatchId,
                    ReportedByUserId = d.ReportedByUserId,
                    ProductType = d.ProductType,
                    Severity = d.Severity,
                    Description = d.Description,
                    AffectedInventory = DeserializeInventory(d.AffectedInventoryJson),
                    CreatedAt = d.CreatedAt,
                    Status = d.Status
                })
                .ToListAsync();
        }

        public async Task<DefectReportDto?> GetByIdAsync(Guid id)
        {
            var defect = await _db.DefectReports
                .FirstOrDefaultAsync(d => d.Id == id);

            if (defect == null) return null;

            return new DefectReportDto
            {
                Id = defect.Id,
                SkuCode = defect.SkuCode,
                BatchId = defect.BatchId,
                ReportedByUserId = defect.ReportedByUserId,
                ProductType = defect.ProductType,
                Severity = defect.Severity,
                Description = defect.Description,
                AffectedInventory = DeserializeInventory(defect.AffectedInventoryJson),
                CreatedAt = defect.CreatedAt,
                Status = defect.Status
            };
        }

        public async Task<DefectReportDto> CreateAsync(CreateDefectReportDto dto, Guid? reportedByUserId)
        {
            if (dto == null)
            {
                throw new ArgumentNullException(nameof(dto));
            }

            if (string.IsNullOrWhiteSpace(dto.SkuCode) && string.IsNullOrWhiteSpace(dto.BatchId))
            {
                throw new ArgumentException("SKU code is required.", nameof(dto));
            }

            if (string.IsNullOrWhiteSpace(dto.Description))
            {
                throw new ArgumentException("Description is required.", nameof(dto));
            }

            ValidateEnums(dto.ProductType, dto.Severity, dto.Status);
            var isCatalogueSkuReport = !string.IsNullOrWhiteSpace(dto.SkuCode);
            var context = !isCatalogueSkuReport
                ? await ResolveLegacyBatchContextAsync(dto.BatchId!, dto.ProductType)
                : await ResolveInventoryContextAsync(dto.SkuCode, dto.BatchId, dto.AffectedInventory);
            var batchId = context.BatchId;
            var productType = context.ProductType;

            var affectedInventory = dto.AffectedInventory?.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList()
                ?? new List<string>();

            // Ensure no selected roll is already associated with an active (open/in-review) defect report or active quarantine
            if (affectedInventory.Count > 0)
            {
                var activeReports = await _db.DefectReports
                    .Where(d => d.Status != DefectStatus.Resolved && d.Status != DefectStatus.Closed)
                    .ToListAsync();

                var activeQuarantineRolls = await _db.Quarantines
                    .Where(q => q.Status == QuarantineStatus.Active)
                    .Select(q => q.InventoryRollId.ToUpper())
                    .ToListAsync();
                var activeQuarantineSet = activeQuarantineRolls.ToHashSet(StringComparer.OrdinalIgnoreCase);

                var conflictingRolls = new List<string>();
                foreach (var rollId in affectedInventory)
                {
                    var cleanId = rollId.Trim().ToUpperInvariant();
                    if (activeQuarantineSet.Contains(cleanId))
                    {
                        conflictingRolls.Add(rollId);
                        continue;
                    }

                    foreach (var activeReport in activeReports)
                    {
                        var existingRolls = DeserializeInventory(activeReport.AffectedInventoryJson);
                        if (existingRolls.Any(r => r.Trim().Equals(cleanId, StringComparison.OrdinalIgnoreCase)))
                        {
                            conflictingRolls.Add(rollId);
                            break;
                        }
                    }
                }

                if (conflictingRolls.Count > 0)
                {
                    var rollListStr = string.Join(", ", conflictingRolls.Distinct());
                    throw new AuthException(
                        $"Inventory roll(s) [{rollListStr}] already have an active defect report or quarantine. A new defect report cannot be created for these rolls until the existing report is resolved or deleted.",
                        HttpStatusCode.Conflict);
                }
            }

            // Legacy batch reports retain the one-report-per-batch rule. A
            // floor-worker SKU report is an independent incident and may be
            // submitted before a physical roll or production batch exists.
            if (!isCatalogueSkuReport && await _db.DefectReports.AnyAsync(d => d.BatchId == batchId))
            {
                throw new AuthException(
                    "A defect has already been created for this batch.",
                    HttpStatusCode.Conflict);
            }

            var report = new DefectReport
            {
                SkuCode = isCatalogueSkuReport ? dto.SkuCode.Trim().ToUpperInvariant() : string.Empty,
                BatchId = batchId,
                ReportedByUserId = reportedByUserId,
                ProductType = productType,
                Severity = dto.Severity,
                Description = dto.Description.Trim(),
                AffectedInventoryJson = JsonSerializer.Serialize(affectedInventory),
                Status = dto.Status,
                CreatedAt = DateTime.UtcNow
            };

            _db.DefectReports.Add(report);
            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                SkuCode = report.SkuCode,
                BatchId = report.BatchId,
                ReportedByUserId = report.ReportedByUserId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                AffectedInventory = DeserializeInventory(report.AffectedInventoryJson),
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<DefectReportDto?> UpdateAsync(Guid id, UpdateDefectReportDto dto)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return null;

            var skuCode = string.IsNullOrWhiteSpace(dto.SkuCode)
                ? report.SkuCode
                : dto.SkuCode.Trim().ToUpperInvariant();
            var isCatalogueSkuReport = !string.IsNullOrWhiteSpace(skuCode);
            var batchId = string.IsNullOrWhiteSpace(dto.BatchId) ? report.BatchId : dto.BatchId.Trim();
            var productType = dto.ProductType ?? report.ProductType;
            var severity = dto.Severity ?? report.Severity;
            var status = dto.Status ?? report.Status;

            ValidateEnums(productType, severity, status);
            if (isCatalogueSkuReport)
            {
                var related = dto.AffectedInventory ?? DeserializeInventory(report.AffectedInventoryJson);
                if (await _db.Quarantines.AnyAsync(q => q.DefectReportId == id) &&
                    (skuCode != report.SkuCode || batchId != report.BatchId ||
                     !related.ToHashSet(StringComparer.OrdinalIgnoreCase).SetEquals(DeserializeInventory(report.AffectedInventoryJson))))
                    throw new AuthException("A defect with quarantine history cannot be reassigned to other inventory.", HttpStatusCode.Conflict);
                var context = await ResolveInventoryContextAsync(skuCode, dto.BatchId, related);
                productType = context.ProductType;
                if (related.Count > 0 || !string.IsNullOrWhiteSpace(dto.BatchId)) batchId = context.BatchId;
            }
            else
            {
                var batch = await _db.Batches.FirstOrDefaultAsync(b => b.Id == batchId);
                if (batch == null)
                {
                    throw new AuthException("Batch was not found.", HttpStatusCode.NotFound);
                }

                if (batch.ProductType != productType)
                {
                    throw new AuthException("Product type does not match the selected batch.");
                }

                if (await _db.DefectReports.AnyAsync(d => d.BatchId == batchId && d.Id != id))
                {
                    throw new AuthException(
                        "A defect has already been created for this batch.",
                        HttpStatusCode.Conflict);
                }
            }

            report.BatchId = batchId;
            report.SkuCode = skuCode;
            report.ProductType = productType;
            report.Severity = severity;

            if (!string.IsNullOrWhiteSpace(dto.Description))
            {
                report.Description = dto.Description.Trim();
            }

            if (string.IsNullOrWhiteSpace(report.Description))
            {
                throw new AuthException("Description is required.");
            }

            report.Status = status;
            if (dto.AffectedInventory != null)
            {
                var newRolls = dto.AffectedInventory.Where(x => !string.IsNullOrWhiteSpace(x)).Distinct().ToList();
                if (newRolls.Count > 0)
                {
                    var otherActiveReports = await _db.DefectReports
                        .Where(d => d.Id != id && d.Status != DefectStatus.Resolved && d.Status != DefectStatus.Closed)
                        .ToListAsync();

                    var activeQuarantineRolls = await _db.Quarantines
                        .Where(q => q.DefectReportId != id && q.Status == QuarantineStatus.Active)
                        .Select(q => q.InventoryRollId.ToUpper())
                        .ToListAsync();
                    var activeQuarantineSet = activeQuarantineRolls.ToHashSet(StringComparer.OrdinalIgnoreCase);

                    var conflictingRolls = new List<string>();
                    foreach (var rollId in newRolls)
                    {
                        var cleanId = rollId.Trim().ToUpperInvariant();
                        if (activeQuarantineSet.Contains(cleanId))
                        {
                            conflictingRolls.Add(rollId);
                            continue;
                        }

                        foreach (var otherReport in otherActiveReports)
                        {
                            var existingRolls = DeserializeInventory(otherReport.AffectedInventoryJson);
                            if (existingRolls.Any(r => r.Trim().Equals(cleanId, StringComparison.OrdinalIgnoreCase)))
                            {
                                conflictingRolls.Add(rollId);
                                break;
                            }
                        }
                    }

                    if (conflictingRolls.Count > 0)
                    {
                        var rollListStr = string.Join(", ", conflictingRolls.Distinct());
                        throw new AuthException(
                            $"Inventory roll(s) [{rollListStr}] already have an active defect report or quarantine. A defect report cannot be assigned to these rolls until the existing report is resolved or deleted.",
                            HttpStatusCode.Conflict);
                    }
                }

                report.AffectedInventoryJson = JsonSerializer.Serialize(newRolls);
            }

            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                SkuCode = report.SkuCode,
                BatchId = report.BatchId,
                ReportedByUserId = report.ReportedByUserId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                AffectedInventory = DeserializeInventory(report.AffectedInventoryJson),
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<bool> DeleteAsync(Guid id)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return false;

            if (await _db.Quarantines.AnyAsync(q => q.DefectReportId == id && q.Status == QuarantineStatus.Active))
            {
                throw new AuthException("Cannot delete defect report while items are actively held in quarantine. Please release the quarantine hold first.", HttpStatusCode.Conflict);
            }

            var historicalQuarantines = await _db.Quarantines.Where(q => q.DefectReportId == id).ToListAsync();
            if (historicalQuarantines.Count > 0)
            {
                _db.Quarantines.RemoveRange(historicalQuarantines);
            }

            _db.DefectReports.Remove(report);
            await _db.SaveChangesAsync();
            return true;
        }

        private static void ValidateEnums(ProductType? productType, DefectSeverity severity, DefectStatus status)
        {
            if (productType.HasValue && !Enum.IsDefined(productType.Value)) throw new AuthException("Invalid product type.");
            if (!Enum.IsDefined(severity)) throw new AuthException("Invalid defect severity.");
            if (!Enum.IsDefined(status)) throw new AuthException("Invalid defect status.");
        }

        private async Task<(string BatchId, ProductType ProductType)> ResolveInventoryContextAsync(
            string skuCode, string? requestedBatch = null, List<string>? affectedInventory = null)
        {
            var cleanSku = skuCode.Trim().ToUpperInvariant();
            var productType = await ResolveProductTypeForSkuAsync(cleanSku);
            var ids = (affectedInventory ?? new()).Where(id => !string.IsNullOrWhiteSpace(id))
                .Select(id => id.Trim().ToUpperInvariant()).Distinct().ToList();
            if (ids.Count > 0)
            {
                var rolls = await _db.StockRolls.Include(r => r.RawMaterial)
                    .Where(r => ids.Contains(r.RollIdentifier.ToUpper())).ToListAsync();
                if (rolls.Count != ids.Count || rolls.Any(r => r.RawMaterial!.SkuCode != cleanSku))
                    throw new AuthException("Select physical roll identifiers belonging to this SKU.");
                var batches = rolls.Select(r => r.BatchId).Where(batch => !string.IsNullOrWhiteSpace(batch))
                    .Select(batch => batch!).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(batch => batch).ToList();
                if (batches.Count == 0)
                    throw new AuthException("Selected rolls must have known batches. Reconcile missing batches first.");
                var resolvedBatch = batches.Count == 1 ? batches[0] : $"MULTI-{cleanSku}";
                if (!string.IsNullOrWhiteSpace(requestedBatch) &&
                    !requestedBatch.Trim().Equals(resolvedBatch, StringComparison.OrdinalIgnoreCase))
                    throw new AuthException("The selected rolls do not belong to the requested batch.");
                return (resolvedBatch, productType);
            }
            if (!string.IsNullOrWhiteSpace(requestedBatch))
                return await ResolveLegacyBatchContextAsync(requestedBatch, productType);

            // A defect can be recorded as soon as the material/SKU is known.
            // A batch or a QR roll can be associated later by the quality
            // team, so submitting the report never depends on an empty roll
            // register.
            return ($"SKU-{cleanSku}-{Guid.NewGuid():N}", productType);
        }

        private async Task<ProductType> ResolveProductTypeForSkuAsync(string skuCode)
        {
            var material = await _db.RawMaterials
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.SkuCode == skuCode);
            if (material == null)
            {
                throw new AuthException("The selected SKU is not in the inventory catalogue.", HttpStatusCode.NotFound);
            }

            var enumName = new string((material.Category ?? string.Empty)
                .Where(char.IsLetterOrDigit)
                .ToArray());
            if (!Enum.TryParse<ProductType>(enumName, true, out var productType))
            {
                throw new AuthException("The selected SKU has an unsupported packaging type.");
            }

            return productType;
        }

        private async Task<(string BatchId, ProductType ProductType)> ResolveLegacyBatchContextAsync(
            string batchId,
            ProductType? productType)
        {
            var batch = await _db.Batches.FirstOrDefaultAsync(item => item.Id == batchId.Trim());
            if (batch == null) throw new AuthException("Batch was not found.", HttpStatusCode.NotFound);
            if (productType.HasValue && batch.ProductType != productType.Value)
            {
                throw new AuthException("Product type does not match the selected batch.");
            }
            return (batch.Id, batch.ProductType);
        }

        private static List<string> DeserializeInventory(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return new List<string>();

            try
            {
                return JsonSerializer.Deserialize<List<string>>(value) ?? new List<string>();
            }
            catch (JsonException)
            {
                return new List<string>();
            }
        }
    }
}
