from typing import Dict, Any, List, Optional
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.purchasing_tools import (
    calculate_purchase_quantity,
    search_external_supplier_market,
    query_internal_supplier_data,
    validate_supplier_candidate,
    select_supplier,
    calculate_total_cost,
    create_draft_po,
)


def purchasing_node(state: AgentState) -> Dict[str, Any]:
    """
    Goal-Based Purchasing Agent Node (Student 2 / Supply Chain Manager):
    1. Ingests structured procurement requirement or production/inventory telemetry.
    2. Calculates net deficit using deterministic formula and adjusts for MOQ / pack size.
    3. Researches online raw-material suppliers using Gemini Search Grounding (with prompt injection defense).
    4. Queries internal enterprise PostgreSQL database for approved suppliers and contracts.
    5. Evaluates quality evidence (ISO, ASTM, Mill certs; marks UNKNOWN if missing, never fabricates).
    6. Filters candidates using 8 mandatory constraints and performs multi-attribute selection.
    7. Computes authoritative total cost deterministically.
    8. Formulates Draft PO with strict invariants (UNPAID, emailSent=False, requiresApproval=True).
    9. Hands off validated recommendation to Validation/Safety Agent.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_call_log = list(state.get("tool_call_log", []))

    # 1. Ingest structured material requirement
    proc_req = state.get("procurement_requirement") or {}
    inv_data = state.get("inventory_data") or {}
    prod_data = state.get("production_data") or {}

    material_name = (
        proc_req.get("materialName")
        or inv_data.get("itemName")
        or "BoxPouch Film"
    )
    specification = (
        proc_req.get("requiredSpecification")
        or inv_data.get("itemCode")
        or "BP-FILM-001"
    )
    production_requirement = float(
        proc_req.get("productionRequirement")
        or prod_data.get("schedule", {}).get("plannedOutput")
        or 4000.0
    )
    safety_stock = float(
        proc_req.get("safetyStock")
        or inv_data.get("reorderThreshold")
        or 1000.0
    )
    current_stock = float(
        proc_req.get("currentStock")
        or inv_data.get("availableQuantity")
        or 1000.0
    )
    open_po_quantity = float(
        proc_req.get("existingOpenPoQuantity", 0.0)
    )
    max_budget = float(
        proc_req.get("maximumBudget", 20000.0)
    )
    quality_req = proc_req.get("qualityRequirement", "ISO 9001")
    preferred_region = proc_req.get("preferredRegion", "Global")
    required_by_date = proc_req.get("requiredByDate")

    # 2. Deterministic quantity calculation (Net Deficit + MOQ + Pack Size)
    qty_result = calculate_purchase_quantity(
        production_requirement=production_requirement,
        safety_stock=safety_stock,
        current_stock=current_stock,
        open_po_quantity=open_po_quantity
    )
    required_quantity = qty_result["adjustedQuantity"]
    tool_call_log.append({"tool": "calculate_purchase_quantity", "result": qty_result})
    completed.append(f"Purchasing: Calculated net deficit requirement: {required_quantity} units")

    if not qty_result["purchaseRequired"] and required_quantity <= 0:
        return {
            "current_agent": "Purchasing",
            "final_decision": "NO_PURCHASE_NEEDED",
            "required_quantity": 0.0,
            "total_cost": 0.0,
            "requires_approval": False,
            "purchasing_data": {
                "message": "Inventory levels are sufficient. No replenishment required."
            },
            "completed_steps": completed + ["Purchasing: Inventory sufficient - no procurement needed"],
            "errors": errors,
            "tool_call_log": tool_call_log
        }

    # 3. Research external supplier market via Gemini Search Grounding
    market_candidates = search_external_supplier_market(
        material_name=material_name,
        specification=specification,
        required_quantity=required_quantity,
        quality_requirement=quality_req,
        maximum_budget=max_budget,
        preferred_region=preferred_region,
        required_by_date=required_by_date
    )
    tool_call_log.append({"tool": "search_external_supplier_market", "count": len(market_candidates)})
    completed.append(f"Purchasing: Researched external market via Gemini Search Grounding ({len(market_candidates)} candidates)")

    # 4. Query internal supplier information
    internal_suppliers = query_internal_supplier_data(material_name=material_name)
    tool_call_log.append({"tool": "query_internal_supplier_data", "count": len(internal_suppliers)})
    completed.append(f"Purchasing: Queried internal supplier database ({len(internal_suppliers)} approved suppliers)")

    # Cross-reference candidates: match approved suppliers from internal DB
    approved_names = {
        s["supplierName"].strip().lower()
        for s in internal_suppliers
        if s.get("supplierStatus") == "APPROVED" or s.get("isActive")
    }

    candidates_to_evaluate = []
    for cand in market_candidates:
        c_copy = dict(cand)
        if c_copy["supplierName"].strip().lower() in approved_names:
            c_copy["supplierStatus"] = "APPROVED"
        else:
            c_copy["supplierStatus"] = "UNVERIFIED"
        candidates_to_evaluate.append(c_copy)

    # 5. Validate candidates against 8 mandatory constraints
    validation_req = {
        "materialName": material_name,
        "requiredSpecification": specification,
        "requiredQuantity": required_quantity,
        "maximumBudget": max_budget,
        "requiredByDate": required_by_date
    }

    validated_candidates = []
    for cand in candidates_to_evaluate:
        report = validate_supplier_candidate(cand, validation_req)
        validated_candidates.append((cand, report))

    # 6. Compare and select top candidate
    selection = select_supplier(validated_candidates, validation_req)
    tool_call_log.append({"tool": "select_supplier", "status": selection["status"]})

    if selection["status"] != "RECOMMENDATION_READY" or not selection.get("selectedCandidate"):
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "final_decision": "NO_VALID_SUPPLIER",
            "errors": errors + [selection.get("message", "No valid supplier candidate found.")],
            "final_outcome": f"Halted: No valid supplier candidate found. {selection.get('message')}",
            "purchasing_data": {
                "rejectedCandidates": selection.get("rejectedCandidates", [])
            },
            "completed_steps": completed + ["Purchasing: Rejection - no candidates satisfied all validation constraints"],
            "tool_call_log": tool_call_log
        }

    selected_cand = selection["selectedCandidate"]
    unit_price = float(selected_cand.get("unitPrice", 1.45))

    # 7. Deterministic total cost calculation
    cost_calc = calculate_total_cost(quantity=required_quantity, unit_price=unit_price)
    total_cost = cost_calc["totalCost"]
    tool_call_log.append({"tool": "calculate_total_cost", "result": cost_calc})

    if cost_calc.get("priceStatus") == "CONFLICTING":
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "final_decision": "PRICE_CONFLICT",
            "errors": errors + [cost_calc.get("message", "Conflicting price quotes detected.")],
            "final_outcome": "Halted: Conflicting price quotes detected. Requires human review.",
            "completed_steps": completed,
            "tool_call_log": tool_call_log
        }

    # 8. Create Draft PO with strict safety invariants
    draft_po = create_draft_po(
        selected_candidate=selected_cand,
        quantity=required_quantity,
        unit_price=unit_price,
        total_cost=total_cost,
        item_code=specification
    )

    completed.append(
        f"Purchasing: Selected {selected_cand['supplierName']} for {required_quantity} units "
        f"(${total_cost:,.2f} USD). Draft PO formulated: {draft_po['poNumber']}"
    )

    # 9. Structure purchasing data & send result to Validation/Safety Agent
    purchasing_data = {
        "supplier": selected_cand,
        "recommendation": selected_cand,
        "draft_po": draft_po,
        "purchase_order": {
            "supplier": draft_po["supplier"],
            "quantity": draft_po["quantity"],
            "budget": draft_po["estimatedCostUsd"],
            "unitPrice": draft_po["unitPrice"]
        },
        "alternatives": selection.get("alternatives", []),
        "rejectedCandidates": selection.get("rejectedCandidates", []),
        "selectionReasons": selection.get("selectionReasons", []),
        "validationSummary": selection.get("validationReport", {}),
        "sources": [
            {
                "supplierName": c.get("supplierName"),
                "sourceUrl": c.get("sourceUrl"),
                "sourceTitle": c.get("sourceTitle")
            }
            for c in market_candidates if c.get("sourceUrl")
        ]
    }

    return {
        "current_agent": "Purchasing",
        "final_decision": "RECOMMENDATION_READY",
        "required_quantity": required_quantity,
        "total_cost": total_cost,
        "requires_approval": True,
        "purchasing_data": purchasing_data,
        "completed_steps": completed,
        "errors": errors,
        "tool_call_log": tool_call_log
    }


