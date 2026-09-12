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
    public class MachineService : IMachineService
    {
        private readonly ApplicationDbContext _db;

        public MachineService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<List<MachineDto>> GetAllAsync()
        {
            var machines = await _db.Machines
                .OrderBy(m => m.Name)
                .ToListAsync();

            return machines.Select(MapToDto).ToList();
        }

        public async Task<MachineDto> GetByIdAsync(Guid id)
        {
            var machine = await _db.Machines.FindAsync(id);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            return MapToDto(machine);
        }

        public async Task<MachineDto> CreateAsync(CreateMachineDto dto)
        {
            var machine = new Machine
            {
                Name = dto.Name.Trim(),
                Status = dto.Status,
                UptimeHours = dto.UptimeHours,
                MaintenanceIntervalHours = dto.MaintenanceIntervalHours,
                Location = dto.Location.Trim()
            };

            _db.Machines.Add(machine);
            await _db.SaveChangesAsync();

            return MapToDto(machine);
        }

        public async Task<MachineDto> UpdateAsync(Guid id, UpdateMachineDto dto)
        {
            var machine = await _db.Machines.FindAsync(id);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            machine.Name = dto.Name.Trim();
            machine.Status = dto.Status;
            machine.UptimeHours = dto.UptimeHours;
            machine.MaintenanceIntervalHours = dto.MaintenanceIntervalHours;
            machine.Location = dto.Location.Trim();
            machine.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            return MapToDto(machine);
        }

        public async Task DeleteAsync(Guid id)
        {
            var machine = await _db.Machines.FindAsync(id);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            _db.Machines.Remove(machine);
            await _db.SaveChangesAsync();
        }

        public async Task<MaintenanceCalculationDto> CalculateMaintenanceAsync(Guid machineId)
        {
            var machine = await _db.Machines.FindAsync(machineId);
            if (machine == null)
                throw new AuthException("Machine not found.", HttpStatusCode.NotFound);

            var remaining = machine.MaintenanceIntervalHours - machine.UptimeHours;
            if (remaining < 0) remaining = 0;

            return new MaintenanceCalculationDto
            {
                UptimeHours = machine.UptimeHours,
                MaintenanceIntervalHours = machine.MaintenanceIntervalHours,
                RemainingHours = remaining,
                IsMaintenanceDue = remaining <= 0
            };
        }

        private static MachineDto MapToDto(Machine machine)
        {
            var remaining = machine.MaintenanceIntervalHours - machine.UptimeHours;
            if (remaining < 0) remaining = 0;

            return new MachineDto
            {
                Id = machine.Id,
                Name = machine.Name,
                Status = machine.Status,
                UptimeHours = machine.UptimeHours,
                MaintenanceIntervalHours = machine.MaintenanceIntervalHours,
                Location = machine.Location,
                RemainingHours = remaining,
                IsMaintenanceDue = remaining <= 0,
                CreatedAt = machine.CreatedAt,
                UpdatedAt = machine.UpdatedAt
            };
        }
    }
}
