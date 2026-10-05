"""Coordinates specialist findings; never modifies validation evidence or budgets."""
from ai.core.state import ApprovalStatus, WorkflowStatus
from ai.core.validation_contract import failed_checks

MAX_SUPPLIER_ATTEMPTS = 3


def supervisor_node(state):
    results = state.get("validation_results") or {}
    failures = list(dict.fromkeys(failed_checks(results) + list(results.get("failedChecks") or [])))
    steps = list(state.get("completed_steps") or [])
    attempt = int(state.get("supplier_selection_attempt") or 1)
    base = {"current_agent": "Supervisor Agent", "requires_approval": False,
            "automatic_retry_required": False, "max_supplier_selection_attempts": MAX_SUPPLIER_ATTEMPTS}
    if not failures and results.get("isValid") is True:
        return {**base, "status": WorkflowStatus.WaitingForApproval,
                "approval_status": ApprovalStatus.Pending, "required_action": "MANAGER_APPROVAL",
                "requires_approval": True,
                "completed_steps": steps + ["Supervisor: All checks passed; requesting purchasing approval"]}

    # Technical/data/QA failures do not disqualify an otherwise suitable supplier.
    if any(results.get(key) == "UNAVAILABLE" for key in failures):
        action = "RESTORE_SERVICE"
    elif "materialValidation" in failures or "poMathematicalCheck" in failures:
        action = "CORRECT_DATA"
    elif "qualitySafetyStatus" in failures:
        action = "QA_REVIEW"
    else:
        action = "RESELECT_SUPPLIER"
    if action == "RESELECT_SUPPLIER" and attempt < MAX_SUPPLIER_ATTEMPTS:
        supplier = state.get("recommended_supplier") or {}
        excluded = list(state.get("excluded_supplier_ids") or [])
        identifier = supplier.get("supplierId") or supplier.get("supplierName")
        if identifier is not None and str(identifier) not in excluded:
            excluded.append(str(identifier))
        return {**base, "status": WorkflowStatus.Running, "approval_status": ApprovalStatus.Pending,
                "required_action": action, "automatic_retry_required": True,
                "excluded_supplier_ids": excluded, "draft_po": None, "recommended_supplier": None,
                "purchasing_data": {}, "final_outcome": None,
                "completed_steps": steps + [f"Supervisor: Supplier attempt {attempt}/3 failed; requesting a revised proposal"]}
    if action == "RESELECT_SUPPLIER":
        action = "REVIEW_SUPPLIER_QUOTES"
    return {**base, "status": WorkflowStatus.Failed, "approval_status": ApprovalStatus.Pending,
            "required_action": action,
            "final_outcome": f"Needs intervention: {action}. Payment approval is blocked.",
            "completed_steps": steps + [f"Supervisor: Paused for {action}; supplier attempts used {attempt}/3"]}
