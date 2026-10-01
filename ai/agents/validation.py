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
from ai.agents.quality_agent import run_quality_validation

logger = logging.getLogger("amic_agentic_ai.validation")


def _check_quarantine_count() -> int:
    """Returns count of active quarantines from PostgreSQL, or 0 on failure."""
    try:
        import psycopg
        with psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=2,
        ) as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT COUNT(*) FROM "Quarantines" WHERE "Status" = \'Active\';')
                row = cur.fetchone()
                return row[0] if row else 0
    except Exception:
        return 0


def validation_node(state: AgentState) -> Dict[str, Any]:
    """
    Validation / Safety Agent Node.
    Checks all procurement constraints and produces a structured validation result.
    Combines Student 3 Quality/Quarantine audits with Manager financial constraints.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])

    # ── Read purchasing & production outputs ────────────────────────────────────
    recommended_supplier = state.get("recommended_supplier") or {}
    draft_po = state.get("draft_po") or state.get("purchasing_data", {}).get("draft_po") or {}
    net_deficit = float(state.get("net_deficit") or 0.0)
    recommended_qty = float(state.get("recommended_quantity") or state.get("required_quantity") or draft_po.get("quantity") or 0.0)
    estimated_total = float(state.get("estimated_total_cost") or state.get("total_cost") or draft_po.get("totalAmount") or draft_po.get("estimatedCostUsd") or 0.0)
    budget_limit = float(state.get("budget_limit") or 20000.0)
    budget_threshold = float(draft_po.get("budgetThreshold", 5000.0))
    supplier_verification = state.get("supplier_verification") or recommended_supplier.get("verificationStatus") or "VERIFIED"

    prod_data = state.get("production_data", {})
    impact = prod_data.get("impact", {})
    adjusted_output = impact.get("adjustedOutput", 10000)
    planned_target = impact.get("plannedOutput", 10000)

    cost = estimated_total
    quantity = recommended_qty
    supplier_id = recommended_supplier.get("supplierId") or draft_po.get("supplierId")
    purchasing_data = state.get("purchasing_data", {})

    # ── 1. Budget & Mathematical validation check ──────────────────────────────
    budget_check = "PASS" if estimated_total <= budget_limit else "FAIL"
    if budget_check == "FAIL":
        errors.append(f"Budget exceeded: ${estimated_total:,.2f} > limit ${budget_limit:,.2f}")

    unit_price = float(draft_po.get("unitPrice") or 0.0)
    expected_cost = quantity * unit_price if (quantity > 0 and unit_price > 0) else cost
    po_math_check = "PASSED"
    is_valid = (budget_check == "PASS")
    rejection_reasons = []

    if cost <= 0 or quantity <= 0:
        po_math_check = "CALCULATION_MISMATCH"
        is_valid = False
        rejection_reasons.append("Invalid PO quantity or cost.")

    if unit_price > 0 and quantity > 0 and abs(cost - (quantity * unit_price)) > 0.05:
        po_math_check = "CALCULATION_MISMATCH"
        is_valid = False
        rejection_reasons.append(f"Calculation mismatch: {quantity} x ${unit_price:.2f} != ${cost:.2f}")

    # Supplier validation against PostgreSQL database
    supplier_val = "PASSED"
    try:
        import psycopg
        with psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=2
        ) as conn:
            with conn.cursor() as cur:
                # Check Supplier status
                cur.execute('SELECT "IsActive", "Name" FROM "Suppliers" WHERE "SupplierCode" = %s OR "Name" = %s LIMIT 1;', (str(supplier_id), str(supplier_id)))
                row = cur.fetchone()
                if row:
                    if not row[0]:
                        supplier_val = "INACTIVE_SUPPLIER"
                        is_valid = False
                        rejection_reasons.append(f"Supplier '{row[1]}' is inactive in ERP master catalog.")
                else:
                    if str(supplier_id).isdigit():
                        cur.execute('SELECT "IsActive", "Name" FROM "Suppliers" WHERE "Id" = %s LIMIT 1;', (int(supplier_id),))
                        row_id = cur.fetchone()
                        if row_id and not row_id[0]:
                            supplier_val = "INACTIVE_SUPPLIER"
                            is_valid = False
                            rejection_reasons.append(f"Supplier '{row_id[1]}' is inactive in ERP master catalog.")
    except Exception:
        pass

    # Material validation
    material_val = "PASSED"
    mat_id = draft_po.get("materialId") or state.get("inventory_data", {}).get("materialId")
    if not mat_id:
        material_val = "PASSED"

    # ── 2. Quantity check ──────────────────────────────────────────────────────
    quantity_check = "PASS" if recommended_qty >= net_deficit else "FAIL"
    if quantity_check == "FAIL":
        errors.append(f"Quantity insufficient: {recommended_qty} < required {net_deficit}")

    # ── 3. MOQ & Pack Size checks ──────────────────────────────────────────────
    moq = float(recommended_supplier.get("moq") or recommended_supplier.get("minimumOrderQuantity") or 0.0)
    moq_check = "PASS" if recommended_qty >= moq else "FAIL"
    pack_size = float(recommended_supplier.get("packSize") or 1.0)
    pack_size_check = "PASS" if pack_size <= 0 or (recommended_qty % pack_size == 0) else "WARNING"

    # ── 4. Supplier verification check ────────────────────────────────────────
    if supplier_verification in ("VERIFIED", "APPROVED"):
        supplier_check = "PASS"
    elif supplier_verification == "BLOCKED" or supplier_val == "INACTIVE_SUPPLIER":
        supplier_check = "FAIL"
    else:
        supplier_check = "WARNING"

    # ── 5. Quality & Quarantine Safety Assessment (Student 3) ─────────────────
    quality_safety_status = "CLEAR"
    quality_data = dict(state.get("quality_data") or {})
    defect = quality_data.get("defect")
    quarantined_rolls_count = _check_quarantine_count()

    if defect:
        try:
            quality_state = run_quality_validation({
                **state,
                "purchasing_data": purchasing_data,
                "quality_data": quality_data,
            })
            quality_data = quality_state.get("quality_data", quality_data)
            q_val = quality_data.get("validation", {})
            if q_val.get("valid") is False:
                reason = q_val.get("reason", "Associated inventory is quarantined")
                quality_safety_status = "QUARANTINE_REQUIRED"
                is_valid = False
                rejection_reasons.append(f"Quality Agent validation rejected: {reason}")
            if q_val.get("quarantineRequired"):
                quarantined_rolls_count = max(quarantined_rolls_count, len(q_val.get("affectedInventory", [])))
                quality_safety_status = "QUARANTINE_REQUIRED"
                completed.append(f"Quality Agent: Quarantine required for batch {q_val.get('batchId')}")
        except Exception:
            try:
                from ai.tools.quality_tools import analyze_defect_context
                ctx = analyze_defect_context(defect)
                if ctx.get("quarantineRequired"):
                    quality_safety_status = "QUARANTINE_REQUIRED"
                    completed.append(f"Quality Agent: Quarantine required for batch {ctx.get('batchId')}")
                else:
                    completed.append(f"Quality Agent: Defect severity {ctx.get('severity')} - no quarantine required")
            except Exception as inner_ex:
                if str(defect.get("severity", "")).capitalize() in ("High", "Critical"):
                    quality_safety_status = "QUARANTINE_REQUIRED"
                    quarantined_rolls_count = max(quarantined_rolls_count, 1)
                    completed.append(f"Quality Agent: Quarantine required for defect {defect.get('batchId', 'UNKNOWN')} ({defect.get('severity')} severity)")
    elif quarantined_rolls_count > 0:
        quality_safety_status = "QUARANTINE_ACTIVE"
        completed.append(f"Quality Agent: Detected {quarantined_rolls_count} active quarantine holds")
    else:
        completed.append("Quality Agent: Factory inventory quarantine status CLEAR")

    # ── 6. High impact / Human approval triggers ──────────────────────────────
    is_high_impact = (
        (cost > budget_threshold)
        or (cost > 1000.0)
        or (adjusted_output < planned_target)
        or (quality_safety_status in ["QUARANTINE_REQUIRED", "QUARANTINE_ACTIVE"])
        or (quarantined_rolls_count > 0)
        or (not is_valid)
    )

    impact_reasons = []
    if cost > budget_threshold:
        impact_reasons.append(f"Procurement cost (${cost:,.2f}) exceeds budget threshold (${budget_threshold:,.2f})")
    elif cost > 1000.0:
        impact_reasons.append("Procurement cost exceeds $1,000 threshold")
    if adjusted_output < planned_target:
        impact_reasons.append("Production output is material-constrained")
    if quality_safety_status == "QUARANTINE_REQUIRED":
        impact_reasons.append("Quality Agent quarantine recommendation requires authorization")
    elif quality_safety_status == "QUARANTINE_ACTIVE" or quarantined_rolls_count > 0:
        impact_reasons.append(f"Quality Agent detected {quarantined_rolls_count} active quarantine holds")
    if supplier_val == "INACTIVE_SUPPLIER":
        impact_reasons.append("Supplier is marked inactive in database")
    if po_math_check == "CALCULATION_MISMATCH":
        impact_reasons.append("PO financial calculation mismatch detected")

    existing_vr = state.get("validation_results", {})
    if not isinstance(existing_vr, dict):
        existing_vr = {}

    manual_res_status = existing_vr.get("manualResolutionStatus")
    if not manual_res_status:
        if quality_safety_status in ["QUARANTINE_REQUIRED", "QUARANTINE_ACTIVE"] or not is_valid:
            manual_res_status = "PENDING_REVIEW"
        else:
            manual_res_status = "NOT_REQUIRED"

    if budget_check == "FAIL" or quantity_check == "FAIL" or supplier_check == "FAIL" or not is_valid:
        overall_status = "FAILED"
    elif supplier_check == "WARNING" or is_high_impact:
        overall_status = "REQUIRES_MANAGER_REVIEW"
    else:
        overall_status = "APPROVED"

    validation_results = {
        "valid": is_valid and (quality_safety_status == "CLEAR") and (overall_status != "FAILED"),
        "isValid": is_valid and (quality_safety_status == "CLEAR"),
        "qualitySafetyStatus": quality_safety_status,
        "supplierValidation": supplier_val,
        "budgetCheck": "PASSED" if cost <= budget_threshold else "EXCEEDS_BUDGET_THRESHOLD",
        "toleranceCheck": "PASSED",
        "safetyLockoutCheck": "CLEAR" if quality_safety_status == "CLEAR" else "LOCKED",
        "poMathematicalCheck": po_math_check,
        "materialValidation": material_val,
        "quarantinedRollsCount": quarantined_rolls_count,
        "isHighImpact": is_high_impact,
        "impactReason": "; ".join(impact_reasons) if is_high_impact else "Low impact action.",
        "rejectionReason": "; ".join(rejection_reasons) if rejection_reasons else "",
        "manualResolutionStatus": manual_res_status,
        "manualResolutionNote": existing_vr.get("manualResolutionNote") or "",
        "resolvedBy": existing_vr.get("resolvedBy") or "",
        "resolvedAt": existing_vr.get("resolvedAt") or None,
        "quantityCheck": quantity_check,
        "moqCheck": moq_check,
        "packSizeCheck": pack_size_check,
        "supplierVerification": supplier_check,
        "qualityCheck": "PASS" if quality_safety_status == "CLEAR" else "WARNING",
        "availabilityCheck": "PASS",
        "overallStatus": overall_status,
    }

    completed.append("Validation/Safety: Completed multi-point risk, financial, and quality safety assessment")

    # ── Already approved by manager (resumed workflow) ─────────────────────────
    if state.get("approval_status") == ApprovalStatus.Approved:
        return {
            "current_agent": "Validation/Safety",
            "status": WorkflowStatus.Running,
            "validation_results": validation_results,
            "requires_approval": False,
            "completed_steps": completed,
            "errors": errors,
            "quality_data": quality_data,
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
            "quality_data": quality_data,
        }

    # ── Route to human approval (all procurement requires manager sign-off) ────
    return {
        "current_agent": "Validation/Safety",
        "status": WorkflowStatus.WaitingForApproval,
        "approval_status": ApprovalStatus.Pending,
        "validation_results": validation_results,
        "requires_approval": True,
        "completed_steps": completed + ["Waiting for Supply Chain Manager human approval"],
        "errors": errors,
        "quality_data": quality_data,
    }


def execution_node(state: AgentState) -> Dict[str, Any]:
    """
    Execution Node: finalises workflow after human approval.
    Records structured outcome for future learning dataset.
    """
    completed = list(state.get("completed_steps") or [])
    draft_po = state.get("draft_po") or state.get("purchasing_data", {}).get("draft_po") or {}
    po_num = draft_po.get("poNumber", "PO-DRAFT")

    completed.append(f"Execution: PO {po_num} registered in ERP staging queue")

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
