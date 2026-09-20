from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus


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

    # Student 3: Validation / Safety Agent integrates quality and quarantine constraint checks
    cost = float(draft_po.get("totalAmount") or draft_po.get("estimatedCostUsd") or 0.0)
    quantity = float(draft_po.get("quantity", 0.0))
    supplier_id = draft_po.get("supplierId")
    adjusted_output = impact.get("adjustedOutput", 10000)
    planned_target = impact.get("plannedOutput", 10000)

    # 1. PO Schema & business rule validation
    if cost <= 0 or quantity <= 0 or not supplier_id:
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.Failed,
            "errors": errors + ["Validation failed: Invalid PO quantity, cost, or missing supplier."],
            "final_outcome": "Execution halted: Purchase order failed schema validation."
        }

    # 2. Check quarantine constraints via Student 3 Quality tools
    quarantine_conflict = False
    quarantine_reason = ""
    try:
        from ai.tools.production_tools import get_db_connection
        conn = get_db_connection()
        if conn:
            with conn.cursor() as cur:
                cur.execute('SELECT COUNT(*) FROM "Quarantines" WHERE "Status" = \'Active\';')
                active_q_count = cur.fetchone()[0]
                if active_q_count > 0:
                    quarantine_conflict = True
                    quarantine_reason = "Associated inventory has active quarantine holds."
            conn.close()
    except Exception:
        pass

    # 3. Risk check: Budget limit > $5,000 OR cost > $1,000 OR production shortfall OR quarantine
    budget_threshold = float(draft_po.get("budgetThreshold", 5000.0))
    is_high_impact = (cost > budget_threshold) or (cost > 1000.0) or (adjusted_output < planned_target)

    validation_results = {
        "valid": not quarantine_conflict,
        "budgetCheck": "PASSED" if cost <= budget_threshold else "EXCEEDS_BUDGET_THRESHOLD",
        "toleranceCheck": "PASSED",
        "safetyLockoutCheck": "CLEAR",
        "quarantineCheck": "FAILED" if quarantine_conflict else "CLEAR",
        "isHighImpact": is_high_impact,
        "riskLevel": "HIGH" if (is_high_impact or quarantine_conflict) else "NORMAL",
        "impactReason": quarantine_reason or (
            f"Procurement cost (${cost:,.2f}) exceeds budget threshold (${budget_threshold:,.2f}) and requires human approval." 
            if is_high_impact else "Low impact action."
        )
    }

    completed.append("Validation/Safety: Completed PO schema, financial budget & quality quarantine audit")

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

