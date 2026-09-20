import datetime
import logging
from langchain_core.messages import AIMessage
from ai.state import AgentState

logger = logging.getLogger("amic_agentic_ai.human_approval_node")


def human_approval_node(state: AgentState) -> dict:
    """
    Stage 5: Human Approval Gate Node
    Pauses workflow or sets state to PENDING/APPROVED for managerial decision.
    In live operations, an external webhook/manager endpoint updates this status.
    """
    wf_id = state.get("workflow_id", "WF-UNKNOWN")
    extraction = state.get("data_extraction_result") or {}
    logger.info(f"[Human Approval Gate] Managing approval for workflow {wf_id}")

    # Set status to PENDING for manager review
    # For automated execution / test runs, records status as PENDING or simulated APPROVAL
    status = state.get("human_approval_status", "PENDING")
    
    decision_text = (
        f"Workflow {wf_id} routed to Supply Chain Manager. "
        f"Reason: Low stock detected for {extraction.get('materialId', 'Material')} "
        f"({extraction.get('currentStock', 0)} units remaining). Status: {status}."
    )

    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    timestamps = state.get("timestamps", {})
    timestamps["approval_gate_reached"] = now_iso

    return {
        "human_approval_status": status,
        "final_decision": decision_text,
        "current_agent": "Human Approval",
        "timestamps": timestamps,
        "messages": [AIMessage(content=decision_text, name="HumanApprovalGate")]
    }
