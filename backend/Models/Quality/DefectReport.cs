using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Quality
{
    public class DefectReport
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        // The catalogue SKU reported by the floor worker. This lets a report
        // stand on its own before a production batch or a physical roll has
        // been assigned.
        public string SkuCode { get; set; } = string.Empty;
        public string BatchId { get; set; } = string.Empty;
        public Guid? ReportedByUserId { get; set; }
        public ProductType ProductType { get; set; }
        public DefectSeverity Severity { get; set; }
        public string Description { get; set; } = string.Empty;
        public string AffectedInventoryJson { get; set; } = "[]";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DefectStatus Status { get; set; } = DefectStatus.Open;

        public Models.Authentication.User? ReportedByUser { get; set; }
    }
}
