using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class UpdateMachineDto
    {
        [Required, MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public MachineStatus Status { get; set; }

        [Range(0, double.MaxValue)]
        public double UptimeHours { get; set; }

        [Required, Range(1, double.MaxValue, ErrorMessage = "Maintenance interval must be greater than 0.")]
        public double MaintenanceIntervalHours { get; set; }

        [MaxLength(300)]
        public string Location { get; set; } = string.Empty;
    }
}

