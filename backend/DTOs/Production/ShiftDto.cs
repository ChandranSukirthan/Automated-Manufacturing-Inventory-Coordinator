using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class ShiftDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? MaterialSku { get; set; }
        public Guid? MachineId { get; set; }
        public decimal? MaterialPerUnit { get; set; }
        public int ProductionTarget { get; set; }
        public int AvailableMaterial { get; set; }
        public int AdjustedOutput { get; set; }
        public int ActualOutput { get; set; }
        public ShiftStatus Status { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}

