import datetime
import logging
from langchain_core.messages import AIMessage
from ai.state import AgentState

logger = logging.getLogger("amic_agentic_ai.validation_node")


def validation_node(state: AgentState) -> dict:
    """
    Stage 4: Validation Agent Node
    Deterministically evaluates business rules, budget thresholds, and compliance gates.
    Flags high-impact reorders for human approval.
    """
    extraction = state.get("data_extraction_result") or {}
    low_stock = extraction.get("lowStock", False)
    req_qty = extraction.get("requiredQuantity", 0.0)
    
    # Calculate estimated cost
    est_cost = req_qty * 4.50
    budget_limit = 15000.00
    approval_threshold = 5000.00

    # Rule checks
    budget_passed = est_cost <= budget_limit
    threshold_exceeded = est_cost > approval_threshold
    
    # Reorder required requires managerial sign-off
    requires_approval = low_stock and req_qty > 0

    validation_msg = (
        f"Validation Node Checks:\n"
        f"• Budget Limit Check (${est_cost:,.2f} <= ${budget_limit:,.2f}): {'PASSED' if budget_passed else 'FAILED'}\n"
        f"• Approval Threshold ($5,000): {'EXCEEDED (Manager Sign-Off Required)' if threshold_exceeded else 'Standard Limits'}\n"
        f"• Action Gate: {'ROUTING TO HUMAN APPROVAL' if requires_approval else 'APPROVED'}"
    )

    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    timestamps = state.get("timestamps", {})
    timestamps["validation_completed"] = now_iso

    return {
        "requires_human_approval": requires_approval,
        "human_approval_status": "PENDING" if requires_approval else "APPROVED",
        "current_agent": "Human Approval" if requires_approval else "Completed",
        "timestamps": timestamps,
        "messages": [AIMessage(content=validation_msg, name="ValidationAgent")]
    }
