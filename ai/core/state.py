from enum import StrEnum
from typing import Any, TypedDict


class WorkflowStatus(StrEnum):
    RUNNING = "Running"
    COMPLETED = "Completed"
    FAILED = "Failed"
    WAITING_FOR_APPROVAL = "WaitingForApproval"


class ApprovalStatus(StrEnum):
    PENDING = "Pending"
    APPROVED = "Approved"
    REJECTED = "Rejected"


class AgentState(TypedDict, total=False):
    workflow_id: str
    objective: str
    current_agent: str
    status: WorkflowStatus
    approval_status: ApprovalStatus
    inventory_data: dict[str, Any]
    production_data: dict[str, Any]
    purchasing_data: dict[str, Any]
    quality_data: dict[str, Any]
    tool_results: dict[str, Any]
    final_outcome: str | None
    errors: list[str]
    requires_approval: bool
