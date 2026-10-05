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
    context = (state.get("procurement_requirement") or {}).get("productionContext") or {}
    schedule = query_production_schedule(shift_id=context.get("shiftId"), material_id=state.get("material_id"))
    tool_results["query_production_schedule"] = schedule
    if schedule.get("available") is False:
        return {"current_agent": "Production Analysis", "production_data": schedule,
                "tool_results": tool_results, "completed_steps": completed + ["Production schedule unavailable; procurement can continue using authoritative material requirements"]}


    # Machine diagnostics are optional and require an actual machine association.
    machine_id = schedule.get("machineId")
    uptime_data = calculate_machine_uptime(machine_id) if machine_id else {"available": False, "reason": "No machine associated with this schedule"}
    interval = uptime_data.get("maintenanceIntervalHours")
    maintenance_data = check_maintenance_requirement(
        uptime=uptime_data["uptimeHours"], maintenance_interval=interval, machine_id=machine_id
    ) if uptime_data.get("uptimeHours") is not None and interval else {"available": False, "reason": "Maintenance telemetry is incomplete"}
    tool_results["calculate_machine_uptime"] = uptime_data
    tool_results["check_maintenance_requirement"] = maintenance_data
    inv_data = state.get("inventory_data", {})
    target = schedule.get("plannedOutput", 0)
    available_mat = inv_data.get("availableQuantity", 0)

    # 4. Calculate production impact
    conversion = schedule.get("materialPerUnit")
    from ai.core.config import settings
    impact = (calculate_production_impact(target=target, available_material=available_mat, material_per_unit=conversion or 1.0)
              if conversion is not None or settings.demo_mode else
              {"available": False, "reason": "Material-per-output conversion is missing; output impact cannot be estimated"})
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
