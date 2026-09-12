namespace backend.Dtos
{
    public class AgentStateUpdateDto
    {
        public string WorkflowId { get; set; }
        public string State { get; set; }
        public string Message { get; set; }
    }
}

