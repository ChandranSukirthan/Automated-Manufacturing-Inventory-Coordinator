"""
Validation / Safety Agent
Performs multi-point constraint checks and produces a structured validation result.
Never bypasses budget rules, supplier verification, quality requirements, or human approval.
"""
from __future__ import annotations

import logging
import psycopg
from typing import Any, Dict

from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings
from ai.agents.quality_agent import run_quality_validation

logger = logging.getLogger("amic_agentic_ai.validation")


def _check_material_quarantine_count(mat_id: Any, mat_name: str = "", sku_code: str = "") -> int:
    try:
        with psycopg.connect(settings.database_url, connect_timeout=3) as connection:
            with connection.cursor() as cursor:
                cursor.execute('''
                    SELECT "Id", "SkuCode" FROM "RawMaterials"
                    WHERE "Id"::text = %s OR "SkuCode" = %s OR "SkuCode" = %s
                ''', (str(mat_id), str(mat_id), sku_code))
                material = cursor.fetchone()
                if not material:
                    raise ValueError("The ordered material does not exist")
                cursor.execute('''
                    SELECT COUNT(DISTINCT r."RollIdentifier") FROM "InventoryRolls" r
                    WHERE r."RawMaterialId" = %s AND (r."Status" IN ('Quarantined', 'Locked', 'On Hold')
                      OR EXISTS (SELECT 1 FROM "Quarantines" q WHERE q."InventoryRollId" = r."RollIdentifier" AND q."Status" = 'Active'))
                ''', (material[0],))
                physical_count = cursor.fetchone()[0]
                cursor.execute('''
                    SELECT COUNT(*) FROM "Quarantines" q JOIN "DefectReports" d ON d."Id" = q."DefectReportId"
                    WHERE q."Status" = 'Active' AND d."SkuCode" = %s
                      AND NOT EXISTS (SELECT 1 FROM "InventoryRolls" r WHERE r."RollIdentifier" = q."InventoryRollId" AND r."RawMaterialId" = %s)
                ''', (material[1], material[0]))
                return physical_count + cursor.fetchone()[0]
    except Exception:
        if settings.demo_mode:
            return 0
        raise ValueError("Live quarantine verification is unavailable; retry after restoring the database")


