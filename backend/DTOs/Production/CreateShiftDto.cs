using System;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class CreateShiftDto
    {
        [Required, MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required, Range(1, int.MaxValue, ErrorMessage = "Production target must be greater than 0.")]
        public int ProductionTarget { get; set; }

        [Required, Range(0, int.MaxValue)]
        public int AvailableMaterial { get; set; }

        [Range(0, int.MaxValue)]
        public int ActualOutput { get; set; } = 0;

        public ShiftStatus Status { get; set; } = ShiftStatus.Planned;

        [Required]
        public DateTime StartTime { get; set; }

        [Required]
        public DateTime EndTime { get; set; }
    }
}

