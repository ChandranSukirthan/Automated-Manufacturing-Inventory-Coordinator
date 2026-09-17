using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Production;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IMachineService
    {
        Task<List<MachineDto>> GetAllAsync();
        Task<MachineDto> GetByIdAsync(Guid id);
        Task<MachineDto> CreateAsync(CreateMachineDto dto);
        Task<MachineDto> UpdateAsync(Guid id, UpdateMachineDto dto);
        Task DeleteAsync(Guid id);
        Task<MaintenanceCalculationDto> CalculateMaintenanceAsync(Guid machineId);
    }
}
