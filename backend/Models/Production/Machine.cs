using System;
using System.Collections.Generic;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Production
{
    public class Machine
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public string Name { get; set; } = string.Empty;
        public MachineStatus Status { get; set; } = MachineStatus.Operational;
        public double UptimeHours { get; set; } = 0;
        public double MaintenanceIntervalHours { get; set; } = 500;
        public string Location { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<MaintenanceLog> MaintenanceLogs { get; set; } = new List<MaintenanceLog>();
    }
}

