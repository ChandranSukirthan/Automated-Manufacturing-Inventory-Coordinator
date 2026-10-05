"""
Student 1 (Floor Worker): Data Extraction Agent.
Retrieves current stock levels, consumption history, burn rate,
and detects low-stock conditions using LangChain structured tools.
"""

from typing import Dict, Any, Optional
import os
import re
import psycopg
from ai.core.config import settings
from ai.core.state import AgentState, WorkflowStatus
from ai.core.contracts import first_present
from ai.data_extraction_agent import run_data_extraction_agent
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock,
)
from ai.tools.production_tools import get_production_schedule

_PRODUCT_DEFAULTS = {
    "BoxPouch": {"batch_id": "BATCH001", "material_sku": "RM-STEEL-001"},
    "BiscuitPackaging": {"batch_id": "BATCH002", "material_sku": "RM-ALUM-002"},
    "TeaBag": {"batch_id": "BATCH003", "material_sku": "RM-POLY-003"},
    "Can": {"batch_id": "BATCH-IRON-001", "material_sku": "RM-IRON-001"},
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
    elif "biscuit" in objective:
        product_type = "BiscuitPackaging"
    else:
        product_type = "BoxPouch"
    return {"product_type": product_type, **_PRODUCT_DEFAULTS[product_type]}


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Student 1 (Floor Worker): Data Extraction Agent Node
    Strictly responsible for inventory retrieval, burn-rate telemetry,
    and read-only next-shift schedule planning.
    """
    completed = list(state.get("completed_steps", []))
    errors = list(state.get("errors", []))
    tool_results = dict(state.get("tool_results", {}))

    # The graph retrieves canonical SKU data below. Product-specific extraction
    # is available separately and must not substitute a default product/batch.

    try:
        inv_input = state.get("inventory_data", {})
        obj = state.get("objective", "")
        material_match = re.search(r"\b(RM[A-Z0-9_-]*)\b", obj, re.IGNORECASE)

        material_id = (
            state.get("material_id")
            or inv_input.get("materialId")
            or inv_input.get("itemCode")
            or (material_match.group(1).upper() if material_match else None)
            or None
        )

        if not material_id:
            raise ValueError("Select an exact material before starting procurement")

        # Tool 1: get_inventory_levels()
        levels = get_inventory_levels.invoke({"materialId": material_id})

        # Tool 2: query_inventory_history()
        history = query_inventory_history.invoke({
            "materialId": material_id,
            "periodDays": 30
        })

        # Tool 3: calculate_burn_rate()
        burn = calculate_burn_rate.invoke({
            "consumption": history.get("consumption", 0),
            "periodDays": history.get("periodDays", 30),
            "materialId": material_id
        })

        # Tool 4: detect_low_stock()
        low_stock_analysis = detect_low_stock.invoke({
            "currentStock": levels["currentStock"],
            "minimumStock": levels["minimumStock"],
            "burnRate": burn.get("burnRate", 0),
            "supplierLeadTime": 0.0,  # No supplier has been selected at this stage.
            "materialId": material_id
        })

        # Read-only schedule context for next shift
        schedule = get_production_schedule.invoke({"shiftName": "Next shift"})

        curr_stock = levels["currentStock"]
        min_stock = state.get("safety_stock") if state.get("safety_stock") is not None else levels["minimumStock"]
        max_stock = levels.get("maximumStock")
        req_qty = first_present(state.get("required_quantity"), inv_input.get("requiredQuantity"), state.get("net_deficit"))

        # Query real material name from PostgreSQL RawMaterials table
        item_name = levels.get("itemName") or "Industrial Raw Material"
        try:
            with psycopg.connect(
                host=settings.DB_HOST,
                port=settings.DB_PORT,
                dbname=settings.DB_NAME,
                user=settings.DB_USER,
                password=settings.DB_PASSWORD,
                connect_timeout=2, options="-c statement_timeout=5000 -c default_transaction_read_only=on"
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute('SELECT "Name" FROM "RawMaterials" WHERE UPPER("SkuCode") = %s', (material_id.upper(),))
                    row = cur.fetchone()
                    if row:
                        item_name = row[0]
        except Exception:
            item_name = state.get("material_name") or item_name

        inventory_data: Dict[str, Any] = {
            "materialId": material_id,
            "itemCode": material_id,
            "itemName": item_name,
            "currentStock": curr_stock,
            "availableQuantity": curr_stock,
            "minimumStock": min_stock,
            "maximumStock": max_stock,
            "reorderThreshold": min_stock,
            "burnRate": burn.get("burnRate", 0),
            "burnRatePerHour": round(burn.get("burnRate", 0) / 8.0, 2),
            "daysRemaining": low_stock_analysis.get("daysRemaining"),
            "lowStock": low_stock_analysis.get("lowStock", False),
            "status": "LOW_STOCK" if low_stock_analysis.get("lowStock", False) else "NORMAL",
            "requiredQuantity": req_qty,
            "productionSchedule": schedule,
            "unit": state.get("unit") or "units"
        }

        tool_results["get_inventory_levels"] = levels
        tool_results["query_inventory_history"] = history
        tool_results["calculate_burn_rate"] = burn
        tool_results["detect_low_stock"] = low_stock_analysis
        tool_results["get_production_schedule"] = schedule

        completed.append("Data Extraction: Analyzed inventory levels, burn rate & days remaining")

        return {
            "current_agent": "Data Extraction",
            "material_name": item_name,
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
            "errors": errors + [f"Data extraction exception: {str(ex)}"],
            "final_outcome": "Safe failure: Exception encountered during data extraction."
        }
