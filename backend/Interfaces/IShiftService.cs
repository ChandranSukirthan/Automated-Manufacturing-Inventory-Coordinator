using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Production;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IShiftService
    {
        Task<List<ShiftDto>> GetAllAsync();
        Task<ShiftDto> CreateAsync(CreateShiftDto dto);
        Task<ShiftDto> UpdateAsync(Guid id, UpdateShiftDto dto);
        Task<AdjustOutputResponseDto> AdjustOutputAsync(Guid shiftId);
    }
}
