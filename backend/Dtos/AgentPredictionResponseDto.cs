namespace backend.Dtos
{
    public class AgentPredictionResponseDto
    {
        public string Status { get; set; }
        public System.Collections.Generic.List<AgentPredictionDto> Predictions { get; set; }
    }

    public class AgentPredictionDto
    {
        public string Sku { get; set; }
        public double RiskScore { get; set; }
        public string RecommendedAction { get; set; }
    }
}

