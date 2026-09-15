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
            var targetRollIds = affectedInventory.Count > 0
                ? affectedInventory
                : await _db.InventoryRolls
                    .Where(i => i.BatchId == defect.BatchId && i.Status == InventoryStatus.Available)
                    .Select(i => i.Id)
                    .ToListAsync();

            if (targetRollIds.Count == 0)
            {
                throw new AuthException("Inventory roll was not found.", HttpStatusCode.NotFound);
            }

            var inventoryRolls = await _db.InventoryRolls
                .Where(i => targetRollIds.Contains(i.Id))
                .ToListAsync();

            if (inventoryRolls.Count != targetRollIds.Count || inventoryRolls.Any(i => i.BatchId != defect.BatchId))
            {
                throw new AuthException("Inventory roll does not belong to the defect batch.");
            }

            if (inventoryRolls.Any(i => i.Status != InventoryStatus.Available))
            {
                throw new AuthException("Inventory roll is not available for quarantine.", HttpStatusCode.Conflict);
            }

            var alreadyQuarantined = await _db.Quarantines.AnyAsync(q =>
                targetRollIds.Contains(q.InventoryRollId) && q.Status == QuarantineStatus.Active);
            if (alreadyQuarantined)
            {
                throw new AuthException("This inventory is already quarantined.", HttpStatusCode.Conflict);
            }

            var quarantines = inventoryRolls.Select(inventoryRoll => new Quarantine
            {
                DefectReportId = defect.Id,
                InventoryRollId = inventoryRoll.Id,
                Reason = dto.Reason.Trim(),
                Status = QuarantineStatus.Active,
                CreatedAt = DateTime.UtcNow
            }).ToList();

            foreach (var inventoryRoll in inventoryRolls)
            {
                inventoryRoll.Status = InventoryStatus.Quarantined;
            }

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
            var quarantine = await _db.Quarantines
                .Include(q => q.DefectReport)
                .FirstOrDefaultAsync(q => q.Id == id);
            if (quarantine == null) return null;

            if (quarantine.Status == QuarantineStatus.Released)
            {
                return ToDto(quarantine);
            }

            var inventoryRoll = await _db.InventoryRolls
                .FirstOrDefaultAsync(i => i.Id == quarantine.InventoryRollId);
            if (inventoryRoll == null)
            {
                throw new AuthException("Inventory roll was not found.", HttpStatusCode.NotFound);
            }

            if (inventoryRoll.Status != InventoryStatus.Quarantined)
            {
                throw new AuthException("Inventory roll is not currently quarantined.", HttpStatusCode.Conflict);
            }

            quarantine.Status = QuarantineStatus.Released;
            quarantine.ReleasedAt = DateTime.UtcNow;
            inventoryRoll.Status = InventoryStatus.Available;
            await _db.SaveChangesAsync();

            return ToDto(quarantine);
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
