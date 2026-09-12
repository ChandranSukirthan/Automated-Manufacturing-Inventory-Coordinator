using System;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class AuditLogDto
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string Entity { get; set; } = string.Empty;
        public string EntityId { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
        public bool Success { get; set; }
        public string? IpAddress { get; set; }
    }
}

