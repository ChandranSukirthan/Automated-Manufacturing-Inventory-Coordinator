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
            // Enforce production adjustment business rule:
            // If available material < production target, adjusted output = available material
            // Otherwise, adjusted output = production target
            var adjustedOutput = dto.AvailableMaterial < dto.ProductionTarget
                ? dto.AvailableMaterial
                : dto.ProductionTarget;

            var shift = new Shift
            {
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

            // Re-enforce production adjustment business rule on update
            var adjustedOutput = dto.AvailableMaterial < dto.ProductionTarget
                ? dto.AvailableMaterial
                : dto.ProductionTarget;

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

        public async Task<AdjustOutputResponseDto> AdjustOutputAsync(Guid shiftId)
        {
            var shift = await _db.Shifts.FindAsync(shiftId);
            if (shift == null)
                throw new AuthException("Shift not found.", HttpStatusCode.NotFound);

            // Business rule enforcement:
            // Target = 10,000 units, Available = 6,000 → Adjusted = 6,000
            var adjustedOutput = shift.AvailableMaterial < shift.ProductionTarget
                ? shift.AvailableMaterial
                : shift.ProductionTarget;

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

        private static ShiftDto MapToDto(Shift shift)
        {
            return new ShiftDto
            {
                Id = shift.Id,
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
