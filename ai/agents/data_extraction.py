from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock
)
from ai.tools.production_tools import get_production_schedule


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Student 1 (Floor Worker): Data Extraction Agent Node
    Responsible for inventory retrieval, burn-rate telemetry, and reading the
    next-shift material plan. It remains read-only and never creates orders.
    - get_inventory_levels()
    - query_inventory_history()
    - calculate_burn_rate()
    - detect_low_stock()
    It does not alter production machines or schedule planning.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    try:
        inv_input = state.get("inventory_data", {})
        material_id = inv_input.get("materialId") or inv_input.get("itemCode")
        if not material_id:
            raise ValueError("A material must be selected before the AI workflow can run.")

        # Tool 1: get_inventory_levels()
        levels = get_inventory_levels.invoke({"materialId": material_id})

        # Tool 2: query_inventory_history()
        history = query_inventory_history.invoke({"materialId": material_id, "periodDays": 30})

        # Tool 3: calculate_burn_rate()
        burn = calculate_burn_rate.invoke({
            "consumption": history["consumption"],
            "periodDays": history["periodDays"],
            "materialId": material_id
        })

        # Tool 4: detect_low_stock()
        low_stock_analysis = detect_low_stock.invoke({
            "currentStock": levels["currentStock"],
            "minimumStock": levels["minimumStock"],
            "burnRate": burn["burnRate"],
            "supplierLeadTime": 0.0,
            "materialId": material_id
        })

        # Tool 5: read the upcoming material requirements. This read-only
        # schedule gives the Floor Worker context without performing planning.
        schedule = get_production_schedule.invoke({"shiftName": "Next shift"})

        curr_stock = levels["currentStock"]
        min_stock = levels["minimumStock"]
        max_stock = levels["maximumStock"]
        req_qty = inv_input.get("requiredQuantity") or max(0, max_stock - curr_stock)

        inventory_data = {
            "materialId": material_id,
            "itemCode": material_id,
            "currentStock": curr_stock,
            "availableQuantity": curr_stock,
            "minimumStock": min_stock,
            "maximumStock": max_stock,
            "reorderThreshold": min_stock,
            "burnRate": burn["burnRate"],
            "daysRemaining": low_stock_analysis["daysRemaining"],
            "lowStock": low_stock_analysis["lowStock"],
            "status": "LOW_STOCK" if low_stock_analysis["lowStock"] else "NORMAL",
            "requiredQuantity": req_qty,
            "productionSchedule": schedule,
        }

        tool_results["get_inventory_levels"] = levels
        tool_results["query_inventory_history"] = history
        tool_results["calculate_burn_rate"] = burn
        tool_results["detect_low_stock"] = low_stock_analysis
        tool_results["get_production_schedule"] = schedule

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
