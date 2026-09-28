<<<<<<< HEAD
from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock
)
from ai.tools.production_tools import get_production_schedule
=======
"""Adapter that connects Student A's data agent to the shared workflow state."""

from typing import Any, Dict

from agents.data_extraction_agent import run_data_extraction_agent
from core.state import AgentState, WorkflowStatus
from tools.production_tools import calculate_production_impact


_PRODUCT_DEFAULTS = {
    "BoxPouch": {"batch_id": "AUTO-BP-001", "material_sku": "BP-FILM-001"},
    "TeaBag": {"batch_id": "AUTO-TB-001", "material_sku": "TB-PAPER-001"},
    "Can": {"batch_id": "AUTO-CAN-001", "material_sku": "CAN-ALLOY-001"},
    "Bottle": {"batch_id": "AUTO-BOT-001", "material_sku": "BOT-RESIN-001"},
}


def _extraction_request_from_state(state: AgentState) -> dict[str, str]:
    """Use a structured alert when present, otherwise infer a safe demo input."""

    supplied = state.get("data_extraction_request")
    if isinstance(supplied, dict):
        return dict(supplied)

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
>>>>>>> 9bbffc7c0e8ef0f0d675fc80a20b283c792a350e


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """Run the two-tool Data Extraction Agent and map its JSON to shared state.

    This node deliberately owns only Student A's tool allow-list:
    ``query_production_db`` and ``get_inventory_levels``. Equipment telemetry
    belongs to the Production Scheduling & Equipment component, not this agent.
    """
<<<<<<< HEAD
    Student 1 (Floor Worker): Data Extraction Agent Node
    Responsible for inventory retrieval, burn-rate telemetry, and reading the
    next-shift material plan. It remains read-only and never creates orders.
    - get_inventory_levels()
    - query_inventory_history()
    - calculate_burn_rate()
    - detect_low_stock()
    It does not alter production machines or schedule planning.
    """
=======

>>>>>>> 9bbffc7c0e8ef0f0d675fc80a20b283c792a350e
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))
    extraction = run_data_extraction_agent(_extraction_request_from_state(state))

<<<<<<< HEAD
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
=======
    if extraction["status"] != "COMPLETED":
>>>>>>> 9bbffc7c0e8ef0f0d675fc80a20b283c792a350e
        return {
            "current_agent": "Data Extraction",
            "status": WorkflowStatus.Failed,
            "tool_results": {**tool_results, "data_extraction": extraction},
            "errors": errors + extraction["errors"],
            "final_outcome": "Workflow aborted: data extraction returned a safe failure.",
        }
<<<<<<< HEAD
=======

    inventory = extraction["current_inventory"]
    requirement = extraction["material_requirement"]
    schedules = extraction["upcoming_production_schedule"]
    planned_output = sum(int(run["planned_output_units"]) for run in schedules)
    product_type = extraction["request"]["product_type"]
    inventory_data = {
        "itemCode": inventory["material_sku"],
        "itemName": f"{product_type} material {inventory['material_sku']}",
        "availableQuantity": inventory["allocatable_quantity"],
        "reorderThreshold": inventory["reorder_threshold"],
        "unit": inventory["unit"],
        "burnRatePerHour": extraction["past_burn_rate"]["average_quantity_per_hour"],
        "status": (
            "LOW_STOCK"
            if requirement["recommendation"] == "REPLENISHMENT_REQUIRED"
            else "IN_STOCK"
        ),
    }
    schedule = {
        "productionDate": "from_data_extraction_agent",
        "plannedOutput": planned_output,
        "requiredMaterial": requirement["upcoming_required_quantity"],
        "scheduledRuns": schedules,
    }
    completed.append("Data Extraction: Collected burn-rate, inventory, and production schedule")
    return {
        "current_agent": "Data Extraction",
        "inventory_data": inventory_data,
        "production_data": {"schedule": schedule, "data_extraction": extraction},
        "tool_results": {**tool_results, "data_extraction": extraction},
        "completed_steps": completed,
        "errors": errors,
    }


def production_analysis_node(state: AgentState) -> Dict[str, Any]:
    """Assess impact of available material on the planned production runs."""

    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))
    prod_data = state.get("production_data", {})
    inv_data = state.get("inventory_data", {})

    target = prod_data.get("schedule", {}).get("plannedOutput", 10000)
    available_mat = inv_data.get("availableQuantity", 6000)
    impact = calculate_production_impact(target=target, available_material=available_mat)
    tool_results["calculate_production_impact"] = impact
    completed.append("Production Analysis: Evaluated production impact and adjusted throughput")

    prod_data_updated = dict(prod_data)
    prod_data_updated["impact"] = impact
    return {
        "current_agent": "Production Analysis",
        "production_data": prod_data_updated,
        "tool_results": tool_results,
        "completed_steps": completed,
        "errors": errors,
    }
>>>>>>> 9bbffc7c0e8ef0f0d675fc80a20b283c792a350e
