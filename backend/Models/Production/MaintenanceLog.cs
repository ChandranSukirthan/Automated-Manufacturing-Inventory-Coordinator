using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Production
{
    public class MaintenanceLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid MachineId { get; set; }
        public Machine? Machine { get; set; }
        public string Description { get; set; } = string.Empty;
        public string PerformedBy { get; set; } = string.Empty;
        public DateTime PerformedAt { get; set; } = DateTime.UtcNow;
        public MaintenanceType Type { get; set; } = MaintenanceType.Scheduled;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}

