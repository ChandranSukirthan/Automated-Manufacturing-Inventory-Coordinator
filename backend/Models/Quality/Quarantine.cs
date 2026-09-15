using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Quality
{
    public class Quarantine
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid DefectReportId { get; set; }
        public string InventoryRollId { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public QuarantineStatus Status { get; set; } = QuarantineStatus.Active;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? ReleasedAt { get; set; }

        public DefectReport DefectReport { get; set; } = null!;
    }
}
