using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Quality;

namespace ManufacturingCoordinator.Api.Services
{
    public class DefectReportService : IDefectReportService
    {
        private readonly ApplicationDbContext _db;

        public DefectReportService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task<IEnumerable<DefectReportDto>> GetAllAsync()
        {
            return await _db.DefectReports
                .OrderByDescending(d => d.CreatedAt)
                .Select(d => new DefectReportDto
                {
                    Id = d.Id,
                    BatchId = d.BatchId,
                    ProductType = d.ProductType,
                    Severity = d.Severity,
                    Description = d.Description,
                    CreatedAt = d.CreatedAt,
                    Status = d.Status
                })
                .ToListAsync();
        }

        public async Task<DefectReportDto?> GetByIdAsync(Guid id)
        {
            var defect = await _db.DefectReports
                .FirstOrDefaultAsync(d => d.Id == id);

            if (defect == null) return null;

            return new DefectReportDto
            {
                Id = defect.Id,
                BatchId = defect.BatchId,
                ProductType = defect.ProductType,
                Severity = defect.Severity,
                Description = defect.Description,
                CreatedAt = defect.CreatedAt,
                Status = defect.Status
            };
        }

        public async Task<DefectReportDto> CreateAsync(CreateDefectReportDto dto)
        {
            if (dto == null)
            {
                throw new ArgumentNullException(nameof(dto));
            }

            if (string.IsNullOrWhiteSpace(dto.BatchId))
            {
                throw new ArgumentException("Batch ID is required.", nameof(dto));
            }

            if (string.IsNullOrWhiteSpace(dto.Description))
            {
                throw new ArgumentException("Description is required.", nameof(dto));
            }

            var report = new DefectReport
            {
                BatchId = dto.BatchId.Trim(),
                ProductType = dto.ProductType,
                Severity = dto.Severity,
                Description = dto.Description.Trim(),
                Status = dto.Status,
                CreatedAt = DateTime.UtcNow
            };

            _db.DefectReports.Add(report);
            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                BatchId = report.BatchId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<DefectReportDto?> UpdateAsync(Guid id, UpdateDefectReportDto dto)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return null;

            if (!string.IsNullOrWhiteSpace(dto.BatchId)) report.BatchId = dto.BatchId.Trim();
            if (dto.ProductType.HasValue) report.ProductType = dto.ProductType.Value;
            if (dto.Severity.HasValue) report.Severity = dto.Severity.Value;
            if (!string.IsNullOrWhiteSpace(dto.Description)) report.Description = dto.Description.Trim();
            if (dto.Status.HasValue) report.Status = dto.Status.Value;

            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                BatchId = report.BatchId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<bool> DeleteAsync(Guid id)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return false;

            _db.DefectReports.Remove(report);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
