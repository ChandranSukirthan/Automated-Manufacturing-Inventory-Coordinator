using System;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class AgentWorkflowDto
    {
        public Guid Id { get; set; }
        public string WorkflowId { get; set; } = string.Empty;
        public string WorkflowType { get; set; } = "Procurement";
        public Guid? MachineId { get; set; }
        public int? PurchaseOrderId { get; set; }
        public object? Details { get; set; }
        public string Objective { get; set; } = string.Empty;
        public string CurrentAgent { get; set; } = string.Empty;
        public WorkflowStatus Status { get; set; }
        public ApprovalStatus ApprovalStatus { get; set; }
        public DateTime StartedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
        public string? FinalOutcome { get; set; }
    }
}

