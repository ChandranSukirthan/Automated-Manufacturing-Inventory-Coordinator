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


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """Run the two-tool Data Extraction Agent and map its JSON to shared state.

    This node deliberately owns only Student A's tool allow-list:
    ``query_production_db`` and ``get_inventory_levels``. Equipment telemetry
    belongs to the Production Scheduling & Equipment component, not this agent.
    """

    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))
    extraction = run_data_extraction_agent(_extraction_request_from_state(state))

    if extraction["status"] != "COMPLETED":
        return {
            "current_agent": "Data Extraction",
            "status": WorkflowStatus.Failed,
            "tool_results": {**tool_results, "data_extraction": extraction},
            "errors": errors + extraction["errors"],
            "final_outcome": "Workflow aborted: data extraction returned a safe failure.",
        }

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
