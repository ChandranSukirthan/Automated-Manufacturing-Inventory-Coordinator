using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Quality;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IQuarantineService
    {
        Task<IEnumerable<QuarantineDto>> GetAllAsync();
        Task<QuarantineDto?> GetByIdAsync(Guid id);
        Task<QuarantineDto> QuarantineDefectAsync(Guid defectId, CreateQuarantineDto dto);
        Task<QuarantineDto?> ReleaseAsync(Guid id);
    }
}
