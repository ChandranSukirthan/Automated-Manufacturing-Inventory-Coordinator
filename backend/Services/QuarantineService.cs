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
using ManufacturingCoordinator.Models.Inventory;
using ManufacturingCoordinator.Models.Quality;

namespace ManufacturingCoordinator.Api.Services
{
    public class QuarantineService : IQuarantineService
    {
        private readonly ApplicationDbContext _db;

        public QuarantineService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<IEnumerable<QuarantineDto>> GetAllAsync()
        {
            return await _db.Quarantines
                .Include(q => q.DefectReport)
                .OrderByDescending(q => q.CreatedAt)
                .Select(ToDtoExpression())
                .ToListAsync();
        }

        public async Task<QuarantineDto?> GetByIdAsync(Guid id)
        {
            return await _db.Quarantines
                .Include(q => q.DefectReport)
                .Where(q => q.Id == id)
                .Select(ToDtoExpression())
                .FirstOrDefaultAsync();
        }

        public async Task<IReadOnlyList<QuarantineDto>> QuarantineDefectAsync(Guid defectId, CreateQuarantineDto dto)
        {
            var defect = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == defectId);
            if (defect == null)
            {
                throw new AuthException("Defect report was not found.", HttpStatusCode.NotFound);
            }

            if (string.IsNullOrWhiteSpace(dto.Reason))
            {
                throw new AuthException("A quarantine reason is required.");
            }

            var affectedInventory = DeserializeInventory(defect.AffectedInventoryJson)
                .Select(id => id.Trim())
                .Where(id => id.Length > 0)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            var physical = await _db.StockRolls.Include(r => r.RawMaterial)
                .Where(r => affectedInventory.Count > 0 ? affectedInventory.Contains(r.RollIdentifier) :
                    (!string.IsNullOrEmpty(defect.SkuCode) ? r.RawMaterial!.SkuCode == defect.SkuCode : r.BatchId == defect.BatchId))
                .ToListAsync();
            var legacy = await _db.InventoryRolls.Where(r => affectedInventory.Count > 0
                ? affectedInventory.Contains(r.Id) : r.BatchId == defect.BatchId).ToListAsync();
            var targetRollIds = physical.Select(r => r.RollIdentifier).Concat(legacy.Select(r => r.Id)).Distinct().ToList();
            if (targetRollIds.Count == 0 || (affectedInventory.Count > 0 && affectedInventory.Any(id => !targetRollIds.Contains(id))))
                throw new AuthException("The selected physical inventory was not found.", HttpStatusCode.NotFound);
            if (physical.Any(r => !string.IsNullOrEmpty(defect.SkuCode)
                ? r.RawMaterial!.SkuCode != defect.SkuCode : r.BatchId != defect.BatchId) ||
                legacy.Any(r => r.BatchId != defect.BatchId))
                throw new AuthException("Inventory roll does not belong to the defect material or batch.");
            if (physical.Any(r => r.Status != "In Stock" && r.Status != "In Production") ||
                legacy.Any(r => r.Status != InventoryStatus.Available) ||
                await _db.Quarantines.AnyAsync(q => targetRollIds.Contains(q.InventoryRollId) && q.Status == QuarantineStatus.Active))
                throw new AuthException("This inventory is already held or unavailable for quarantine.", HttpStatusCode.Conflict);
            var quarantines = targetRollIds.Select(id => new Quarantine { DefectReportId = defect.Id,
                InventoryRollId = id, Reason = dto.Reason.Trim(), Status = QuarantineStatus.Active,
                CreatedAt = DateTime.UtcNow }).ToList();
            foreach (var roll in physical)
            {
                await ChangeAvailableStockAsync(roll, -roll.CurrentQuantity, "QUARANTINED");
                roll.Status = "Quarantined";
            }
            foreach (var roll in legacy) roll.Status = InventoryStatus.Quarantined;

            _db.Quarantines.AddRange(quarantines);
            await _db.SaveChangesAsync();

            return quarantines.Select(quarantine =>
            {
                quarantine.DefectReport = defect;
                return ToDto(quarantine);
            }).ToList();
        }

