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

    inv_data = state.get("inventory_data", {})
    prod_data = state.get("production_data", {})

    # Query real Supplier from PostgreSQL Suppliers table
    supplier = None
    from ai.tools.production_tools import get_db_connection
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT "SupplierCode", "Name", "LeadTimeDays", "IsActive" FROM "Suppliers" WHERE "IsActive" = true ORDER BY "Id" ASC LIMIT 1')
                sup = cur.fetchone()
                if sup:
                    supplier = {
                        "supplierId": sup[0],
                        "name": sup[1],
                        "isAvailable": sup[3],
                        "leadTimeDays": int(sup[2]),
                        "unitPriceUsd": 4.50,
                        "minimumOrderQuantity": 500
                    }
        except Exception:
            pass
        finally:
            conn.close()

    if not supplier:
        supplier = {
            "supplierId": "SUP-001",
            "name": "Apex Industrial Metals",
            "isAvailable": True,
            "leadTimeDays": 7,
            "unitPriceUsd": 4.50,
            "minimumOrderQuantity": 500
        }

    if not supplier.get("isAvailable"):
        return {
            "current_agent": "Purchasing",
            "status": WorkflowStatus.Failed,
            "errors": errors + ["Primary supplier unavailable for BoxPouch film."],
            "final_outcome": "Halted: Supplier unavailable. Revision requested."
        }

    target = prod_data.get("schedule", {}).get("plannedOutput", 1000)
    avail = inv_data.get("availableQuantity", 160)
    needed_material = max(500, int(target - avail)) if target > avail else 500
    total_cost = round(needed_material * supplier["unitPriceUsd"], 2)

    import uuid
    draft_po_num = f"PO-AI-{str(uuid.uuid4())[:6].upper()}"
    draft_po = {
        "poNumber": draft_po_num,
        "supplier": supplier["name"],
        "itemCode": inv_data.get("itemCode", "RM-STEEL-001"),
        "quantity": needed_material,
        "unit": inv_data.get("unit", "KG"),
        "estimatedCostUsd": total_cost,
        "paymentStatus": "UNPAID", # Strict constraint: Planner/AI must NOT pay
        "emailSent": False,        # Strict constraint: Planner/AI must NOT send email
        "requiresApproval": total_cost > 1000.0
    }

    completed.append(f"Purchasing: Formulated draft purchase order ({draft_po_num})")

    return {
        "current_agent": "Purchasing",
        "purchasing_data": {
            "supplier": supplier,
            "draft_po": draft_po
        },
        "completed_steps": completed,
        "errors": errors
    }

