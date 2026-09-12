using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class MaintenanceLogDto
    {
        public Guid Id { get; set; }
        public Guid MachineId { get; set; }
        public string MachineName { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string PerformedBy { get; set; } = string.Empty;
        public DateTime PerformedAt { get; set; }
        public MaintenanceType Type { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

