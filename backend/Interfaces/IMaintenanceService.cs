using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Production;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IMaintenanceService
    {
        Task<List<MaintenanceLogDto>> GetByMachineIdAsync(Guid machineId);
        Task<MaintenanceLogDto> CreateAsync(CreateMaintenanceLogDto dto);
        Task<MaintenanceLogDto> UpdateAsync(Guid id, UpdateMaintenanceLogDto dto);
    }
}
