using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class MachineDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public MachineStatus Status { get; set; }
        public double UptimeHours { get; set; }
        public double MaintenanceIntervalHours { get; set; }
        public string Location { get; set; } = string.Empty;
        public bool IsMaintenanceDue { get; set; }
        public double RemainingHours { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}

