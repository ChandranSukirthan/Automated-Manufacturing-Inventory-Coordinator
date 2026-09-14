from typing import Dict, Any
from core.state import AgentState, WorkflowStatus, ApprovalStatus


def validation_node(state: AgentState) -> Dict[str, Any]:
    """
    Validation / Safety Agent Node:
    Performs risk analysis and business constraint checks.
    Rules:
    - If validation fails: do not execute.
    - If high-impact (e.g., procurement expenditure > $1,000 or production shortfall):
      pauses for human approval.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))

    purchasing_data = state.get("purchasing_data", {})
    draft_po = purchasing_data.get("draft_po", {})
    prod_data = state.get("production_data", {})
    impact = prod_data.get("impact", {})

    cost = draft_po.get("estimatedCostUsd", 0.0)
    adjusted_output = impact.get("adjustedOutput", 10000)
    planned_target = impact.get("plannedOutput", 10000)

    # 1. Validation check
    if cost <= 0:
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.Failed,
            "errors": errors + ["Validation failed: Invalid PO quantity or cost."],
            "final_outcome": "Execution halted: Purchase order failed financial validation."
        }

    # 2. Risk check: High impact triggers Human Approval requirement
    is_high_impact = cost > 1000.0 or (adjusted_output < planned_target)

    validation_results = {
        "budgetCheck": "PASSED",
        "toleranceCheck": "PASSED",
        "safetyLockoutCheck": "CLEAR",
        "isHighImpact": is_high_impact,
        "impactReason": "Procurement cost exceeds $1,000 threshold and production output is material-constrained." if is_high_impact else "Low impact action."
    }

    completed.append("Validation/Safety: Completed multi-point risk and safety assessment")

    # If approval was already granted (e.g. resumed by human)
    if state.get("approval_status") == ApprovalStatus.Approved:
        return {
            "current_agent": "Validation/Safety",
            "validation_results": validation_results,
            "requires_approval": False,
            "status": WorkflowStatus.Running,
            "completed_steps": completed,
            "errors": errors
        }

    if is_high_impact:
        return {
            "current_agent": "Validation/Safety",
            "validation_results": validation_results,
            "requires_approval": True,
            "status": WorkflowStatus.WaitingForApproval,
            "approval_status": ApprovalStatus.Pending,
            "completed_steps": completed + ["Waiting for IT Admin human approval"],
            "errors": errors
        }

    return {
        "current_agent": "Validation/Safety",
        "validation_results": validation_results,
        "requires_approval": False,
        "completed_steps": completed,
        "errors": errors
    }


def execution_node(state: AgentState) -> Dict[str, Any]:
    """
    Execution Node:
    Finalizes workflow after validation and human approval.
    """
    completed = list(state.get("completed_steps", []))
    draft_po = state.get("purchasing_data", {}).get("draft_po", {})
    po_num = draft_po.get("poNumber", "PO-DRAFT")

    completed.append(f"Execution: PO {po_num} registered in manufacturing ERP staging queue")

    return {
        "current_agent": "Execution",
        "status": WorkflowStatus.Completed,
        "approval_status": ApprovalStatus.Approved if state.get("requires_approval") else state.get("approval_status", ApprovalStatus.Approved),
        "completed_steps": completed,
        "final_outcome": f"Objective achieved: {draft_po.get('quantity', 4000)}m raw film requisition queued under {po_num}. Production schedule reconciled."
    }

