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

        # Student 1: Data Extraction Agent uses inventory tools
        from ai.tools.inventory_tools import (
            get_inventory_levels,
            query_inventory_history,
            calculate_burn_rate,
            detect_low_stock
        )

        material_id = state.get("inventory_data", {}).get("itemCode") or "RM-STEEL-001"
        levels = get_inventory_levels.invoke({"materialId": material_id})
        history = query_inventory_history.invoke({"materialId": material_id, "periodDays": 30})
        burn = calculate_burn_rate.invoke({
            "consumption": history.get("consumption", 2400.0),
            "periodDays": history.get("periodDays", 30),
            "materialId": material_id
        })
        low_stock_analysis = detect_low_stock.invoke({
            "currentStock": levels.get("currentStock", 350.0),
            "minimumStock": levels.get("minimumStock", 200.0),
            "burnRate": burn.get("burnRate", 80.0),
            "supplierLeadTime": 7.0,
            "materialId": material_id
        })

        target_output = schedule.get("plannedOutput", 1000)
        curr_stock = levels.get("currentStock", 350.0)
        req_qty = max(500, int(target_output - curr_stock)) if target_output > curr_stock else 500

        inventory_data = {
            "materialId": material_id,
            "itemCode": material_id,
            "itemName": "Cold Rolled Steel Sheet",
            "currentStock": curr_stock,
            "availableQuantity": curr_stock,
            "minimumStock": levels.get("minimumStock", 200.0),
            "reorderThreshold": levels.get("minimumStock", 200.0),
            "burnRate": burn.get("burnRate", 80.0),
            "burnRatePerHour": round(burn.get("burnRate", 80.0) / 8.0, 2),
            "daysRemaining": low_stock_analysis.get("daysRemaining", 4.375),
            "lowStock": low_stock_analysis.get("lowStock", True),
            "status": "LOW_STOCK" if low_stock_analysis.get("lowStock", True) else "NORMAL",
            "requiredQuantity": req_qty,
            "unit": "KG"
        }

        tool_results["get_inventory_levels"] = levels
        tool_results["calculate_burn_rate"] = burn
        tool_results["detect_low_stock"] = low_stock_analysis
        tool_results["query_production_schedule"] = schedule
        tool_results["calculate_machine_uptime"] = uptime_data
        tool_results["check_maintenance_requirement"] = maintenance_data

        completed.append("Data Extraction: Analyzed inventory levels, burn rate & days remaining")

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

