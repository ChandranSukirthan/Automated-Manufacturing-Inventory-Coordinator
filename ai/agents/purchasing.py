from typing import Dict, Any
from core.state import AgentState, WorkflowStatus


def purchasing_node(state: AgentState) -> Dict[str, Any]:
    """
    Purchasing Agent Node:
    Assesses supplier availability and creates a draft purchase order.
    Strict restriction: Does NOT execute payments or send emails.
    Failure handling: If supplier is unavailable, requests revision or halts.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))

    inv_data = state.get("inventory_data", {})
    prod_data = state.get("production_data", {})

    # Evaluate supplier availability
    supplier = {
        "supplierId": "SUP-8802",
        "name": "Apex Polymer Solutions Ltd",
        "isAvailable": True,
        "leadTimeDays": 3,
        "unitPriceUsd": 1.45,
        "minimumOrderQuantity": 2000
    }

    if not supplier.get("isAvailable"):
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "errors": errors + ["Primary supplier unavailable for BoxPouch film."],
            "final_outcome": "Halted: Supplier unavailable. Revision requested."
        }

    needed_material = 4000
    total_cost = needed_material * supplier["unitPriceUsd"]

    draft_po = {
        "poNumber": "PO-DRAFT-2026-004",
        "supplier": supplier["name"],
        "itemCode": inv_data.get("itemCode", "BP-FILM-001"),
        "quantity": needed_material,
        "unit": inv_data.get("unit", "meters"),
        "estimatedCostUsd": total_cost,
        "paymentStatus": "UNPAID", # Strict constraint: Planner/AI must NOT pay
        "emailSent": False,        # Strict constraint: Planner/AI must NOT send email
        "requiresApproval": True
    }

    completed.append("Purchasing: Formulated draft purchase order (PO-DRAFT-2026-004)")

    return {
        "current_agent": "Purchasing",
        "purchasing_data": {
            "supplier": supplier,
            "draft_po": draft_po
        },
        "completed_steps": completed,
        "errors": errors
    }

