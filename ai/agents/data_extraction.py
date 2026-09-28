from typing import Dict, Any
from ai.agents.data_extraction_agent import run_data_extraction_agent
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock
)
from ai.tools.production_tools import get_production_schedule


_PRODUCT_DEFAULTS = {
    "BoxPouch": {"batch_id": "AUTO-BP-001", "material_sku": "BP-FILM-001"},
    "TeaBag": {"batch_id": "AUTO-TB-001", "material_sku": "TB-PAPER-001"},
    "Can": {"batch_id": "AUTO-CAN-001", "material_sku": "CAN-ALLOY-001"},
    "Bottle": {"batch_id": "AUTO-BOT-001", "material_sku": "BOT-RESIN-001"},
}


def _extraction_request_from_state(state: AgentState) -> dict[str, str]:
    """Build a validated, read-only request for the data-extraction agent."""

    supplied = state.get("data_extraction_request")
    if isinstance(supplied, dict):
        return {key: str(value) for key, value in supplied.items()}

    objective = str(state.get("objective", "")).lower()
    if "tea bag" in objective or "teabag" in objective:
        product_type = "TeaBag"
    elif "bottle" in objective:
        product_type = "Bottle"
    elif "can packaging" in objective or " can " in f" {objective} ":
        product_type = "Can"
    else:
        product_type = "BoxPouch"
    return {"product_type": product_type, **_PRODUCT_DEFAULTS[product_type]}


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """Run the two-tool Data Extraction Agent and map its JSON to shared state.

    This node deliberately owns only Student A's tool allow-list:
    ``query_production_db`` and ``get_inventory_levels``. Equipment telemetry
    belongs to the Production Scheduling & Equipment component, not this agent.
    """
    # Student 1 (Floor Worker): Data Extraction Agent Node.
    # It retrieves inventory, burn-rate telemetry, and the next-shift material
    # plan without creating orders or altering production machines.
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))
    extraction = run_data_extraction_agent(_extraction_request_from_state(state))
    tool_results["data_extraction_agent"] = extraction
    if extraction.get("status") != "COMPLETED":
        return {
            "current_agent": "Data Extraction",
            "status": WorkflowStatus.Failed,
            "tool_results": tool_results,
            "errors": errors + list(extraction.get("errors", [])),
            "final_outcome": "Workflow aborted: data extraction returned a safe failure.",
        }

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
        # Read-only schedule context for the Floor Worker's next shift.
        schedule = get_production_schedule.invoke({"shiftName": "Next shift"})


        curr_stock = levels["currentStock"]
        min_stock = levels["minimumStock"]
        max_stock = levels["maximumStock"]
        req_qty = inv_input.get("requiredQuantity") or max(0, max_stock - curr_stock)

        inventory_data: Dict[str, Any] = {
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
            "tool_results": tool_results,
            "errors": errors + [str(ex)],
            "final_outcome": "Workflow aborted: data extraction returned a safe failure.",
        }
