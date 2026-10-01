namespace backend.Dtos
{
    public class AgentPredictionResponseDto
    {
        public string Status { get; set; } = string.Empty;
        public System.Collections.Generic.List<AgentPredictionDto> Predictions { get; set; } = new();
    }

    public class AgentPredictionDto
    {
        public string Sku { get; set; } = string.Empty;
        public double RiskScore { get; set; }
        public string RecommendedAction { get; set; } = string.Empty;
    }
}

