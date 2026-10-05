namespace backend.Dtos
{
    public class AgentStateUpdateDto
    {
        public string WorkflowId { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }
}