        public async Task<QuarantineDto?> ReleaseAsync(Guid id)
        {
            return await ReleaseAsync(id, null, null);
        }

        public async Task<QuarantineDto?> ReleaseAsync(Guid id, string? resolutionNote, string? resolvedBy)
        {
            var quarantine = await _db.Quarantines
                .Include(q => q.DefectReport)
                .FirstOrDefaultAsync(q => q.Id == id);
            if (quarantine == null) return null;

            if (quarantine.Status == QuarantineStatus.Released)
            {
                return ToDto(quarantine);
            }

            var physical = await _db.StockRolls.Include(r => r.RawMaterial)
                .SingleOrDefaultAsync(r => r.RollIdentifier == quarantine.InventoryRollId);
            var legacy = await _db.InventoryRolls.SingleOrDefaultAsync(r => r.Id == quarantine.InventoryRollId);
            if (physical == null && legacy == null)
                throw new AuthException("Inventory roll was not found.", HttpStatusCode.NotFound);
            if ((physical != null && physical.Status != "Quarantined") ||
                (legacy != null && legacy.Status != InventoryStatus.Quarantined))
                throw new AuthException("Inventory roll is not currently quarantined.", HttpStatusCode.Conflict);
            quarantine.Status = QuarantineStatus.Released;
            quarantine.ReleasedAt = DateTime.UtcNow;
            if (physical != null)
            {
                if (!await _db.Quarantines.AnyAsync(q => q.Id != id && q.InventoryRollId == quarantine.InventoryRollId && q.Status == QuarantineStatus.Active))
                {
                    await ChangeAvailableStockAsync(physical, physical.CurrentQuantity, "RELEASED");
                    physical.Status = physical.CurrentQuantity > 0 ? "In Stock" : "Depleted";
                }
            }
            if (legacy != null) legacy.Status = InventoryStatus.Available;

            if (!string.IsNullOrWhiteSpace(resolutionNote))
            {
                quarantine.Reason = $"{quarantine.Reason} | Resolution: {resolutionNote.Trim()}";
            }

            // Sync ONLY with workflows specifically associated with this quarantine / affected inventory / defect
            if (!string.IsNullOrWhiteSpace(resolutionNote))
            {
                var rollId = quarantine.InventoryRollId?.Trim();
                var defectIdStr = quarantine.DefectReportId.ToString();
                var quarantineIdStr = quarantine.Id.ToString();
                var batchId = quarantine.DefectReport?.BatchId?.Trim();

                var allWorkflows = await _db.AgentWorkflows.ToListAsync();
                var matchingWorkflows = allWorkflows.Where(wf =>
                {
                    if (string.IsNullOrWhiteSpace(wf.WorkflowId)) return false;

                    // Match explicitly associated workflows (by Roll ID, Defect ID, Quarantine ID, or specific Batch ID)
                    bool matchRoll = !string.IsNullOrEmpty(rollId) && (
                        HasExactIdentifier(wf.WorkflowId, rollId) ||
                        (wf.Objective != null && HasExactIdentifier(wf.Objective, rollId)) ||
                        (wf.ValidationResults != null && HasExactIdentifier(wf.ValidationResults, rollId))
                    );

                    bool matchDefect = !string.IsNullOrEmpty(defectIdStr) && (
                        wf.WorkflowId.Contains(defectIdStr, StringComparison.OrdinalIgnoreCase) ||
                        (wf.Objective != null && wf.Objective.Contains(defectIdStr, StringComparison.OrdinalIgnoreCase)) ||
                        (wf.ValidationResults != null && wf.ValidationResults.Contains(defectIdStr, StringComparison.OrdinalIgnoreCase))
                    );

                    bool matchQuarantine = (
                        wf.WorkflowId.Contains(quarantineIdStr, StringComparison.OrdinalIgnoreCase) ||
                        (wf.Objective != null && wf.Objective.Contains(quarantineIdStr, StringComparison.OrdinalIgnoreCase)) ||
                        (wf.ValidationResults != null && wf.ValidationResults.Contains(quarantineIdStr, StringComparison.OrdinalIgnoreCase))
                    );

                    bool matchBatch = !string.IsNullOrEmpty(batchId) && (
                        wf.WorkflowId.Equals($"WF-DEFECT-{batchId}", StringComparison.OrdinalIgnoreCase) ||
                        wf.WorkflowId.Equals($"WF-{batchId}", StringComparison.OrdinalIgnoreCase) ||
                        (wf.Objective != null && (
                            wf.Objective.Contains($"Batch {batchId}", StringComparison.OrdinalIgnoreCase) ||
                            wf.Objective.Contains($"batch {batchId}", StringComparison.OrdinalIgnoreCase)
                        ))
                    );

                    return matchRoll || matchDefect || matchQuarantine || matchBatch;
                }).ToList();

                foreach (var wf in matchingWorkflows)
                {
                    if (!string.IsNullOrWhiteSpace(wf.ValidationResults))
                    {
                        try
                        {
                            var dict = JsonSerializer.Deserialize<Dictionary<string, object?>>(wf.ValidationResults);
                            if (dict != null)
                            {
                                dict["manualResolutionStatus"] = "RESOLVED";
                                dict["manualResolutionNote"] = resolutionNote.Trim();
                                dict["resolvedBy"] = resolvedBy ?? "QualityInspector";
                                dict["resolvedAt"] = DateTime.UtcNow.ToString("o");
                                wf.ValidationResults = JsonSerializer.Serialize(dict);
                            }
                        }
                        catch { }
                    }
                }
            }

            await _db.SaveChangesAsync();

            return ToDto(quarantine);
        }

