using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Quality;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IDefectReportService
    {
        Task<IEnumerable<DefectReportDto>> GetAllAsync();
        Task<DefectReportDto?> GetByIdAsync(Guid id);
        Task<DefectReportDto> CreateAsync(CreateDefectReportDto dto);
        Task<DefectReportDto?> UpdateAsync(Guid id, UpdateDefectReportDto dto);
        Task<bool> DeleteAsync(Guid id);
    }
}
