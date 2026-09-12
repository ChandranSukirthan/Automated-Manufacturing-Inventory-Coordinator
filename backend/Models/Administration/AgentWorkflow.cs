using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Administration
{
    public class AgentWorkflow
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public string WorkflowId { get; set; } = string.Empty; // e.g. "WF-1001"
        public string Objective { get; set; } = string.Empty;
        public string CurrentAgent { get; set; } = string.Empty;
        public WorkflowStatus Status { get; set; } = WorkflowStatus.Running;
        public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.Pending;
        public DateTime StartedAt { get; set; } = DateTime.UtcNow;
        public DateTime? CompletedAt { get; set; }
        public string? FinalOutcome { get; set; }
    }
}

