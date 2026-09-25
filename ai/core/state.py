from enum import StrEnum
from typing import Any, TypedDict


class WorkflowStatus(StrEnum):
    RUNNING = "Running"
    COMPLETED = "Completed"
    FAILED = "Failed"
    WAITING_FOR_APPROVAL = "WaitingForApproval"
    Running = "Running"
    Completed = "Completed"
    Failed = "Failed"
    WaitingForApproval = "WaitingForApproval"


class ApprovalStatus(StrEnum):
    PENDING = "Pending"
    APPROVED = "Approved"
    REJECTED = "Rejected"
    Pending = "Pending"
    Approved = "Approved"
    Rejected = "Rejected"


class AgentState(TypedDict, total=False):
    workflow_id: str
    objective: str
    plan: list[str]
    current_agent: str
    status: WorkflowStatus
    approval_status: ApprovalStatus
    inventory_data: dict[str, Any]
    production_data: dict[str, Any]
    purchasing_data: dict[str, Any]
    quality_data: dict[str, Any]
    validation_results: dict[str, Any]
    completed_steps: list[str]
    tool_results: dict[str, Any]
    tool_call_log: list[dict[str, Any]]
    procurement_requirement: dict[str, Any]
    final_outcome: str | None
    errors: list[str]
    requires_approval: bool
    approved_by: str | None
    created_at: str | None
    updated_at: str | None
