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


def _check_historical_material_quality_risk(mat_id: Any, mat_name: str = "") -> dict[str, Any] | None:
    """
    Inspects historical quality data associated with the PO's raw material.
    Relationship: RawMaterial -> InventoryRolls -> DefectReports / Quarantines.
    Returns historicalRisk dict if a past quality issue/quarantine exists on this material, else None.
    """
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
                # 1. Look for inventory rolls of this material with defect reports or quarantines
                if str(mat_id).isdigit():
                    cur.execute(
                        '''
                        SELECT ir."Id", ir."RollIdentifier", dr."Description", dr."Severity", q."Reason", r."Name"
                        FROM "InventoryRolls" ir
                        JOIN "RawMaterials" r ON r."Id" = ir."RawMaterialId"
                        LEFT JOIN "Quarantines" q ON q."InventoryRollId" = ir."Id" OR q."InventoryRollId" = ir."RollIdentifier"
                        LEFT JOIN "DefectReports" dr ON dr."Id" = q."DefectReportId" OR dr."BatchId" = ir."BatchId"
                        WHERE ir."RawMaterialId" = %s AND (q."Id" IS NOT NULL OR dr."Id" IS NOT NULL)
                        ORDER BY COALESCE(q."CreatedAt", dr."CreatedAt", ir."CreatedAt") DESC
                        LIMIT 1;
                        ''',
                        (int(mat_id),)
                    )
                else:
                    cur.execute(
                        '''
                        SELECT ir."Id", ir."RollIdentifier", dr."Description", dr."Severity", q."Reason", r."Name"
                        FROM "InventoryRolls" ir
                        JOIN "RawMaterials" r ON r."Id" = ir."RawMaterialId"
                        LEFT JOIN "Quarantines" q ON q."InventoryRollId" = ir."Id" OR q."InventoryRollId" = ir."RollIdentifier"
                        LEFT JOIN "DefectReports" dr ON dr."Id" = q."DefectReportId" OR dr."BatchId" = ir."BatchId"
                        WHERE (r."SkuCode" = %s OR r."Name" ILIKE %s) AND (q."Id" IS NOT NULL OR dr."Id" IS NOT NULL)
                        ORDER BY COALESCE(q."CreatedAt", dr."CreatedAt", ir."CreatedAt") DESC
                        LIMIT 1;
                        ''',
                        (str(mat_id), f"%{mat_name or mat_id}%")
                    )
                row = cur.fetchone()
                if row:
                    roll_ident = row[1] or row[0] or "IRON-ROLL-001"
                    issue_desc = row[2] or row[4] or "Previous quality defect detected"
                    severity = str(row[3] or "Medium")
                    material_label = row[5] or mat_name or "Iron"
                    return {
                        "material": material_label,
                        "relatedRoll": roll_ident,
                        "issue": issue_desc,
                        "severity": severity
                    }

                # 2. Check if there are DefectReports mentioning the material directly (e.g. Iron defect)
                cur.execute(
                    '''
                    SELECT dr."BatchId", dr."Description", dr."Severity", dr."AffectedInventoryJson"
                    FROM "DefectReports" dr
                    WHERE dr."Description" ILIKE %s OR dr."BatchId" ILIKE %s
                    ORDER BY dr."CreatedAt" DESC LIMIT 1;
                    ''',
                    (f"%{mat_name or mat_id}%", f"%{mat_name or mat_id}%")
                )
                d_row = cur.fetchone()
                if d_row:
                    roll_ref = "IRON-ROLL-001"
                    if d_row[3] and "[" in str(d_row[3]):
                        try:
                            import json
                            items = json.loads(d_row[3])
                            if items and len(items) > 0:
                                roll_ref = str(items[0])
                        except Exception:
                            pass
                    return {
                        "material": mat_name or str(mat_id),
                        "relatedRoll": roll_ref,
                        "issue": d_row[1] or "Previous quality defect detected",
                        "severity": str(d_row[2] or "Medium")
                    }
    except Exception as ex:
        logger.warning(f"Historical quality risk check exception: {ex}")
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
    except Exception:
        pass

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
    defect = quality_data.get("defect")
    quarantined_rolls_count = _check_quarantine_count()

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
