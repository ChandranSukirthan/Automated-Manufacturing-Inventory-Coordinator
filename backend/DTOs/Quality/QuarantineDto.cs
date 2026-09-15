using System;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Quality
{
    public class CreateQuarantineDto
    {
        public string? InventoryRollId { get; set; }

        [Required]
        public string Reason { get; set; } = string.Empty;
    }

    public class QuarantineDto
    {
        public Guid Id { get; set; }
        public Guid DefectReportId { get; set; }
        public string InventoryRollId { get; set; } = string.Empty;
        public string BatchId { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public QuarantineStatus Status { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ReleasedAt { get; set; }
    }
}
