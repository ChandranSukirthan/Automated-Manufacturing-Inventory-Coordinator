using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
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

        public async Task<QuarantineDto> QuarantineDefectAsync(Guid defectId, CreateQuarantineDto dto)
        {
            var defect = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == defectId);
            if (defect == null)
            {
                throw new AuthException("Defect report was not found.", HttpStatusCode.NotFound);
            }

            var inventoryRollId = string.IsNullOrWhiteSpace(dto.InventoryRollId)
                ? defect.BatchId.Trim()
                : dto.InventoryRollId.Trim();

            if (string.IsNullOrWhiteSpace(inventoryRollId))
            {
                throw new AuthException("An inventory roll identifier is required.");
            }

            if (string.IsNullOrWhiteSpace(dto.Reason))
            {
                throw new AuthException("A quarantine reason is required.");
            }

            var alreadyQuarantined = await _db.Quarantines.AnyAsync(q =>
                q.InventoryRollId == inventoryRollId && q.Status == QuarantineStatus.Active);
            if (alreadyQuarantined)
            {
                throw new AuthException("This inventory is already quarantined.", HttpStatusCode.Conflict);
            }

            var quarantine = new Quarantine
            {
                DefectReportId = defect.Id,
                InventoryRollId = inventoryRollId,
                Reason = dto.Reason.Trim(),
                Status = QuarantineStatus.Active,
                CreatedAt = DateTime.UtcNow
            };

            _db.Quarantines.Add(quarantine);
            await _db.SaveChangesAsync();

            quarantine.DefectReport = defect;
            return ToDto(quarantine);
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

            quarantine.Status = QuarantineStatus.Released;
            quarantine.ReleasedAt = DateTime.UtcNow;
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
    }
}
