using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class CreateMachineDto
    {
        [Required, MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public MachineStatus Status { get; set; } = MachineStatus.Operational;

        [Range(0, double.MaxValue)]
        public double UptimeHours { get; set; } = 0;

        [Required, Range(1, double.MaxValue, ErrorMessage = "Maintenance interval must be greater than 0.")]
        public double MaintenanceIntervalHours { get; set; } = 500;

        [MaxLength(300)]
        public string Location { get; set; } = string.Empty;
    }
}

