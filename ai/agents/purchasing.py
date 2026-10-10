"""
Purchasing Agent — Goal-Based Procurement
Main AI contribution: combines internal company data + external Gemini market research
to produce a validated supplier recommendation for human approval.

Architecture prepared for future learning-based procurement intelligence via
structured historical outcome storage (see ProcurementOutcome model).
"""
from __future__ import annotations
from ai.core.config import settings

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ai.core.state import AgentState, WorkflowStatus
from ai.core.contracts import first_present
from ai.core.validation_contract import finite_number
from ai.tools.purchasing_tools import (
    search_external_supplier_market,
    calculate_purchase_quantity,
    calculate_total_cost,
    query_internal_supplier_data,
    query_supplier_rates,
    validate_supplier_candidate,
    select_supplier,
    create_draft_po,
)

logger = logging.getLogger("amic_agentic_ai.purchasing")


def purchasing_node(state: AgentState) -> Dict[str, Any]:
    """
    Goal-Based Purchasing Agent Node.

    Goal: "Find a suitable procurement solution for the required material while
    satisfying quantity, price, quality, supplier, availability, budget, and
    safety constraints."

    Reads authoritative values from state (populated by ASP.NET Core via planner/data_extraction).
    Supports inter-agent cooperation with Production Analysis shortfall calculations.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])
    tool_log = list(state.get("tool_call_log") or [])
    tool_results = dict(state.get("tool_results") or {})
    now_iso = datetime.now(timezone.utc).isoformat()
    attempt = int(state.get("supplier_selection_attempt") or 0) + 1
    max_attempts = 3
    if attempt > max_attempts:
        raise ValueError("Three supplier attempts have been used; start a new reviewed request")
    excluded_supplier_ids = {
        str(value) for value in (state.get("excluded_supplier_ids") or []) if value is not None
    }

    # If draft_po is already provided (e.g., verifying an existing manual PO), preserve it
    existing_purchasing = dict(state.get("purchasing_data", {}))
    if (existing_purchasing.get("draft_po") and not state.get("revision_request")
            and not state.get("automatic_retry_required")):
        draft_po = existing_purchasing["draft_po"]
        po_num = draft_po.get("poNumber", "PO-DRAFT")
        completed.append(f"Purchasing: Validating existing purchase order {po_num}")
        return {
            "current_agent": "Purchasing",
            "purchasing_data": existing_purchasing,
            "completed_steps": completed,
            "errors": errors
        }

    # ── Step 1 & 2: Read authoritative procurement requirement ─────────────────
    req = dict(state.get("procurement_requirement") or {})
    inv_data = dict(state.get("inventory_data") or {})
    prod_data = dict(state.get("production_data") or {})
    impact = prod_data.get("impact", {})

    material_id = (
        state.get("material_id")
        or inv_data.get("materialId")
        or inv_data.get("itemCode")
        or None
    )
    material_name: str = (
        state.get("material_name")
        or inv_data.get("materialName")
        or inv_data.get("itemName")
        or req.get("materialName")
        or req.get("material")
        or "Unknown Material"
    )
    specification: str = (
        state.get("specification")
        or req.get("requiredSpecification")
        or req.get("specification")
        or material_name
    )
    quality_req: str = (
        state.get("quality_requirement")
        or req.get("qualityRequirement")
        or ""
    )
    budget = first_present(state.get("budget_limit"), req.get("budgetLimit"), req.get("maximumBudget"))
    if not settings.demo_mode and (not material_id or budget is None or float(budget) <= 0):
        raise ValueError("An exact material and a positive authorized budget are required")
    max_budget = float(budget if budget is not None else 6000000.0)
    preferred_region: str = state.get("preferred_region") or req.get("preferredRegion") or "Sri Lanka"
    required_by_date: Optional[str] = state.get("required_by_date") or req.get("requiredByDate")
    unit: str = state.get("unit") or req.get("unit") or "units"

    # ── Authoritative net deficit ─────────────────────────────────────────────
    explicit_deficit = state.get("net_deficit") if state.get("net_deficit") is not None else req.get("netDeficit")
    production_requirement = first_present(state.get("required_quantity"), req.get("productionRequirement"),
        req.get("requiredQuantity"), inv_data.get("requiredQuantity"), explicit_deficit)
    if production_requirement is None and not settings.demo_mode:
        raise ValueError("An authoritative material requirement is required")
    prod_req = float(production_requirement if production_requirement is not None else 1000.0)
    safety = float(first_present(state.get("safety_stock"), req.get("safetyStock"), 0))
    current_stk = float(first_present(state.get("current_stock"), req.get("currentStock"), inv_data.get("currentStock"), 0))
    open_po = float(first_present(state.get("open_po_quantity"), req.get("openPOQuantity"), req.get("existingOpenPoQuantity"), 0))

    if state.get("trigger_type") == "Manual":
        explicit_deficit = finite_number(first_present(state.get("requested_quantity"), state.get("required_quantity")), "manual requested quantity", positive=True)

    qty_calc = calculate_purchase_quantity(
        production_requirement=prod_req,
        safety_stock=safety,
        current_stock=current_stk,
        open_po_quantity=open_po,
        moq=0.0,
        pack_size=1.0,
        net_deficit=explicit_deficit,
    )
    net_deficit = explicit_deficit if explicit_deficit is not None else qty_calc.get("recommendedQuantity", prod_req)
    if net_deficit <= 0:
        return {"current_agent": "Purchasing", "status": WorkflowStatus.Completed, "requires_approval": False,
                "net_deficit": 0, "draft_po": None, "completed_steps": completed + ["Purchasing: No material deficit; no order required"],
                "final_outcome": "No purchase required for the authoritative material requirement."}

    # Production output and material quantity have different units. Never overwrite
    # the authoritative material deficit with a finished-product shortfall.

    tool_log.append({
        "tool": "calculate_purchase_quantity",
        "inputs": {"explicit_deficit": explicit_deficit, "calculated": net_deficit},
        "output": {"netDeficit": net_deficit},
        "timestamp": now_iso,
    })
    completed.append(f"Purchasing: Authoritative net deficit = {net_deficit:,.2f} {unit}")

    # ── Query available internal/catalog suppliers ─────────────────────────────
    raw_suppliers = query_supplier_rates(material_id)
    if isinstance(raw_suppliers, dict):
        available_suppliers = [raw_suppliers]
    elif isinstance(raw_suppliers, list):
        available_suppliers = [s for s in raw_suppliers if isinstance(s, dict)]
    else:
        available_suppliers = []

    # ── External market research via Gemini Search Grounding ──────────────────
    internal_suppliers = query_internal_supplier_data(material_name=material_id, material_label=material_name)
    market_candidates = search_external_supplier_market(
        material_name=material_name,
        specification=specification,
        required_quantity=net_deficit,
        quality_requirement=quality_req,
        maximum_budget=max_budget,
        preferred_region=preferred_region,
        required_by_date=required_by_date,
        revision_notes=state.get("revision_request"),
    ) if not internal_suppliers or state.get("revision_request") else []
    tool_log.append({
        "tool": "search_external_supplier_market",
        "inputs": {"material": material_name, "quantity": net_deficit},
        "candidatesDiscovered": len(market_candidates),
        "timestamp": now_iso,
    })
    completed.append(f"Purchasing: Discovered {len(market_candidates)} external candidate(s) via Gemini market research")

    # ── Internal approved suppliers ───────────────────────────────────────────
    all_candidates: List[Dict[str, Any]] = []

    for s in internal_suppliers:
        raw_code = str(s.get("supplierCode") or s.get("supplierId") or "")
        cand: Dict[str, Any] = {
            "supplierId": raw_code,
            "supplierName": s.get("supplierName"),
            "origin": "Internal",
            "productName": f"Approved {material_name}",
            "material": material_name,
            "materialName": material_name,
            "specification": specification,
            "unitPrice": float(s.get("unitPrice") or s.get("unitPriceUsd") or 0),
            "currency": s.get("currency", "LKR"),
            "unit": s.get("unit") or unit,
            "minimumOrderQuantity": float(s.get("minimumOrderQuantity", 0)),
            "packSize": float(s.get("packSize", 1)),
            "availableQuantity": float(s.get("availableQuantity", max(net_deficit * 2, 10000) if settings.demo_mode else 0)),
            "leadTimeDays": int(first_present(s.get("leadTimeDays"), 3 if settings.demo_mode else 0)),
            "qualityEvidence": s.get("qualityEvidence", "ISO 9001 Certified" if settings.demo_mode else "UNKNOWN"),
            "certifications": [],
            "availabilityStatus": "AVAILABLE" if s.get("availableQuantity") is not None or settings.demo_mode else "UNKNOWN",
            "supplierStatus": s.get("supplierStatus", "APPROVED" if settings.demo_mode else "UNVERIFIED"),
            "verificationStatus": s.get("verificationStatus", "VERIFIED" if settings.demo_mode else "UNVERIFIED"),
            "qualityEvidenceStatus": "AVAILABLE" if s.get("qualityEvidence") or settings.demo_mode else "UNKNOWN",
            "sourceUrl": f"internal://database/suppliers/{raw_code}",
            "sourceTitle": "Internal Manufacturing ERP Supplier Registry",
            "retrievedAt": now_iso,
        }
        all_candidates.append(cand)

    # Also add standard catalog suppliers from available_suppliers
    for cat in (available_suppliers if settings.demo_mode else []):
        if not isinstance(cat, dict):
            continue
        cat_name = cat.get("name") or cat.get("supplierName") or "Catalog Supplier"
        if not any(c.get("supplierName") == cat_name for c in all_candidates):
            all_candidates.append({
                "supplierId": str(cat.get("supplierId", "SUP-001")),
                "supplierName": cat_name,
                "origin": "Internal Catalog",
                "productName": f"Standard {material_name}",
                "material": material_name,
                "materialName": material_name,
                "specification": specification,
                "unitPrice": float(cat.get("pricePerUnit") or cat.get("unitPrice") or 1.45),
                "currency": "LKR",
                "unit": unit,
                "minimumOrderQuantity": float(cat.get("minOrderQuantity") or cat.get("minimumOrderQuantity") or 500.0),
                "packSize": 50.0,
                "availableQuantity": max(net_deficit * 2, 10000.0),
                "leadTimeDays": int(cat.get("leadTimeDays", 7)),
                "qualityEvidence": "ISO 9001 Certified",
                "certifications": ["ISO 9001"],
                "availabilityStatus": "AVAILABLE",
                "supplierStatus": "APPROVED",
                "verificationStatus": "VERIFIED",
                "qualityEvidenceStatus": "AVAILABLE",
                "sourceUrl": f"internal://catalog/{cat.get('supplierId', 'SUP-001')}",
                "sourceTitle": "Supplier Catalog",
                "retrievedAt": now_iso,
            })

    for c in market_candidates:
        c_copy = dict(c)
        c_copy["supplierStatus"] = "UNVERIFIED"
        c_copy["verificationStatus"] = "UNVERIFIED"
        qe = str(c_copy.get("qualityEvidence") or "").strip()
        c_copy["qualityEvidenceStatus"] = "AVAILABLE" if qe and qe.upper() not in ("UNKNOWN", "NONE", "N/A") else "UNKNOWN"
        all_candidates.append(c_copy)

    if excluded_supplier_ids:
        all_candidates = [
            candidate for candidate in all_candidates
            if str(candidate.get("supplierId")) not in excluded_supplier_ids
        ]
        completed.append(
            f"Purchasing: Attempt {attempt}/{max_attempts} excluded {len(excluded_supplier_ids)} supplier(s) rejected by Quality Validation"
        )

    completed.append(
        f"Purchasing: Attempt {attempt}/{max_attempts} comparing {len(all_candidates)} supplier quote(s) for {material_name}"
    )

    # ── Evaluate and validate candidates ──────────────────────────────────────
    eval_requirement = {
        "materialName": material_name,
        "requiredSpecification": specification,
        "requiredQuantity": net_deficit,
        "maximumBudget": max_budget,
        "requiredByDate": required_by_date,
    }

    validated_pairs = []
    for cand in all_candidates:
        qty_info = calculate_purchase_quantity(
            net_deficit=net_deficit,
            moq=cand.get("minimumOrderQuantity") or 0.0,
            pack_size=cand.get("packSize") or 1.0,
            available_quantity=cand.get("availableQuantity"),
        )
        cand_qty = qty_info["recommendedQuantity"]

        cost_info = calculate_total_cost(
            quantity=cand_qty,
            unit_price=cand.get("unitPrice") or 1.50,
        )

        # MOQ/pack rounding changes both cost and availability requirements.
        val_report = validate_supplier_candidate(cand, {**eval_requirement, "requiredQuantity": cand_qty})
        if str(cand.get("currency", "LKR")).upper() != str(req.get("currency", "LKR")).upper() or str(cand.get("unit", unit)).upper() != unit.upper():
            val_report["isValid"] = False
            val_report["rejectionReasons"].append("Quote currency or unit differs from the authorized request; conversion is required.")
        val_report["adjustedQuantity"] = cand_qty
        val_report["recommendedQuantity"] = cand_qty
        val_report["totalCost"] = cost_info["totalCost"]

        qe = str(cand.get("qualityEvidence") or "").strip()
        if not qe or qe.upper() in ("NONE", "UNKNOWN", "N/A"):
            val_report["qualityStatus"] = "UNKNOWN"
            val_report["isValid"] = False
            if "Insufficient quality certification evidence." not in val_report["rejectionReasons"]:
                val_report["rejectionReasons"].append("Insufficient quality certification evidence.")

        validated_pairs.append((cand, val_report))

    # ── Selection ─────────────────────────────────────────────────────────────
    selection = select_supplier(validated_pairs, eval_requirement)
    if not selection.get("selectedCandidate"):
        return {"current_agent": "Student 2 Supplier Selection", "status": WorkflowStatus.Failed,
                "requires_approval": False, "draft_po": None, "supplier_candidates": all_candidates,
                "supplier_selection_attempt": attempt,
                "max_supplier_selection_attempts": max_attempts,
                "automatic_retry_required": False,
                "validation_results": {"isValid": False, "overallStatus": "NO_VALID_SUPPLIER",
                                       "attemptNumber": attempt, "maxAttempts": max_attempts,
                                       "rejectionReason": "No eligible supplier quote passed the purchasing constraints."},
                "completed_steps": completed, "errors": errors + ["No suitable supplier quote is available. Add a verified quote or create a manual draft PO."],
                "final_outcome": "Supplier selection failed because no eligible quote passed the required stock, price, quality, and budget checks."}
    top_cand = selection.get("selectedCandidate") or (all_candidates[0] if all_candidates else {})
    top_report = selection.get("validationReport") or (validated_pairs[0][1] if validated_pairs else {})
    required_candidate_fields = ("supplierId", "supplierName", "unitPrice")
    if any(top_cand.get(field) in (None, "") for field in required_candidate_fields):
        raise ValueError("Selected supplier quote is missing its identity or unit price")
    recommended_qty = top_report["adjustedQuantity"]
    total_cost = top_report["totalCost"]

    # Chosen supplier format for test compatibility
    chosen_supplier = {
        "supplierId": top_cand["supplierId"],
        "name": top_cand["supplierName"],
        "pricePerUnit": float(top_cand["unitPrice"]),
        "leadTimeDays": int(top_cand.get("leadTimeDays") or 0),
        "minOrderQuantity": float(top_cand.get("minimumOrderQuantity") or 0),
        "isActive": top_cand.get("supplierStatus") == "APPROVED",
        "currency": top_cand.get("currency", "LKR"),
    }

    if inv_data.get("currentStock") is not None and inv_data.get("burnRate") is not None:
        from ai.tools.inventory_tools import detect_low_stock
        coverage = detect_low_stock.invoke({"materialId": material_id,
            "currentStock": inv_data["currentStock"], "minimumStock": inv_data.get("minimumStock", 0),
            "burnRate": inv_data["burnRate"], "supplierLeadTime": top_cand.get("leadTimeDays", 0)})
        inv_data.update({key: coverage[key] for key in ("lowStock", "daysRemaining", "severity", "reason")})
        tool_results["detect_low_stock_with_supplier"] = coverage

    # ── Create Draft PO ───────────────────────────────────────────────────────
    draft_po = create_draft_po(
        supplier_id=chosen_supplier["supplierId"],
        supplier_name=chosen_supplier["name"],
        material_id=material_id,
        quantity=recommended_qty,
        unit_price=chosen_supplier["pricePerUnit"],
        total_amount=total_cost,
        currency=chosen_supplier["currency"],
        budget_threshold=1500000.0 if chosen_supplier["currency"].upper() == "LKR" else 5000.0,
    )
    # Enrich with details for manager UI
    draft_po["itemCode"] = specification
    draft_po["materialName"] = material_name
    draft_po["estimatedCost"] = total_cost
    draft_po["totalCost"] = total_cost

    tool_log.append({
        "tool": "create_draft_po",
        "poNumber": draft_po["poNumber"],
        "supplier": draft_po["supplierName"],
        "paymentStatus": draft_po["paymentStatus"],
        "emailSent": draft_po["emailSent"],
        "requiresApproval": draft_po["requiresApproval"],
        "timestamp": now_iso,
    })

    # Exact string required by tests: "Purchasing: Selected <name> ($<price>/unit) and drafted <poNumber>"
    completed.append(
        f"Purchasing: Selected {chosen_supplier['name']} (${chosen_supplier['pricePerUnit']}/unit) and drafted {draft_po['poNumber']}"
    )

    # Normalised supplier candidates list for output
    supplier_candidates_out: List[Dict[str, Any]] = []
    for cand, report in validated_pairs:
        supplier_candidates_out.append({
            "supplierId": cand.get("supplierId"),
            "supplierName": cand.get("supplierName"),
            "materialName": cand.get("materialName"),
            "origin": cand.get("origin"),
            "unitPrice": cand.get("unitPrice"),
            "currency": cand.get("currency", "LKR"),
            "moq": cand.get("minimumOrderQuantity"),
            "packSize": cand.get("packSize"),
            "availability": cand.get("availabilityStatus", "UNKNOWN"),
            "availableQuantity": cand.get("availableQuantity"),
            "leadTimeDays": cand.get("leadTimeDays"),
            "leadTime": f"{cand.get('leadTimeDays', '?')} days",
            "qualityEvidence": cand.get("qualityEvidence", "UNKNOWN"),
            "qualityEvidenceStatus": cand.get("qualityEvidenceStatus", "UNKNOWN"),
            "sourceUrl": cand.get("sourceUrl"),
            "sourceTitle": cand.get("sourceTitle"),
            "supplierStatus": cand.get("supplierStatus", "UNVERIFIED"),
            "verificationStatus": cand.get("verificationStatus", "UNVERIFIED"),
            "recommendedQuantity": report.get("recommendedQuantity"),
            "totalCost": report.get("totalCost"),
            "isValid": report.get("isValid"),
            "rejectionReasons": report.get("rejectionReasons", []),
        })

    risks: List[str] = []
    if top_cand.get("verificationStatus") == "UNVERIFIED":
        risks.append("Recommended supplier is UNVERIFIED — requires manager onboarding before PO dispatch")
    for alt_name in selection.get("alternatives", []):
        risks.append(f"Alternative supplier available: {alt_name}")

    sources = [c.get("sourceUrl") for c in all_candidates if c.get("sourceUrl")]

    recommendation_summary = (
        f"Recommended supplier: {top_cand.get('supplierName')} "
        f"({top_cand.get('verificationStatus', 'UNVERIFIED')}). "
        f"Quantity: {recommended_qty:,.0f} {unit} @ ${top_cand['unitPrice']:.2f}/{unit}. "
        f"Estimated total: ${total_cost:,.2f}. "
        f"Lead time: {top_cand.get('leadTimeDays', 'unknown')} days."
    )

    purchasing_data = {
        "supplier": chosen_supplier,
        "draft_po": draft_po,
        "suppliers": all_candidates,
        "recommendation": {
            "supplier": chosen_supplier["name"],
            "product": top_cand.get("productName", material_name),
            "quantity": recommended_qty,
            "unitPrice": chosen_supplier["pricePerUnit"],
            "totalCost": total_cost,
            "qualityStatus": top_report.get("qualityStatus", "VERIFIED"),
            "supplierStatus": top_cand.get("supplierStatus", "APPROVED"),
        },
        "alternatives": selection.get("alternatives", []),
        "rejectedCandidates": selection.get("rejectedCandidates", []),
        "validationSummary": top_report,
        "sources": sources,
        "requiresHumanApproval": True,
        "netDeficit": net_deficit,
        "recommendedQuantity": recommended_qty,
        "selectionAttempt": attempt,
        "maxSelectionAttempts": max_attempts,
        "supplierComparison": sorted(
            supplier_candidates_out,
            key=lambda candidate: (
                not bool(candidate.get("isValid")),
                float(candidate.get("totalCost") or float("inf")),
                int(candidate.get("leadTimeDays") or 999),
            ),
        ),
    }

    return {
        "current_agent": "Student 2 Supplier Selection",
        "status": WorkflowStatus.Running,
        "supplier_selection_attempt": attempt,
        "max_supplier_selection_attempts": max_attempts,
        "automatic_retry_required": False,
        "validation_results": {key: value for key, value in (state.get("validation_results") or {}).items()
            if key in ("manualResolutionStatus", "manualResolutionNote", "resolvedBy", "resolvedAt", "historicalRisk", "defectFingerprint")},
        "net_deficit": state.get("net_deficit") if state.get("trigger_type") == "Manual" else net_deficit,
        "inventory_data": inv_data,
        "supplier_candidates": supplier_candidates_out,
        "recommended_supplier": top_cand,
        "alternative_suppliers": selection.get("alternatives", []),
        "recommended_quantity": recommended_qty,
        "estimated_unit_price": chosen_supplier["pricePerUnit"],
        "estimated_total_cost": total_cost,
        "quality_evidence": [{
            "supplier": top_cand.get("supplierName"),
            "evidence": top_cand.get("qualityEvidence", "UNKNOWN"),
            "certifications": top_cand.get("certifications", []),
            "status": top_report.get("qualityStatus", "VERIFIED"),
        }],
        "supplier_verification": top_cand.get("verificationStatus", "VERIFIED"),
        "recommendation_summary": recommendation_summary,
        "risks": risks,
        "sources": sources,
        "draft_po": draft_po,
        "purchasing_data": purchasing_data,
        "completed_steps": completed,
        "errors": errors,
        "tool_call_log": tool_log,
        "tool_results": tool_results,
        "required_quantity": prod_req,
        "total_cost": total_cost,
        "final_decision": "RECOMMENDATION_READY",
    }
