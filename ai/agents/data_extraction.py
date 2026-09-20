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
        material_id = state.get("inventory_data", {}).get("itemCode") or "RM-STEEL-001"

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
        req_qty = max(500, int(max_stock - curr_stock))

        inventory_data = {
            "materialId": material_id,
            "itemCode": material_id,
            "itemName": "Cold Rolled Steel Sheet",
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
