from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus


def purchasing_node(state: AgentState) -> Dict[str, Any]:
    """
    Purchasing Agent Node:
    Assesses supplier availability and creates a draft purchase order.
    Strict restriction: Does NOT execute payments or send emails.
    Failure handling: If supplier is unavailable, requests revision or halts.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))

    # Student 2: Purchasing Agent implements query_supplier_rates, select_supplier, calculate_total_cost, create_draft_po
    from ai.tools.purchasing_tools import (
        query_supplier_rates,
        select_supplier,
        calculate_total_cost,
        create_draft_po
    )

    inv_data = state.get("inventory_data", {})
    prod_data = state.get("production_data", {})

    material_id = inv_data.get("materialId") or inv_data.get("itemCode", "RM-STEEL-001")
    required_quantity = float(inv_data.get("requiredQuantity", 2000))

    # Tool 1: query_supplier_rates()
    available_suppliers = query_supplier_rates(material_id)

    # Tool 2: select_supplier()
    chosen_supplier = select_supplier(available_suppliers, required_quantity)

    # Tool 3: calculate_total_cost()
    cost_calc = calculate_total_cost(
        quantity=required_quantity,
        unit_price=chosen_supplier["pricePerUnit"],
        currency="USD"
    )

    # Tool 4: create_draft_po() — Creates ONLY draft, NEVER pays, NEVER sends email
    draft_po = create_draft_po(
        supplier_id=chosen_supplier["supplierId"],
        supplier_name=chosen_supplier["name"],
        material_id=material_id,
        quantity=cost_calc["quantity"],
        unit_price=cost_calc["unitPrice"],
        total_amount=cost_calc["totalAmount"],
        currency=cost_calc["currency"],
        budget_threshold=5000.0
    )

    completed.append(f"Purchasing: Selected {chosen_supplier['name']} (${chosen_supplier['pricePerUnit']}/unit) and drafted {draft_po['poNumber']}")

    return {
        "current_agent": "Purchasing",
        "purchasing_data": {
            "supplier": chosen_supplier,
            "draft_po": draft_po
        },
        "completed_steps": completed,
        "errors": errors
    }

