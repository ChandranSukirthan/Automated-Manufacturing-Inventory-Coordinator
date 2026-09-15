namespace ManufacturingCoordinator.Api.DTOs.Quality
{
    public class QualityDashboardSummaryDto
    {
        public int TotalDefects { get; set; }
        public int HighSeverityDefects { get; set; }
        public int ActiveQuarantines { get; set; }
        public int ReleasedQuarantines { get; set; }
    }
}
