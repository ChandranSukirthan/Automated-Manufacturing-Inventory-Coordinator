using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Helpers;
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
                    ReportedByUserId = d.ReportedByUserId,
                    ProductType = d.ProductType,
                    Severity = d.Severity,
                    Description = d.Description,
                    AffectedInventory = DeserializeInventory(d.AffectedInventoryJson),
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
                ReportedByUserId = defect.ReportedByUserId,
                ProductType = defect.ProductType,
                Severity = defect.Severity,
                Description = defect.Description,
                AffectedInventory = DeserializeInventory(defect.AffectedInventoryJson),
                CreatedAt = defect.CreatedAt,
                Status = defect.Status
            };
        }

        public async Task<DefectReportDto> CreateAsync(CreateDefectReportDto dto, Guid? reportedByUserId)
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

            ValidateEnums(dto.ProductType, dto.Severity, dto.Status);

            var batchId = dto.BatchId.Trim();
            var batch = await _db.Batches.FirstOrDefaultAsync(b => b.Id == batchId);
            if (batch == null)
            {
                throw new AuthException("Batch was not found.", HttpStatusCode.NotFound);
            }

            if (batch.ProductType != dto.ProductType)
            {
                throw new AuthException("Product type does not match the selected batch.");
            }

            var existingDefect = await _db.DefectReports.AnyAsync(d => d.BatchId == batchId);
            if (existingDefect)
            {
                throw new AuthException("A defect has already been created for this batch.", HttpStatusCode.Conflict);
            }

            var report = new DefectReport
            {
                BatchId = batchId,
                ReportedByUserId = reportedByUserId,
                ProductType = dto.ProductType,
                Severity = dto.Severity,
                Description = dto.Description.Trim(),
                AffectedInventoryJson = JsonSerializer.Serialize(dto.AffectedInventory ?? new List<string>()),
                Status = dto.Status,
                CreatedAt = DateTime.UtcNow
            };

            _db.DefectReports.Add(report);
            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                BatchId = report.BatchId,
                ReportedByUserId = report.ReportedByUserId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                AffectedInventory = DeserializeInventory(report.AffectedInventoryJson),
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<DefectReportDto?> UpdateAsync(Guid id, UpdateDefectReportDto dto)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return null;

            var batchId = string.IsNullOrWhiteSpace(dto.BatchId) ? report.BatchId : dto.BatchId.Trim();
            var productType = dto.ProductType ?? report.ProductType;
            var severity = dto.Severity ?? report.Severity;
            var status = dto.Status ?? report.Status;

            ValidateEnums(productType, severity, status);

            var batch = await _db.Batches.FirstOrDefaultAsync(b => b.Id == batchId);
            if (batch == null)
            {
                throw new AuthException("Batch was not found.", HttpStatusCode.NotFound);
            }

            if (batch.ProductType != productType)
            {
                throw new AuthException("Product type does not match the selected batch.");
            }

            var anotherDefectWithSameBatch = await _db.DefectReports.AnyAsync(d => d.BatchId == batchId && d.Id != id);
            if (anotherDefectWithSameBatch)
            {
                throw new AuthException("A defect has already been created for this batch.", HttpStatusCode.Conflict);
            }

            report.BatchId = batchId;
            report.ProductType = productType;
            report.Severity = severity;

            if (!string.IsNullOrWhiteSpace(dto.Description))
            {
                report.Description = dto.Description.Trim();
            }

            if (string.IsNullOrWhiteSpace(report.Description))
            {
                throw new AuthException("Description is required.");
            }

            report.Status = status;
            if (dto.AffectedInventory != null)
            {
                report.AffectedInventoryJson = JsonSerializer.Serialize(dto.AffectedInventory);
            }

            await _db.SaveChangesAsync();

            return new DefectReportDto
            {
                Id = report.Id,
                BatchId = report.BatchId,
                ReportedByUserId = report.ReportedByUserId,
                ProductType = report.ProductType,
                Severity = report.Severity,
                Description = report.Description,
                AffectedInventory = DeserializeInventory(report.AffectedInventoryJson),
                CreatedAt = report.CreatedAt,
                Status = report.Status
            };
        }

        public async Task<bool> DeleteAsync(Guid id)
        {
            var report = await _db.DefectReports.FirstOrDefaultAsync(d => d.Id == id);
            if (report == null) return false;

            if (await _db.Quarantines.AnyAsync(q => q.DefectReportId == id))
            {
                throw new AuthException("A defect with quarantine history cannot be deleted.", HttpStatusCode.Conflict);
            }

            _db.DefectReports.Remove(report);
            await _db.SaveChangesAsync();
            return true;
        }

        private static void ValidateEnums(ProductType productType, DefectSeverity severity, DefectStatus status)
        {
            if (!Enum.IsDefined(productType)) throw new AuthException("Invalid product type.");
            if (!Enum.IsDefined(severity)) throw new AuthException("Invalid defect severity.");
            if (!Enum.IsDefined(status)) throw new AuthException("Invalid defect status.");
        }

        private static List<string> DeserializeInventory(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return new List<string>();

            try
            {
                return JsonSerializer.Deserialize<List<string>>(value) ?? new List<string>();
            }
            catch (JsonException)
            {
                return new List<string>();
            }
        }
    }
}