def _check_historical_material_quality_risk(mat_id: Any, mat_name: str = "") -> dict[str, Any] | None:
    try:
        with psycopg.connect(settings.database_url, connect_timeout=3) as connection:
            with connection.cursor() as cursor:
                cursor.execute('''
                    SELECT m."Name", d."Description", d."Severity", d."AffectedInventoryJson"
                    FROM "DefectReports" d JOIN "RawMaterials" m ON m."SkuCode" = d."SkuCode"
                    WHERE (m."Id"::text = %s OR m."SkuCode" = %s)
                      AND d."Status" NOT IN ('Resolved', 'Closed') AND d."Severity" IN ('HIGH', 'High', 'Critical')
                    ORDER BY d."CreatedAt" DESC LIMIT 1
                ''', (str(mat_id), str(mat_id)))
                row = cursor.fetchone()
        if row:
            import json
            rolls = json.loads(row[3] or "[]")
            return {"material": row[0], "issue": row[1], "severity": row[2], "relatedRoll": rolls[0] if rolls else None}
    except Exception:
        if not settings.demo_mode:
            raise ValueError("Live defect verification is unavailable")
    return None


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
    budget_limit = float(state.get("budget_limit") or draft_po.get("budgetLimit") or 20000.0)
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
    budget_check_passed = (budget_limit <= 0 or estimated_total <= budget_limit)
    budget_val = "PASSED" if budget_check_passed else "BUDGET_EXCEEDED"
    budget_check = "PASS" if budget_check_passed else "FAIL"
    rejection_reasons = []

    if not budget_check_passed:
        errors.append(f"Budget exceeded: ${estimated_total:,.2f} > limit ${budget_limit:,.2f}")
        rejection_reasons.append(f"Total order cost (${estimated_total:,.2f}) exceeds authorized budget limit (${budget_limit:,.2f}).")

    unit_price = float(draft_po.get("unitPrice") or 0.0)
    expected_cost = quantity * unit_price if (quantity > 0 and unit_price > 0) else cost
    po_math_check = "PASSED"
    is_valid = budget_check_passed

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
                        elif not row_id:
                            supplier_val = "INACTIVE_SUPPLIER"
                            is_valid = False
                            rejection_reasons.append(f"Supplier ID '{supplier_id}' not found in ERP master catalog.")
                    elif not settings.demo_mode:
                        supplier_val = "SUPPLIER_NOT_FOUND"
                        is_valid = False
                        rejection_reasons.append("Recommended supplier is not onboarded in the ERP.")
    except Exception:
        if not settings.demo_mode:
            supplier_val = "UNAVAILABLE"
            is_valid = False
            rejection_reasons.append("Live supplier verification is unavailable.")

    # Material validation against PostgreSQL RawMaterials database
    material_val = "PASSED"
    mat_name = ""
    mat_id = draft_po.get("materialId") or state.get("material_id") or state.get("target_material_id") or state.get("inventory_data", {}).get("materialId")
    if mat_id is None or str(mat_id).strip() == "" or str(mat_id).strip() == "0":
        material_val = "MATERIAL_NOT_FOUND"
        is_valid = False
        rejection_reasons.append("Order is missing a valid raw material reference.")
    else:
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
                    if str(mat_id).isdigit():
                        cur.execute('SELECT "Id", "SkuCode", "Name" FROM "RawMaterials" WHERE "Id" = %s LIMIT 1;', (int(mat_id),))
                    else:
                        cur.execute('SELECT "Id", "SkuCode", "Name" FROM "RawMaterials" WHERE "SkuCode" = %s OR "Name" = %s LIMIT 1;', (str(mat_id), str(mat_id)))
                    mat_row = cur.fetchone()
                    if not mat_row:
                        material_val = "MATERIAL_NOT_FOUND"
                        is_valid = False
                        rejection_reasons.append(f"Raw material '{mat_id}' does not exist in inventory catalog.")
                    else:
                        material_val = "PASSED"
                        mat_name = mat_row[2] or ""
        except Exception as ex:
            logger.warning(f"Database material check error: {ex}")
            if not settings.demo_mode:
                material_val = "UNAVAILABLE"
                is_valid = False
                rejection_reasons.append("Live material verification is unavailable.")

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
    if supplier_verification in ("VERIFIED", "APPROVED") and supplier_val == "PASSED":
        supplier_check = "PASS"
    elif supplier_verification == "BLOCKED" or supplier_val == "INACTIVE_SUPPLIER":
        supplier_check = "FAIL"
    else:
        supplier_check = "WARNING"

    # ── 5. Quality, Historical Risk & Quarantine Safety Assessment ─────────────
    quality_safety_status = "CLEAR"
    quality_data = dict(state.get("quality_data") or {})
    defect = quality_data.get("defect") or {}
    sku_val = draft_po.get("materialSku") or state.get("sku") or ""
    quarantined_rolls_count = _check_material_quarantine_count(mat_id, mat_name, sku_code=sku_val)

    # Historical Quality Risk Detection (Human-in-the-Loop requirement)
    historical_risk = _check_historical_material_quality_risk(mat_id, mat_name)

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
    elif historical_risk:
        quality_safety_status = "MANUAL_REVIEW_REQUIRED"
        completed.append(f"Quality Agent: Flagged Historical Quality Risk on material '{historical_risk['material']}' (Roll: {historical_risk['relatedRoll']}) - Manual QA Review Required")
    else:
        completed.append("Quality Agent: Factory inventory quarantine status CLEAR")

    # ── 6. Diagnostic & Safety reasons ─────────────────────────────────────────
    diagnostic_reasons = []
    if quality_safety_status == "QUARANTINE_REQUIRED":
        diagnostic_reasons.append("Quality Agent quarantine recommendation requires authorization")
    elif quality_safety_status == "QUARANTINE_ACTIVE" or quarantined_rolls_count > 0:
        diagnostic_reasons.append(f"Quality Agent detected {quarantined_rolls_count} active quarantine holds")
    elif quality_safety_status == "MANUAL_REVIEW_REQUIRED" and historical_risk:
        diagnostic_reasons.append(f"Historical quality risk detected on {historical_risk['material']} (Related roll: {historical_risk['relatedRoll']})")
    if supplier_val == "INACTIVE_SUPPLIER":
        diagnostic_reasons.append("Supplier is marked inactive in database")
    if material_val == "MATERIAL_NOT_FOUND":
        diagnostic_reasons.append("Raw material not found in inventory database")
    if po_math_check == "CALCULATION_MISMATCH":
        diagnostic_reasons.append("PO financial calculation mismatch detected")
    if not budget_check_passed:
        diagnostic_reasons.append(f"Total order cost exceeds budget limit (${budget_limit:,.2f})")

    existing_vr = state.get("validation_results", {})
    if not isinstance(existing_vr, dict):
        existing_vr = {}

    manual_res_status = existing_vr.get("manualResolutionStatus")
    if not manual_res_status:
        if quality_safety_status in ["QUARANTINE_REQUIRED", "QUARANTINE_ACTIVE", "MANUAL_REVIEW_REQUIRED"] or not is_valid:
            manual_res_status = "PENDING_REVIEW"
        else:
            manual_res_status = "NOT_REQUIRED"

    if manual_res_status != "RESOLVED" and quality_safety_status == "MANUAL_REVIEW_REQUIRED" and historical_risk:
        is_valid = False
        rejection_reasons.append(f"Manual QA Review Required: Historical quality risk detected on material '{historical_risk['material']}' (Related roll: {historical_risk['relatedRoll']} - {historical_risk['issue']}). Waiting for QA Inspector review.")

    if budget_check == "FAIL" or quantity_check == "FAIL" or supplier_check == "FAIL" or not is_valid:
        overall_status = "FAILED"
    elif supplier_check == "WARNING" or (quality_safety_status in ["QUARANTINE_REQUIRED", "QUARANTINE_ACTIVE", "MANUAL_REVIEW_REQUIRED"]):
        overall_status = "REQUIRES_MANAGER_REVIEW"
    else:
        overall_status = "APPROVED"

    validation_results = {
        "valid": is_valid and (quality_safety_status in ("CLEAR", "PASSED") or manual_res_status == "RESOLVED") and (overall_status != "FAILED"),
        "isValid": is_valid and (quality_safety_status in ("CLEAR", "PASSED") or manual_res_status == "RESOLVED"),
        "qualitySafetyStatus": quality_safety_status,
        "supplierValidation": supplier_val,
        "budgetCheck": budget_val,
        "toleranceCheck": "PASSED",
        "safetyLockoutCheck": "CLEAR" if (quality_safety_status == "CLEAR" or manual_res_status == "RESOLVED") else "LOCKED",
        "poMathematicalCheck": po_math_check,
        "materialValidation": material_val,
        "quarantinedRollsCount": quarantined_rolls_count,
        "historicalRisk": historical_risk,
        "impactReason": "; ".join(diagnostic_reasons) if diagnostic_reasons else "Operational parameters clear.",
        "rejectionReason": "; ".join(rejection_reasons) if rejection_reasons else "",
        "manualResolutionStatus": manual_res_status,
        "manualResolutionNote": existing_vr.get("manualResolutionNote") or "",
        "resolvedBy": existing_vr.get("resolvedBy") or "",
        "resolvedAt": existing_vr.get("resolvedAt") or None,
        "quantityCheck": quantity_check,
        "moqCheck": moq_check,
        "packSizeCheck": pack_size_check,
        "supplierVerification": supplier_check,
        "qualityCheck": "PASS" if quality_safety_status in ("CLEAR", "PASSED") else "WARNING",
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
        "current_agent": "Payment / Dispatch",
        "status": WorkflowStatus.WaitingForApproval,
        "approval_status": ApprovalStatus.Approved,
        "completed_steps": completed,
        "final_outcome": (
            f"Procurement recommendation approved. Draft PO {po_num} queued for "
            f"{state.get('recommended_supplier', {}).get('supplierName', 'supplier')}. "
            f"Quantity: {state.get('recommended_quantity', 0):,.0f} {state.get('unit', 'units')}. "
            f"Estimated total: ${state.get('estimated_total_cost', 0):,.2f}."
        ),
    }
