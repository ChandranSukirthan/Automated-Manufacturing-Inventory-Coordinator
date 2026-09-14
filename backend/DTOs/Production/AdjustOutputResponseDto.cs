namespace ManufacturingCoordinator.Api.DTOs.Production
{
    public class AdjustOutputResponseDto
    {
        public int ProductionTarget { get; set; }
        public int AvailableMaterial { get; set; }
        public int AdjustedOutput { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}

