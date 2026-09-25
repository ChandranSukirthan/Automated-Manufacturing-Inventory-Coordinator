"""
Purchasing Agent Module
Component: Student 2 / Supply Chain Manager.

Goal:
"Find a suitable raw-material supplier and procurement option using internal business data
and current external supplier research, then produce a validated Draft PO proposal for human review."

Full 13-Step Workflow:
1. Receive structured material requirement.
2. Receive calculated net deficit.
3. Research relevant suppliers/products.
4. Use Gemini Search Grounding for online research.
5. Extract structured supplier candidates.
6. Query internal supplier information.
7. Compare candidates.
8. Determine suitable quantity using deterministic rules.
9. Evaluate quality evidence.
10. Calculate total cost.
11. Recommend suitable candidate.
12. Prepare Draft PO data.
13. Send result to Validation/Safety.
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
    validate_candidate_schema,
)

logger = logging.getLogger("amic_agentic_ai.purchasing")


def purchasing_node(state: AgentState) -> Dict[str, Any]:
    """
    Goal-Based Purchasing Agent Node (Student 2 / Supply Chain Manager).
    Coordinates external Gemini search grounding, internal supplier DB lookup,
    deterministic MOQ/pack-size arithmetic, and produces a controlled Draft PO proposal.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_log = list(state.get("tool_call_log", []))

    # -------------------------------------------------------------------------
    # Step 1 & 2: Receive structured material requirement & authoritative deficit
    # -------------------------------------------------------------------------
    req = dict(state.get("procurement_requirement", {}))
    inv = dict(state.get("inventory_data", {}))
    prod = dict(state.get("production_data", {}))

    material_name = (
        req.get("materialName")
        or req.get("material")
        or inv.get("itemName")
        or "BoxPouch Film"
    )
    specification = (
        req.get("requiredSpecification")
        or req.get("specification")
        or inv.get("itemCode")
        or "BP-FILM-001"
    )
    quality_req = (
        req.get("qualityRequirement")
        or "ISO 9001"
    )
    max_budget = float(
        req.get("maximumBudget")
        or 20000.0
    )
    preferred_region = req.get("preferredRegion") or "Global"
    required_by_date = req.get("requiredByDate")

    # Authoritative net deficit calculation
    prod_req = float(req.get("productionRequirement") or prod.get("schedule", {}).get("plannedOutput", 4000.0))
    safety_stock = float(req.get("safetyStock", 1000.0))
    current_stock = float(req.get("currentStock", inv.get("availableQuantity", 1000.0)))
    open_po_qty = float(req.get("existingOpenPoQuantity", 0.0))

    explicit_deficit = req.get("netDeficit") or req.get("requiredQuantity")
    qty_calc = calculate_purchase_quantity(
        production_requirement=prod_req,
        safety_stock=safety_stock,
        current_stock=current_stock,
        open_po_quantity=open_po_qty,
        moq=0.0,
        pack_size=1.0,
        net_deficit=float(explicit_deficit) if explicit_deficit is not None else None,
    )
    net_deficit = qty_calc["netDeficit"]

    tool_log.append({
        "tool": "calculate_purchase_quantity",
        "inputs": {"net_deficit": net_deficit},
        "output": {"netDeficit": net_deficit},
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    completed.append(f"Purchasing: Authoritative net deficit calculated ({net_deficit:,.1f} units)")

    # -------------------------------------------------------------------------
    # Step 3, 4 & 5: Online Market Research via Gemini Search Grounding
    # -------------------------------------------------------------------------
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
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    completed.append(f"Purchasing: Discovered {len(market_candidates)} online supplier candidate(s) via market research")

    # -------------------------------------------------------------------------
    # Step 6: Query Internal Approved Supplier Database
    # -------------------------------------------------------------------------
    internal_suppliers = query_internal_supplier_data(material_name=material_name)
    tool_log.append({
        "tool": "query_internal_supplier_data",
        "activeSuppliersFound": len(internal_suppliers),
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    completed.append(f"Purchasing: Queried internal database ({len(internal_suppliers)} approved supplier(s))")

    # Adapt internal suppliers to supplier candidate format
    all_candidates: List[Dict[str, Any]] = []
    now_iso = datetime.now(timezone.utc).isoformat()

    for s in internal_suppliers:
        cand = {
            "supplierId": s.get("supplierId"),
            "supplierName": s.get("supplierName", "Internal Approved Supplier"),
            "origin": "Internal",
            "productName": f"Approved {material_name}",
            "material": material_name,
            "materialName": material_name,
            "specification": specification,
            "unitPrice": float(s.get("unitPrice", 1.45)),
            "currency": "USD",
            "unit": inv.get("unit", "meters"),
            "minimumOrderQuantity": float(s.get("minimumOrderQuantity", 500.0)),
            "packSize": float(s.get("packSize", 50.0)),
            "availableQuantity": float(s.get("availableQuantity", max(net_deficit * 2, 5000.0))),
            "leadTimeDays": int(s.get("leadTimeDays", 3)),
            "qualityEvidence": "ISO 9001 Certified (Internal contract verified)",
            "certifications": ["ISO 9001"],
            "availabilityStatus": "AVAILABLE",
            "supplierStatus": "APPROVED",
            "sourceUrl": f"internal://database/suppliers/{s.get('supplierId', 1)}",
            "sourceTitle": "Internal Manufacturing ERP Supplier Registry",
            "retrievedAt": now_iso,
        }
        all_candidates.append(cand)

    # Append external market candidates (strictly marked UNVERIFIED)
    for c in market_candidates:
        c_copy = dict(c)
        c_copy["supplierStatus"] = "UNVERIFIED"
        all_candidates.append(c_copy)

    # -------------------------------------------------------------------------
    # Step 7, 8, 9 & 10: Candidate Validation, Deterministic Quantity & Cost
    # -------------------------------------------------------------------------
    eval_requirement = {
        "materialName": material_name,
        "requiredSpecification": specification,
        "requiredQuantity": net_deficit,
        "maximumBudget": max_budget,
        "requiredByDate": required_by_date,
    }

    validated_pairs = []
    for cand in all_candidates:
        # Step 8: Adjust quantity for MOQ, pack size, availability
        qty_info = calculate_purchase_quantity(
            net_deficit=net_deficit,
            moq=cand.get("minimumOrderQuantity", 0.0),
            pack_size=cand.get("packSize", 1.0),
            available_quantity=cand.get("availableQuantity"),
        )
        cand_adjusted_qty = qty_info["recommendedQuantity"]

        # Step 10: Calculate total cost deterministically
        cost_info = calculate_total_cost(
            quantity=cand_adjusted_qty,
            unit_price=cand.get("unitPrice", 1.50)
        )

        val_report = validate_supplier_candidate(cand, eval_requirement)
        val_report["adjustedQuantity"] = cand_adjusted_qty
        val_report["recommendedQuantity"] = cand_adjusted_qty
        val_report["totalCost"] = cost_info["totalCost"]

        # Step 9: Re-verify quality evidence
        q_ev = cand.get("qualityEvidence", "").strip()
        if not q_ev or q_ev.upper() in ["NONE", "UNKNOWN", "N/A"]:
            val_report["qualityStatus"] = "UNKNOWN"
            val_report["isValid"] = False
            if "Insufficient quality certification evidence." not in val_report["rejectionReasons"]:
                val_report["rejectionReasons"].append("Insufficient quality certification evidence.")

        validated_pairs.append((cand, val_report))

    # -------------------------------------------------------------------------
    # Step 11: Compare & Transparently Select Top Candidate
    # -------------------------------------------------------------------------
    selection = select_supplier(validated_pairs, eval_requirement)
    status_decision = selection.get("status", "NO_VALID_SUPPLIER")

    if status_decision == "NO_VALID_SUPPLIER" or not selection.get("selectedCandidate"):
        errors.append("No supplier satisfied all mandatory constraints.")
        completed.append("Purchasing: Candidate evaluation halted — no viable supplier passed constraints")
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "final_decision": "FAILED",
            "required_quantity": net_deficit,
            "total_cost": 0.0,
            "purchasing_data": {
                "recommendation": None,
                "alternatives": selection.get("alternatives", []),
                "rejectedCandidates": selection.get("rejectedCandidates", []),
                "validationSummary": selection.get("validationSummary", {}),
                "sources": selection.get("sources", []),
                "requiresHumanApproval": False,
                "suppliers": all_candidates,
            },
            "completed_steps": completed,
            "errors": errors,
            "tool_call_log": tool_log,
        }

    top_cand = selection["selectedCandidate"]
    top_report = selection["validationReport"]
    recommended_qty = top_report["adjustedQuantity"]
    total_cost = top_report["totalCost"]

    # -------------------------------------------------------------------------
    # Step 12: Prepare Draft Purchase Order with Strict Safety Invariants
    # -------------------------------------------------------------------------
    draft_po = create_draft_po(
        selected_candidate=top_cand,
        quantity=recommended_qty,
        unit_price=top_cand.get("unitPrice", 1.45),
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
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    completed.append(f"Purchasing: Formulated Draft PO ({draft_po['poNumber']}) for {top_cand.get('supplierName')}")

    # Step 13: Send Result to Validation / Safety Agent
    recommendation = {
        "supplier": top_cand.get("supplierName"),
        "product": top_cand.get("productName", top_cand.get("materialName")),
        "quantity": recommended_qty,
        "unitPrice": top_cand.get("unitPrice"),
        "totalCost": total_cost,
        "qualityStatus": top_report.get("qualityStatus", "VERIFIED"),
        "supplierStatus": top_cand.get("supplierStatus", "UNVERIFIED"),
    }

    purchasing_data = {
        "recommendation": recommendation,
        "alternatives": selection.get("alternatives", []),
        "rejectedCandidates": selection.get("rejectedCandidates", []),
        "validationSummary": selection.get("validationSummary", {}),
        "sources": selection.get("sources", []),
        "requiresHumanApproval": True,
        "supplier": {
            "supplierId": top_cand.get("supplierId", "SUP-8802"),
            "name": top_cand.get("supplierName"),
            "isAvailable": True,
            "leadTimeDays": top_cand.get("leadTimeDays", 3),
            "unitPriceUsd": top_cand.get("unitPrice", 1.45),
            "minimumOrderQuantity": top_cand.get("minimumOrderQuantity", 500),
        },
        "suppliers": all_candidates,
        "draft_po": draft_po,
        "netDeficit": net_deficit,
        "recommendedQuantity": recommended_qty,
    }

    return {
        "current_agent": "Purchasing",
        "status": WorkflowStatus.Running,
        "final_decision": "RECOMMENDATION_READY",
        "required_quantity": recommended_qty,
        "total_cost": total_cost,
        "purchasing_data": purchasing_data,
        "completed_steps": completed,
        "errors": errors,
        "tool_call_log": tool_log,
    }
