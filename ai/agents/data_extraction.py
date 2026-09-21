from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock
)


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Student 1 (Floor Worker): Data Extraction Agent Node
    Strictly responsible ONLY for inventory retrieval and burn-rate telemetry:
    - get_inventory_levels()
    - query_inventory_history()
    - calculate_burn_rate()
    - detect_low_stock()
    Does NOT touch production machines or schedule planning (which belongs to Student 4).
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    try:
        import re
        import psycopg
        from ai.core.config import settings

        inv_input = state.get("inventory_data", {})
        obj = state.get("objective", "")
        material_match = re.search(r"\b(RM[A-Z0-9_-]*)\b", obj, re.IGNORECASE)

        material_id = (
            inv_input.get("materialId")
            or inv_input.get("itemCode")
            or (material_match.group(1).upper() if material_match else None)
            or "RM-STEEL-001"
        )

        # Tool 1: get_inventory_levels()
        levels = get_inventory_levels.invoke({"materialId": material_id})

        # Tool 2: query_inventory_history()
        history = query_inventory_history.invoke({"materialId": material_id, "periodDays": 30})

        # Tool 3: calculate_burn_rate()
        burn = calculate_burn_rate.invoke({
            "consumption": history.get("consumption", 2400.0),
            "periodDays": history.get("periodDays", 30),
            "materialId": material_id
        })

        # Tool 4: detect_low_stock()
        low_stock_analysis = detect_low_stock.invoke({
            "currentStock": levels.get("currentStock", 350.0),
            "minimumStock": levels.get("minimumStock", 200.0),
            "burnRate": burn.get("burnRate", 80.0),
            "supplierLeadTime": 7.0,
            "materialId": material_id
        })

        curr_stock = levels.get("currentStock", 350.0)
        min_stock = levels.get("minimumStock", 200.0)
        max_stock = levels.get("maximumStock", 1000.0)
        req_qty = inv_input.get("requiredQuantity") or max(500, int(max_stock - curr_stock))

        # Query real material name from PostgreSQL RawMaterials table
        item_name = levels.get("itemName") or "Industrial Raw Material"
        try:
            with psycopg.connect(
                host=settings.DB_HOST,
                port=settings.DB_PORT,
                dbname=settings.DB_NAME,
                user=settings.DB_USER,
                password=settings.DB_PASSWORD,
                connect_timeout=2
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute('SELECT "Name" FROM "RawMaterials" WHERE UPPER("SkuCode") = %s OR UPPER("SkuCode") LIKE %s', (material_id, f"%{material_id}%"))
                    row = cur.fetchone()
                    if row:
                        item_name = row[0]
        except Exception:
            if "STEEL" in material_id:
                item_name = "Cold Rolled Steel Sheet"
            elif "ALUM" in material_id:
                item_name = "High-Tensile Aluminum Rod"
            elif "POLY" in material_id:
                item_name = "Industrial Polypropylene Pellets"

        inventory_data = {
            "materialId": material_id,
            "itemCode": material_id,
            "itemName": item_name,
            "currentStock": curr_stock,
            "availableQuantity": curr_stock,
            "minimumStock": min_stock,
            "maximumStock": max_stock,
            "reorderThreshold": min_stock,
            "burnRate": burn.get("burnRate", 80.0),
            "burnRatePerHour": round(burn.get("burnRate", 80.0) / 8.0, 2),
            "daysRemaining": low_stock_analysis.get("daysRemaining", 4.375),
            "lowStock": low_stock_analysis.get("lowStock", True),
            "status": "LOW_STOCK" if low_stock_analysis.get("lowStock", True) else "NORMAL",
            "requiredQuantity": req_qty,
            "unit": "KG"
        }

        tool_results["get_inventory_levels"] = levels
        tool_results["query_inventory_history"] = history
        tool_results["calculate_burn_rate"] = burn
        tool_results["detect_low_stock"] = low_stock_analysis

        completed.append("Data Extraction: Analyzed inventory levels, burn rate & days remaining")

        return {
            "current_agent": "Data Extraction",
            "inventory_data": inventory_data,
            "tool_results": tool_results,
            "completed_steps": completed,
            "errors": errors
        }

    except Exception as ex:
        return {
            "current_agent": "Data Extraction",
            "status": WorkflowStatus.Failed,
            "errors": errors + [f"Data extraction exception: {str(ex)}"],
            "final_outcome": "Safe failure: Exception encountered during data extraction."
        }
