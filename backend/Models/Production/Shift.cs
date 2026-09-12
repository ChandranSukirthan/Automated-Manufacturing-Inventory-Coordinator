using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Production
{
    public class Shift
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public string Name { get; set; } = string.Empty;
        public int ProductionTarget { get; set; } = 0;
        public int AvailableMaterial { get; set; } = 0;
        public int AdjustedOutput { get; set; } = 0;
        public int ActualOutput { get; set; } = 0;
        public ShiftStatus Status { get; set; } = ShiftStatus.Planned;
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}