        private static bool HasExactIdentifier(string value, string identifier) =>
            System.Text.RegularExpressions.Regex.IsMatch(value, $@"(?<![A-Za-z0-9_-]){System.Text.RegularExpressions.Regex.Escape(identifier)}(?![A-Za-z0-9_-])", System.Text.RegularExpressions.RegexOptions.IgnoreCase)
            || value.Equals($"WF-DEFECT-{identifier}", StringComparison.OrdinalIgnoreCase);

        private async Task ChangeAvailableStockAsync(backend.Models.InventoryRoll roll, decimal delta, string type)
        {
            var item = await _db.InventoryItems.SingleOrDefaultAsync(i => i.Sku == roll.RawMaterial!.SkuCode);
            if (item == null || item.StockLevel + delta < 0)
                throw new AuthException("Reconcile the physical roll with its SKU balance first.", HttpStatusCode.Conflict);
            var previous = item.StockLevel;
            item.StockLevel = checked(previous + decimal.ToInt32(delta));
            _db.InventoryMovements.Add(new backend.Models.InventoryMovement { RawMaterialId = roll.RawMaterialId,
                RollIdentifier = roll.RollIdentifier, TransactionType = type, Quantity = Math.Abs(delta),
                PreviousStock = previous, NewStock = item.StockLevel, Reason = "QA quarantine state changed" });
        }

        private static System.Linq.Expressions.Expression<Func<Quarantine, QuarantineDto>> ToDtoExpression()
        {
            return q => new QuarantineDto
            {
                Id = q.Id,
                DefectReportId = q.DefectReportId,
                InventoryRollId = q.InventoryRollId,
                BatchId = q.DefectReport.BatchId,
                Reason = q.Reason,
                Status = q.Status,
                CreatedAt = q.CreatedAt,
                ReleasedAt = q.ReleasedAt
            };
        }

        private static QuarantineDto ToDto(Quarantine quarantine)
        {
            return new QuarantineDto
            {
                Id = quarantine.Id,
                DefectReportId = quarantine.DefectReportId,
                InventoryRollId = quarantine.InventoryRollId,
                BatchId = quarantine.DefectReport.BatchId,
                Reason = quarantine.Reason,
                Status = quarantine.Status,
                CreatedAt = quarantine.CreatedAt,
                ReleasedAt = quarantine.ReleasedAt
            };
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
