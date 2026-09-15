using System;

namespace ManufacturingCoordinator.Models.Administration
{
    public class AuditLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string Entity { get; set; } = string.Empty;
        public string EntityId { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public bool Success { get; set; } = true;
        public string? IpAddress { get; set; }

        // NOTE: Never store passwords or secrets in audit logs
    }
}

