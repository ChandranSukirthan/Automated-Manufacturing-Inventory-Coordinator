import operator
from typing import TypedDict, Annotated, Sequence, List, Dict, Any, Optional
from langchain_core.messages import BaseMessage


class AgentState(TypedDict, total=False):
    """
    Shared LangGraph State across the multi-agent manufacturing workflow:
    Planner -> Data Extraction -> Purchasing -> Validation -> Human Approval
    """
    # LangGraph message stream with additive reducer
    messages: Annotated[Sequence[BaseMessage], operator.add]
    
    # Workflow metadata
    workflow_id: str
    target_material_id: str
    target_batch: str
    current_agent: str
    
    # Student 1: Inventory & Data Extraction telemetry
    inventory_data: Dict[str, Any]
    history_data: Dict[str, Any]
    burn_rate_data: Dict[str, Any]
    low_stock_data: Dict[str, Any]
    
    # Structured Data Extraction Output
    data_extraction_result: Dict[str, Any]
    inventory_result: Dict[str, Any]
    tool_execution_summary: List[Dict[str, Any]]
    
    # Human approval gate
    requires_human_approval: bool
    human_approval_status: str  # "PENDING", "APPROVED", "REJECTED"
    
    # Workflow auditing
    timestamps: Dict[str, str]
    errors: List[str]
    final_decision: str

