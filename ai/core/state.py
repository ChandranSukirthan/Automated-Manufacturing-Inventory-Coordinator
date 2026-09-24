from enum import Enum
from typing import TypedDict, Optional, List, Dict, Any


class WorkflowStatus(str, Enum):
    Running = "Running"
    Completed = "Completed"
    Failed = "Failed"
    WaitingForApproval = "WaitingForApproval"


class ApprovalStatus(str, Enum):
    Pending = "Pending"
    Approved = "Approved"
    Rejected = "Rejected"


class AgentState(TypedDict, total=False):
    """
    State shared across all nodes in the LangGraph workflow.
    Note: Hidden chain-of-thought is strictly omitted to respect audit requirements.
    """
    workflow_id: str
    objective: str
    data_extraction_request: Dict[str, str]
    plan: List[str]
    current_agent: str
    status: WorkflowStatus
    approval_status: ApprovalStatus
    completed_steps: List[str]
    tool_results: Dict[str, Any]
    inventory_data: Dict[str, Any]
    production_data: Dict[str, Any]
    purchasing_data: Dict[str, Any]
    validation_results: Dict[str, Any]
    final_outcome: Optional[str]
    errors: List[str]
    requires_approval: bool

