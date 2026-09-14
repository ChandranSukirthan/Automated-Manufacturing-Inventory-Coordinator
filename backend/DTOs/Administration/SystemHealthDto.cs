using System.Collections.Generic;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class SystemHealthDto
    {
        public string OverallStatus { get; set; } = "ONLINE"; // ONLINE, OFFLINE, DEGRADED
        public List<ServiceHealthDto> Services { get; set; } = new List<ServiceHealthDto>();
    }

    public class ServiceHealthDto
    {
        public string Name { get; set; } = string.Empty;
        public string Status { get; set; } = "ONLINE"; // ONLINE, OFFLINE, DEGRADED
        public string? Message { get; set; }
    }
}

