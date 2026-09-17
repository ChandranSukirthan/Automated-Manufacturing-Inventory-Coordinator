namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class MaintenanceCalculationDto
    {
        public double UptimeHours { get; set; }
        public double MaintenanceIntervalHours { get; set; }
        public double RemainingHours { get; set; }
        public bool IsMaintenanceDue { get; set; }
    }
}

