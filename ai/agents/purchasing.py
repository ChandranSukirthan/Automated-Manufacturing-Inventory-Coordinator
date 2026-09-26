"""
Purchasing Agent — Goal-Based Procurement
Main AI contribution: combines internal company data + external Gemini market research
to produce a validated supplier recommendation for human approval.

Architecture prepared for future learning-based procurement intelligence via
structured historical outcome storage (see ProcurementOutcome model).
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ai.core.state import AgentState, WorkflowStatus
from ai.tools.purchasing_tools import (
    search_external_supplier_market,
    calculate_purchase_quantity,
    calculate_total_cost,
    query_internal_supplier_data,
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

    Reads authoritative values from state (populated by ASP.NET Core via planner).
    Never invents net_deficit — uses the value provided by ASP.NET Core.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])
    tool_log = list(state.get("tool_call_log") or [])
    now_iso = datetime.now(timezone.utc).isoformat()

    # ── Step 1 & 2: Read authoritative procurement requirement ─────────────────
    # Primary source: top-level state fields (set by planner from ASP.NET input)
    # Fallback: legacy procurement_requirement dict
    req = dict(state.get("procurement_requirement") or {})

    material_name: str = (
        state.get("material_name")
        or req.get("materialName")
        or req.get("material")
        or state.get("inventory_data", {}).get("materialName")
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
        or "ISO 9001"
    )
    max_budget: float = float(
        state.get("budget_limit")
        or req.get("budgetLimit")
        or req.get("maximumBudget")
        or 20000.0
    )
    preferred_region: str = state.get("preferred_region") or req.get("preferredRegion") or "Global"
    required_by_date: Optional[str] = state.get("required_by_date") or req.get("requiredByDate")
    unit: str = state.get("unit") or req.get("unit") or "units"

    # ── Authoritative net deficit (NEVER invented by AI) ──────────────────────
    # ASP.NET Core calculates: netDeficit = requiredQty + safetyStock - currentStock - openPO
    explicit_deficit = (
        state.get("net_deficit")
        or req.get("netDeficit")
        or req.get("requiredQuantity")
    )

    qty_calc = calculate_purchase_quantity(
        production_requirement=float(state.get("required_quantity") or req.get("productionRequirement") or 0.0),
        safety_stock=float(state.get("safety_stock") or req.get("safetyStock") or 0.0),
        current_stock=float(state.get("current_stock") or req.get("currentStock") or 0.0),
        open_po_quantity=float(state.get("open_po_quantity") or req.get("openPOQuantity") or req.get("existingOpenPoQuantity") or 0.0),
        moq=0.0,
        pack_size=1.0,
        net_deficit=float(explicit_deficit) if explicit_deficit is not None else None,
    )
    net_deficit: float = qty_calc["netDeficit"]

    tool_log.append({
        "tool": "calculate_purchase_quantity",
        "inputs": {"explicit_deficit": explicit_deficit},
        "output": {"netDeficit": net_deficit},
        "timestamp": now_iso,
    })
    completed.append(f"Purchasing: Authoritative net deficit = {net_deficit:,.2f} {unit}")

    if net_deficit <= 0:
        completed.append("Purchasing: Net deficit is zero — no procurement required")
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Running,
            "net_deficit": net_deficit,
            "supplier_candidates": [],
            "recommended_supplier": None,
            "recommendation_summary": "No procurement required — current stock satisfies demand.",
            "completed_steps": completed,
            "errors": errors,
            "tool_call_log": tool_log,
            # legacy
            "purchasing_data": {"requiresHumanApproval": False, "netDeficit": 0},
        }

    # ── Step 3, 4 & 5: External market research via Gemini Search Grounding ────
    market_candidates = search_external_supplier_market(
        material_name=material_name,
        specification=specification,
        required_quantity=net_deficit,
        quality_requirement=quality_req,
        maximum_budget=max_budget,
        preferred_region=preferred_region,
        required_by_date=required_by_date,
    )
    tool_log.append({
        "tool": "search_external_supplier_market",
        "inputs": {"material": material_name, "quantity": net_deficit},
        "candidatesDiscovered": len(market_candidates),
        "timestamp": now_iso,
    })
    completed.append(f"Purchasing: Discovered {len(market_candidates)} external candidate(s) via Gemini market research")

    # ── Step 6: Query internal approved supplier database ─────────────────────
    internal_suppliers = query_internal_supplier_data(material_name=material_name)
    tool_log.append({
        "tool": "query_internal_supplier_data",
        "activeSuppliersFound": len(internal_suppliers),
        "timestamp": now_iso,
    })
    completed.append(f"Purchasing: Queried internal database — {len(internal_suppliers)} approved supplier(s)")

    # Build unified candidate list
    all_candidates: List[Dict[str, Any]] = []

    for s in internal_suppliers:
        cand: Dict[str, Any] = {
            "supplierId": s.get("supplierId"),
            "supplierName": s.get("supplierName", "Internal Approved Supplier"),
            "origin": "Internal",
            "productName": f"Approved {material_name}",
            "material": material_name,
            "materialName": material_name,
            "specification": specification,
            "unitPrice": float(s.get("unitPrice") or s.get("unitPriceUsd") or 1.45),
            "currency": "USD",
            "unit": unit,
            "minimumOrderQuantity": float(s.get("minimumOrderQuantity") or 500.0),
            "packSize": float(s.get("packSize") or 50.0),
            "availableQuantity": float(s.get("availableQuantity") or max(net_deficit * 2, 5000.0)),
            "leadTimeDays": int(s.get("leadTimeDays") or 3),
            "qualityEvidence": "ISO 9001 Certified (Internal contract verified)",
            "certifications": ["ISO 9001"],
            "availabilityStatus": "AVAILABLE",
            "supplierStatus": "APPROVED",
            "verificationStatus": "VERIFIED",
            "qualityEvidenceStatus": "AVAILABLE",
            "sourceUrl": f"internal://database/suppliers/{s.get('supplierId', 1)}",
            "sourceTitle": "Internal Manufacturing ERP Supplier Registry",
            "retrievedAt": now_iso,
        }
        all_candidates.append(cand)

    for c in market_candidates:
        c_copy = dict(c)
        c_copy["supplierStatus"] = "UNVERIFIED"
        c_copy["verificationStatus"] = "UNVERIFIED"
        # Normalise quality evidence status
        qe = str(c_copy.get("qualityEvidence") or "").strip()
        c_copy["qualityEvidenceStatus"] = "AVAILABLE" if qe and qe.upper() not in ("UNKNOWN", "NONE", "N/A") else "UNKNOWN"
        all_candidates.append(c_copy)

    # ── Step 7, 8, 9 & 10: Validate, adjust quantity, evaluate quality, cost ──
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

        val_report = validate_supplier_candidate(cand, eval_requirement)
        val_report["adjustedQuantity"] = cand_qty
        val_report["recommendedQuantity"] = cand_qty
        val_report["totalCost"] = cost_info["totalCost"]

        # Quality evidence check
        qe = str(cand.get("qualityEvidence") or "").strip()
        if not qe or qe.upper() in ("NONE", "UNKNOWN", "N/A"):
            val_report["qualityStatus"] = "UNKNOWN"
            val_report["isValid"] = False
            if "Insufficient quality certification evidence." not in val_report["rejectionReasons"]:
                val_report["rejectionReasons"].append("Insufficient quality certification evidence.")

        validated_pairs.append((cand, val_report))

    # ── Step 11: Compare and select top candidate ──────────────────────────────
    selection = select_supplier(validated_pairs, eval_requirement)
    status_decision = selection.get("status", "NO_VALID_SUPPLIER")

    # Build normalised supplier candidates list for output
    supplier_candidates_out: List[Dict[str, Any]] = []
    for cand, report in validated_pairs:
        supplier_candidates_out.append({
            "supplierName": cand.get("supplierName"),
            "materialName": cand.get("materialName"),
            "origin": cand.get("origin"),
            "unitPrice": cand.get("unitPrice"),
            "currency": cand.get("currency", "USD"),
            "moq": cand.get("minimumOrderQuantity"),
            "packSize": cand.get("packSize"),
            "availability": cand.get("availabilityStatus", "UNKNOWN"),
            "leadTime": f"{cand.get('leadTimeDays', '?')} days",
            "qualityEvidence": cand.get("qualityEvidence", "UNKNOWN"),
            "qualityEvidenceStatus": cand.get("qualityEvidenceStatus", "UNKNOWN"),
            "sourceUrl": cand.get("sourceUrl"),
            "sourceTitle": cand.get("sourceTitle"),
            "verificationStatus": cand.get("verificationStatus", "UNVERIFIED"),
            "recommendedQuantity": report.get("recommendedQuantity"),
            "totalCost": report.get("totalCost"),
            "isValid": report.get("isValid"),
            "rejectionReasons": report.get("rejectionReasons", []),
        })

    if status_decision == "NO_VALID_SUPPLIER" or not selection.get("selectedCandidate"):
        errors.append("No supplier satisfied all mandatory procurement constraints.")
        completed.append("Purchasing: No viable supplier passed all validation rules")
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "net_deficit": net_deficit,
            "supplier_candidates": supplier_candidates_out,
            "recommended_supplier": None,
            "recommendation_summary": "No supplier candidates satisfied all mandatory constraints.",
            "risks": ["No verified supplier available for this material"],
            "sources": [],
            "completed_steps": completed,
            "errors": errors,
            "tool_call_log": tool_log,
            "final_outcome": "FAILED",
            # legacy
            "purchasing_data": {
                "requiresHumanApproval": False,
                "netDeficit": net_deficit,
                "suppliers": all_candidates,
            },
        }

    top_cand = selection["selectedCandidate"]
    top_report = selection["validationReport"]
    recommended_qty = top_report["adjustedQuantity"]
    total_cost = top_report["totalCost"]

    # ── Step 12: Prepare Draft PO (strict invariants: UNPAID, no email) ────────
    draft_po = create_draft_po(
        selected_candidate=top_cand,
        quantity=recommended_qty,
        unit_price=top_cand.get("unitPrice") or 1.45,
        total_cost=total_cost,
        item_code=specification,
    )
    tool_log.append({
        "tool": "create_draft_po",
        "poNumber": draft_po["poNumber"],
        "supplier": draft_po["supplier"],
        "paymentStatus": draft_po["paymentStatus"],
        "emailSent": draft_po["emailSent"],
        "requiresApproval": draft_po["requiresApproval"],
        "timestamp": now_iso,
    })
    completed.append(
        f"Purchasing: Draft PO {draft_po['poNumber']} prepared for {top_cand.get('supplierName')}"
    )

    # Quality evidence list
    quality_evidence_out: List[Dict[str, Any]] = [{
        "supplier": top_cand.get("supplierName"),
        "evidence": top_cand.get("qualityEvidence", "UNKNOWN"),
        "certifications": top_cand.get("certifications", []),
        "status": top_report.get("qualityStatus", "UNKNOWN"),
    }]

    # Risks
    risks: List[str] = []
    if top_cand.get("verificationStatus") == "UNVERIFIED":
        risks.append("Recommended supplier is UNVERIFIED — requires manager onboarding before PO dispatch")
    if top_report.get("qualityStatus") == "UNKNOWN":
        risks.append("Quality evidence is UNKNOWN — manager should request certification before approval")
    for alt_name in selection.get("alternatives", []):
        risks.append(f"Alternative supplier available: {alt_name}")

    # Sources
    sources = [c.get("sourceUrl") for c in all_candidates if c.get("sourceUrl")]

    recommendation_summary = (
        f"Recommended supplier: {top_cand.get('supplierName')} "
        f"({top_cand.get('verificationStatus', 'UNVERIFIED')}). "
        f"Quantity: {recommended_qty:,.0f} {unit} @ ${top_cand.get('unitPrice'):.2f}/{unit}. "
        f"Estimated total: ${total_cost:,.2f}. "
        f"Lead time: {top_cand.get('leadTimeDays')} days. "
        f"Quality: {top_report.get('qualityStatus', 'UNKNOWN')}."
    )

    # ── Step 13: Structured output for Validation Agent ───────────────────────
    return {
        "current_agent": "Purchasing",
        "status": WorkflowStatus.Running,
        "net_deficit": net_deficit,
        "supplier_candidates": supplier_candidates_out,
        "recommended_supplier": {
            "supplierName": top_cand.get("supplierName"),
            "materialName": top_cand.get("materialName"),
            "origin": top_cand.get("origin"),
            "unitPrice": top_cand.get("unitPrice"),
            "currency": top_cand.get("currency", "USD"),
            "moq": top_cand.get("minimumOrderQuantity"),
            "packSize": top_cand.get("packSize"),
            "availability": top_cand.get("availabilityStatus"),
            "leadTime": f"{top_cand.get('leadTimeDays')} days",
            "qualityEvidence": top_cand.get("qualityEvidence"),
            "qualityEvidenceStatus": top_cand.get("qualityEvidenceStatus", "AVAILABLE"),
            "sourceUrl": top_cand.get("sourceUrl"),
            "sourceTitle": top_cand.get("sourceTitle"),
            "verificationStatus": top_cand.get("verificationStatus", "UNVERIFIED"),
        },
        "alternative_suppliers": selection.get("alternatives", []),
        "recommended_quantity": recommended_qty,
        "estimated_unit_price": top_cand.get("unitPrice"),
        "estimated_total_cost": total_cost,
        "quality_evidence": quality_evidence_out,
        "supplier_verification": top_cand.get("verificationStatus", "UNVERIFIED"),
        "recommendation_summary": recommendation_summary,
        "risks": risks,
        "sources": sources,
        "draft_po": draft_po,
        "completed_steps": completed,
        "errors": errors,
        "tool_call_log": tool_log,
        # legacy compatibility
        "purchasing_data": {
            "recommendation": {
                "supplier": top_cand.get("supplierName"),
                "quantity": recommended_qty,
                "unitPrice": top_cand.get("unitPrice"),
                "totalCost": total_cost,
                "qualityStatus": top_report.get("qualityStatus"),
                "supplierStatus": top_cand.get("supplierStatus"),
            },
            "alternatives": selection.get("alternatives", []),
            "rejectedCandidates": selection.get("rejectedCandidates", []),
            "sources": sources,
            "requiresHumanApproval": True,
            "suppliers": all_candidates,
            "draft_po": draft_po,
            "netDeficit": net_deficit,
            "recommendedQuantity": recommended_qty,
        },
        "required_quantity": recommended_qty,
        "total_cost": total_cost,
        "final_decision": "RECOMMENDATION_READY",
    }
