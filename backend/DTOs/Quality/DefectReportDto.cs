using System;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Quality
{
    public class DefectReportDto
    {
        public Guid Id { get; set; }
        public string BatchId { get; set; } = string.Empty;
        public ProductType ProductType { get; set; }
        public DefectSeverity Severity { get; set; }
        public string Description { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DefectStatus Status { get; set; }
    }

    public class CreateDefectReportDto
    {
        [Required]
        public string BatchId { get; set; } = string.Empty;

        [Required]
        public ProductType ProductType { get; set; }

        [Required]
        public DefectSeverity Severity { get; set; }

        [Required]
        public string Description { get; set; } = string.Empty;

        [Required]
        public DefectStatus Status { get; set; } = DefectStatus.Open;
    }

    public class UpdateDefectReportDto
    {
        public string? BatchId { get; set; }
        public ProductType? ProductType { get; set; }
        public DefectSeverity? Severity { get; set; }
        public string? Description { get; set; }
        public DefectStatus? Status { get; set; }
    }
}
