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
    public class ShiftService : IShiftService
    {
        private readonly ApplicationDbContext _db;

        public ShiftService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<List<ShiftDto>> GetAllAsync()
        {
            var shifts = await _db.Shifts
                .OrderByDescending(s => s.StartTime)
                .ToListAsync();

            return shifts.Select(MapToDto).ToList();
        }

        public async Task<ShiftDto> CreateAsync(CreateShiftDto dto)
        {
            await ValidateContext(dto.MaterialSku, dto.MachineId, dto.MaterialPerUnit, dto.StartTime, dto.EndTime);
            // Enforce production adjustment business rule:
            // If available material < production target, adjusted output = available material
            // Otherwise, adjusted output = production target
            var adjustedOutput = Adjusted(dto.ProductionTarget, dto.AvailableMaterial, dto.MaterialPerUnit);

            var shift = new Shift
            {
                MaterialSku = dto.MaterialSku, MachineId = dto.MachineId, MaterialPerUnit = dto.MaterialPerUnit,
                Name = dto.Name.Trim(),
                ProductionTarget = dto.ProductionTarget,
                AvailableMaterial = dto.AvailableMaterial,
                AdjustedOutput = adjustedOutput,
                ActualOutput = dto.ActualOutput,
                Status = dto.Status,
                StartTime = dto.StartTime,
                EndTime = dto.EndTime
            };

            _db.Shifts.Add(shift);
            await _db.SaveChangesAsync();

            return MapToDto(shift);
        }

        public async Task<ShiftDto> UpdateAsync(Guid id, UpdateShiftDto dto)
        {
            var shift = await _db.Shifts.FindAsync(id);
            if (shift == null)
                throw new AuthException("Shift not found.", HttpStatusCode.NotFound);

            await ValidateContext(dto.MaterialSku, dto.MachineId, dto.MaterialPerUnit, dto.StartTime, dto.EndTime, id);
            // Re-enforce production adjustment business rule on update
            var adjustedOutput = Adjusted(dto.ProductionTarget, dto.AvailableMaterial, dto.MaterialPerUnit);

            shift.MaterialSku = dto.MaterialSku; shift.MachineId = dto.MachineId; shift.MaterialPerUnit = dto.MaterialPerUnit;
            shift.Name = dto.Name.Trim();
            shift.ProductionTarget = dto.ProductionTarget;
            shift.AvailableMaterial = dto.AvailableMaterial;
            shift.AdjustedOutput = adjustedOutput;
            shift.ActualOutput = dto.ActualOutput;
            shift.Status = dto.Status;
            shift.StartTime = dto.StartTime;
            shift.EndTime = dto.EndTime;
            shift.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            return MapToDto(shift);
        }

        public async Task DeleteAsync(Guid id)
        {
            var shift = await _db.Shifts.FindAsync(id);
            if (shift == null)
                throw new AuthException("Shift not found.", HttpStatusCode.NotFound);

            _db.Shifts.Remove(shift);
            await _db.SaveChangesAsync();
        }

        public async Task<AdjustOutputResponseDto> AdjustOutputAsync(Guid shiftId)
        {
            var shift = await _db.Shifts.FindAsync(shiftId);
            if (shift == null)
                throw new AuthException("Shift not found.", HttpStatusCode.NotFound);

            // Business rule enforcement:
            // Target = 10,000 units, Available = 6,000 → Adjusted = 6,000
            var adjustedOutput = Adjusted(shift.ProductionTarget, shift.AvailableMaterial, shift.MaterialPerUnit);

            shift.AdjustedOutput = adjustedOutput;
            shift.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            var message = shift.AvailableMaterial < shift.ProductionTarget
                ? $"Output adjusted to {adjustedOutput} due to material constraint (available: {shift.AvailableMaterial}, target: {shift.ProductionTarget})."
                : $"Output set to production target: {adjustedOutput}.";

            return new AdjustOutputResponseDto
            {
                ProductionTarget = shift.ProductionTarget,
                AvailableMaterial = shift.AvailableMaterial,
                AdjustedOutput = adjustedOutput,
                Message = message
            };
        }

        private static int Adjusted(int target, int available, decimal? conversion) =>
            conversion.HasValue ? (int)Math.Min(target, decimal.Floor(available / conversion.Value)) : Math.Min(target, available);

        private async Task ValidateContext(string? sku, Guid? machineId, decimal? conversion, DateTime start, DateTime end, Guid? currentShiftId = null)
        {
            if (end <= start) throw new AuthException("Shift end must be after its start.", HttpStatusCode.BadRequest);
            if (conversion.HasValue && (conversion <= 0 || string.IsNullOrWhiteSpace(sku)))
                throw new AuthException("A positive material-per-output value requires a catalogue material.", HttpStatusCode.BadRequest);
            if (!string.IsNullOrWhiteSpace(sku) && (!conversion.HasValue || !await _db.RawMaterials.AnyAsync(m => m.SkuCode == sku)))
                throw new AuthException("Select an existing material and its material-per-output conversion.", HttpStatusCode.BadRequest);
            if (machineId.HasValue && !await _db.Machines.AnyAsync(m => m.Id == machineId))
                throw new AuthException("The selected machine does not exist.", HttpStatusCode.BadRequest);

            if (machineId.HasValue)
            {
                var hasOverlap = await _db.Shifts
                    .AnyAsync(s => s.MachineId == machineId.Value && (!currentShiftId.HasValue || s.Id != currentShiftId.Value) &&
                                   s.StartTime < end && s.EndTime > start);
                if (hasOverlap)
                {
                    throw new AuthException("Another shift is already scheduled on this machine during this time window.", HttpStatusCode.Conflict);
                }
            }
        }

        private static ShiftDto MapToDto(Shift shift)
        {
            return new ShiftDto
            {
                Id = shift.Id,
                MaterialSku = shift.MaterialSku, MachineId = shift.MachineId, MaterialPerUnit = shift.MaterialPerUnit,
                Name = shift.Name,
                ProductionTarget = shift.ProductionTarget,
                AvailableMaterial = shift.AvailableMaterial,
                AdjustedOutput = shift.AdjustedOutput,
                ActualOutput = shift.ActualOutput,
                Status = shift.Status,
                StartTime = shift.StartTime,
                EndTime = shift.EndTime,
                CreatedAt = shift.CreatedAt,
                UpdatedAt = shift.UpdatedAt
            };
        }
    }
}
