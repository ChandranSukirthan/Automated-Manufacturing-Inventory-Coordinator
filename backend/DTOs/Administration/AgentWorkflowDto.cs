using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class AgentWorkflowDto
    {
        public Guid Id { get; set; }
        public string WorkflowId { get; set; } = string.Empty;
        public string Objective { get; set; } = string.Empty;
        public string CurrentAgent { get; set; } = string.Empty;
        public WorkflowStatus Status { get; set; }
        public ApprovalStatus ApprovalStatus { get; set; }
        public DateTime StartedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
        public string? FinalOutcome { get; set; }
    }
}

