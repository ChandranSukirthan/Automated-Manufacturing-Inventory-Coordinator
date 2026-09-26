"""
Validation / Safety Agent
Performs multi-point constraint checks and produces a structured validation result.
Never bypasses budget rules, supplier verification, quality requirements, or human approval.
"""
from __future__ import annotations

import logging
from typing import Any, Dict

from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings

logger = logging.getLogger("amic_agentic_ai.validation")


def _check_quarantine_count() -> int:
    """Returns count of quarantined inventory rolls from PostgreSQL, or 0 on failure."""
    try:
        import psycopg
        with psycopg.connect(settings.database_url, connect_timeout=2) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    'SELECT COUNT(*) FROM "InventoryRolls" WHERE UPPER("Status") = %s;',
                    ("QUARANTINED",),
                )
                row = cur.fetchone()
                return row[0] if row else 0
    except Exception:
        return 0


def validation_node(state: AgentState) -> Dict[str, Any]:
    """
    Validation / Safety Agent Node.
    Checks all procurement constraints and produces a structured validation result.

    Output schema:
    {
        "budgetCheck": "PASS|FAIL",
        "quantityCheck": "PASS|FAIL",
        "moqCheck": "PASS|FAIL",
        "packSizeCheck": "PASS|FAIL",
        "supplierVerification": "PASS|FAIL|WARNING",
        "qualityCheck": "PASS|FAIL|WARNING",
        "availabilityCheck": "PASS|FAIL",
        "overallStatus": "APPROVED|REQUIRES_MANAGER_REVIEW|FAILED"
    }
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])

    # ── Read purchasing outputs ────────────────────────────────────────────────
    recommended_supplier = state.get("recommended_supplier") or {}
    draft_po = state.get("draft_po") or state.get("purchasing_data", {}).get("draft_po") or {}
    net_deficit = state.get("net_deficit") or 0.0
    recommended_qty = state.get("recommended_quantity") or state.get("required_quantity") or 0.0
    estimated_total = state.get("estimated_total_cost") or state.get("total_cost") or 0.0
    budget_limit = state.get("budget_limit") or 20000.0
    supplier_verification = state.get("supplier_verification") or recommended_supplier.get("verificationStatus") or "UNVERIFIED"
    quality_evidence_list = state.get("quality_evidence") or []
    material_name = state.get("material_name") or "Unknown Material"

    # Fallback: read from legacy purchasing_data
    if estimated_total == 0.0:
        estimated_total = draft_po.get("estimatedCostUsd") or 0.0
    if recommended_qty == 0.0:
        recommended_qty = draft_po.get("quantity") or 0.0

    # ── 1. Budget check ────────────────────────────────────────────────────────
    budget_check = "PASS" if estimated_total <= budget_limit else "FAIL"
    if budget_check == "FAIL":
        errors.append(f"Budget exceeded: ${estimated_total:,.2f} > limit ${budget_limit:,.2f}")

    # ── 2. Quantity check ──────────────────────────────────────────────────────
    quantity_check = "PASS" if recommended_qty >= net_deficit else "FAIL"
    if quantity_check == "FAIL":
        errors.append(f"Quantity insufficient: {recommended_qty} < required {net_deficit}")

    # ── 3. MOQ check ───────────────────────────────────────────────────────────
    moq = float(recommended_supplier.get("moq") or 0.0)
    moq_check = "PASS" if recommended_qty >= moq else "FAIL"

    # ── 4. Pack size check ─────────────────────────────────────────────────────
    pack_size = float(recommended_supplier.get("packSize") or 1.0)
    pack_size_check = "PASS" if pack_size <= 0 or (recommended_qty % pack_size == 0) else "WARNING"

    # ── 5. Supplier verification check ────────────────────────────────────────
    if supplier_verification == "VERIFIED" or supplier_verification == "APPROVED":
        supplier_check = "PASS"
    elif supplier_verification == "BLOCKED":
        supplier_check = "FAIL"
        errors.append("Recommended supplier is BLOCKED — procurement halted")
    else:
        supplier_check = "WARNING"  # UNVERIFIED — requires manager review

    # ── 6. Quality check ───────────────────────────────────────────────────────
    has_quality_evidence = any(
        str(qe.get("evidence") or "").strip().upper() not in ("", "UNKNOWN", "NONE", "N/A")
        for qe in quality_evidence_list
    )
    if not quality_evidence_list:
        # Fallback: check recommended_supplier directly
        qe_val = str(recommended_supplier.get("qualityEvidence") or "").strip()
        has_quality_evidence = bool(qe_val) and qe_val.upper() not in ("UNKNOWN", "NONE", "N/A")

    quality_check = "PASS" if has_quality_evidence else "WARNING"

    # ── 7. Availability check ──────────────────────────────────────────────────
    availability = str(recommended_supplier.get("availability") or "AVAILABLE").upper()
    availability_check = "PASS" if "AVAILABLE" in availability else "FAIL"

    # ── 8. Material check ──────────────────────────────────────────────────────
    material_check = "PASS" if material_name and material_name != "Unknown Material" else "WARNING"

    # ── 9. Quarantine safety check ─────────────────────────────────────────────
    quarantined_count = _check_quarantine_count()
    quarantine_status = "QUARANTINE_ACTIVE" if quarantined_count > 0 else "CLEAR"
    if quarantined_count > 0:
        completed.append(f"Validation: Detected {quarantined_count} quarantined inventory rolls")

    # ── Determine overall status ───────────────────────────────────────────────
    hard_failures = [
        budget_check == "FAIL",
        quantity_check == "FAIL",
        moq_check == "FAIL",
        supplier_check == "FAIL",
        availability_check == "FAIL",
    ]
    warnings = [
        supplier_check == "WARNING",
        quality_check == "WARNING",
        pack_size_check == "WARNING",
        material_check == "WARNING",
        quarantined_count > 0,
    ]

    if any(hard_failures):
        overall_status = "FAILED"
    elif any(warnings):
        overall_status = "REQUIRES_MANAGER_REVIEW"
    else:
        overall_status = "APPROVED"

    validation_results: Dict[str, Any] = {
        "budgetCheck": budget_check,
        "quantityCheck": quantity_check,
        "moqCheck": moq_check,
        "packSizeCheck": pack_size_check,
        "supplierVerification": supplier_check,
        "qualityCheck": quality_check,
        "availabilityCheck": availability_check,
        "materialCheck": material_check,
        "quarantineStatus": quarantine_status,
        "quarantinedRollsCount": quarantined_count,
        "estimatedTotalCost": estimated_total,
        "budgetLimit": budget_limit,
        "recommendedQuantity": recommended_qty,
        "netDeficit": net_deficit,
        "overallStatus": overall_status,
    }

    completed.append(
        f"Validation: Completed multi-point check — overall status: {overall_status}"
    )

    # ── Hard failure: halt workflow ────────────────────────────────────────────
    if overall_status == "FAILED":
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.Failed,
            "validation_results": validation_results,
            "requires_approval": False,
            "completed_steps": completed,
            "errors": errors,
            "final_outcome": f"Validation failed: {'; '.join(errors)}",
        }

    # ── Already approved by manager (resumed workflow) ─────────────────────────
    if state.get("approval_status") == ApprovalStatus.Approved:
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.Running,
            "validation_results": validation_results,
            "requires_approval": False,
            "completed_steps": completed,
            "errors": errors,
        }

    # ── Revision requested: re-enter purchasing with revision context ──────────
    if state.get("approval_status") == ApprovalStatus.RevisionRequested:
        revision = state.get("revision_request") or "Manager requested revision"
        completed.append(f"Validation: Revision requested — {revision}")
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.WaitingForApproval,
            "approval_status": ApprovalStatus.Pending,
            "validation_results": validation_results,
            "requires_approval": True,
            "completed_steps": completed,
            "errors": errors,
        }

    # ── Route to human approval (all procurement requires manager sign-off) ────
    return {
        "current_agent": "Validation/Safety",
        "status": WorkflowStatus.WaitingForApproval,
        "approval_status": ApprovalStatus.Pending,
        "validation_results": validation_results,
        "requires_approval": True,
        "completed_steps": completed + ["Waiting for Supply Chain Manager approval"],
        "errors": errors,
    }


def execution_node(state: AgentState) -> Dict[str, Any]:
    """
    Execution Node: finalises workflow after human approval.
    Records structured outcome for future learning dataset.
    """
    completed = list(state.get("completed_steps") or [])
    draft_po = state.get("draft_po") or state.get("purchasing_data", {}).get("draft_po") or {}
    po_num = draft_po.get("poNumber", "PO-DRAFT")

    completed.append(f"Execution: Draft PO {po_num} registered in ERP staging queue")

    return {
        "current_agent": "Execution",
        "status": WorkflowStatus.Completed,
        "approval_status": ApprovalStatus.Approved,
        "completed_steps": completed,
        "final_outcome": (
            f"Procurement recommendation approved. Draft PO {po_num} queued for "
            f"{state.get('recommended_supplier', {}).get('supplierName', 'supplier')}. "
            f"Quantity: {state.get('recommended_quantity', 0):,.0f} {state.get('unit', 'units')}. "
            f"Estimated total: ${state.get('estimated_total_cost', 0):,.2f}."
        ),
    }
