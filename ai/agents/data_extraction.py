from typing import Dict, Any
from ai.core.state import AgentState, WorkflowStatus
from ai.tools.production_tools import (
    query_production_schedule,
    calculate_machine_uptime,
    check_maintenance_requirement,
    calculate_production_impact,
)


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Data Extraction Agent Node:
    Responsible for inventory analysis, machine telemetry, and schedule requirements.
    Implements safe failure if inventory or production data is unavailable.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    try:
        # Extract production schedule data
        schedule = query_production_schedule()
        if not schedule or "plannedOutput" not in schedule:
            return {
                "current_agent": "Data Extraction",
                "status": WorkflowStatus.Failed,
                "errors": errors + ["Production data unavailable: safe failure triggered."],
                "final_outcome": "Workflow aborted: Production schedule data unavailable."
            }

        # Query machine uptime and maintenance status
        uptime_data = calculate_machine_uptime(schedule.get("machineId", "M001"))
        maintenance_data = check_maintenance_requirement(
            uptime=uptime_data.get("uptimeHours", 480),
            maintenance_interval=500.0,
            machine_id=schedule.get("machineId", "M001")
        )

        inventory_data = {
            "itemCode": "BP-FILM-001",
            "itemName": "BoxPouch Film Roll (Grade A)",
            "availableQuantity": 6000,
            "reorderThreshold": 8000,
            "unit": "meters",
            "burnRatePerHour": 250,
            "status": "LOW_STOCK"
        }

        tool_results["query_production_schedule"] = schedule
        tool_results["calculate_machine_uptime"] = uptime_data
        tool_results["check_maintenance_requirement"] = maintenance_data

        completed.append("Data Extraction: Collected inventory & machine telemetry")

        return {
            "current_agent": "Data Extraction",
            "inventory_data": inventory_data,
            "production_data": {
                "schedule": schedule,
                "machine_uptime": uptime_data,
                "maintenance_requirement": maintenance_data
            },
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


def production_analysis_node(state: AgentState) -> Dict[str, Any]:
    """
    Production Analysis Node:
    Assesses impact of inventory and maintenance on planned production runs.
    Calculates adjusted output.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    prod_data = state.get("production_data", {})
    inv_data = state.get("inventory_data", {})

    target = prod_data.get("schedule", {}).get("plannedOutput", 10000)
    available_mat = inv_data.get("availableQuantity", 6000)

    # Tool 4: calculate_production_impact
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
        "errors": errors
    }

