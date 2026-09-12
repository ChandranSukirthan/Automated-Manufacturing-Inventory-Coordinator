using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Production;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Models.Production;

namespace ManufacturingCoordinator.Api.Services
{
    public class MaintenanceService : IMaintenanceService
    {
        private readonly ApplicationDbContext _db;

        public MaintenanceService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<List<MaintenanceLogDto>> GetByMachineIdAsync(Guid machineId)
        {
            var machine = await _db.Machines.FindAsync(machineId);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            var logs = await _db.MaintenanceLogs
                .Include(ml => ml.Machine)
                .Where(ml => ml.MachineId == machineId)
                .OrderByDescending(ml => ml.PerformedAt)
                .ToListAsync();

            return logs.Select(MapToDto).ToList();
        }

        public async Task<MaintenanceLogDto> CreateAsync(CreateMaintenanceLogDto dto)
        {
            var machine = await _db.Machines.FindAsync(dto.MachineId);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            var log = new MaintenanceLog
            {
                MachineId = dto.MachineId,
                Description = dto.Description.Trim(),
                PerformedBy = dto.PerformedBy.Trim(),
                Type = dto.Type,
                PerformedAt = dto.PerformedAt ?? DateTime.UtcNow
            };

            _db.MaintenanceLogs.Add(log);
            await _db.SaveChangesAsync();

            // Reload with Machine navigation property
            await _db.Entry(log).Reference(ml => ml.Machine).LoadAsync();

            return MapToDto(log);
        }

        public async Task<MaintenanceLogDto> UpdateAsync(Guid id, UpdateMaintenanceLogDto dto)
        {
            var log = await _db.MaintenanceLogs
                .Include(ml => ml.Machine)
                .FirstOrDefaultAsync(ml => ml.Id == id);

            if (log == null)
                throw new AuthException("Maintenance log not found.", HttpStatusCode.NotFound);

            log.Description = dto.Description.Trim();
            log.PerformedBy = dto.PerformedBy.Trim();
            log.Type = dto.Type;
            if (dto.PerformedAt.HasValue)
                log.PerformedAt = dto.PerformedAt.Value;

            await _db.SaveChangesAsync();

            return MapToDto(log);
        }

        private static MaintenanceLogDto MapToDto(MaintenanceLog log)
        {
            return new MaintenanceLogDto
            {
                Id = log.Id,
                MachineId = log.MachineId,
                MachineName = log.Machine?.Name ?? string.Empty,
                Description = log.Description,
                PerformedBy = log.PerformedBy,
                PerformedAt = log.PerformedAt,
                Type = log.Type,
                CreatedAt = log.CreatedAt
            };
        }
    }
}
