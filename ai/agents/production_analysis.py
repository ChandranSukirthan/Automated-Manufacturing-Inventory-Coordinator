from typing import Dict, Any
from ai.core.state import AgentState
from ai.tools.production_tools import (
    query_production_schedule,
    calculate_machine_uptime,
    check_maintenance_requirement,
    calculate_production_impact,
)


def production_analysis_node(state: AgentState) -> Dict[str, Any]:
    """
    Student 4 (Shankar - IT Admin): Production Analysis Node
    Evaluates manufacturing schedule impact, machine uptime, maintenance intervals,
    and calculates adjusted throughput based on available inventory.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    # 1. Query production schedule
    schedule = query_production_schedule()
    tool_results["query_production_schedule"] = schedule

    # 2. Check machine uptime & maintenance requirement
    uptime_data = calculate_machine_uptime(schedule.get("machineId", "M001"))
    maintenance_data = check_maintenance_requirement(
        uptime=uptime_data.get("uptimeHours", 480.0),
        maintenance_interval=500.0,
        machine_id=schedule.get("machineId", "M001")
    )
    tool_results["calculate_machine_uptime"] = uptime_data
    tool_results["check_maintenance_requirement"] = maintenance_data

    # 3. Assess impact of available inventory on shift target
    inv_data = state.get("inventory_data", {})
    target = schedule.get("plannedOutput", 1000)
    available_mat = inv_data.get("availableQuantity", 350.0)

    # 4. Calculate production impact
    impact = calculate_production_impact(target=target, available_material=int(available_mat))
    tool_results["calculate_production_impact"] = impact

    completed.append("Production Analysis: Evaluated production schedule impact, machine uptime & adjusted throughput")

    prod_data = {
        "schedule": schedule,
        "machine_uptime": uptime_data,
        "maintenance_requirement": maintenance_data,
        "impact": impact
    }

    return {
        "current_agent": "Production Analysis",
        "production_data": prod_data,
        "tool_results": tool_results,
        "completed_steps": completed,
        "errors": errors
    }
