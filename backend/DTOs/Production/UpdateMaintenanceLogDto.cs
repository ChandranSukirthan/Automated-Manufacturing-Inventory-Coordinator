using System;
using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class UpdateMaintenanceLogDto
    {
        [Required, MaxLength(1000)]
        public string Description { get; set; } = string.Empty;

        [Required, MaxLength(150)]
        public string PerformedBy { get; set; } = string.Empty;

        [Required]
        public MaintenanceType Type { get; set; }

        public DateTime? PerformedAt { get; set; }
    }
}

