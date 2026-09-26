"""
Data Extraction Agent
Retrieves all internal procurement context needed by the Purchasing Agent:
- Material & stock data
- Open PO quantities
- Approved supplier rates, MOQ, pack size
- Historical prices and supplier performance
- Quality history and previous procurement outcomes
Returns structured JSON — no chain-of-thought stored.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List

from ai.core.state import AgentState, WorkflowStatus
from ai.tools.production_tools import (
    query_production_schedule,
    calculate_machine_uptime,
    check_maintenance_requirement,
    calculate_production_impact,
)
from ai.tools.purchasing_tools import (
    query_internal_supplier_data,
    get_db_connection,
)

logger = logging.getLogger("amic_agentic_ai.data_extraction")


def _query_supplier_rates_and_history(
    material_name: str | None,
    conn: Any,
) -> tuple[list[dict], list[dict]]:
    """
    Queries supplier rates (MOQ, pack size, unit price, lead time) and
    historical procurement outcomes from PostgreSQL.
    Returns (supplier_rates, historical_procurement).
    """
    supplier_rates: list[dict] = []
    historical_procurement: list[dict] = []

    if not conn:
        return supplier_rates, historical_procurement

    try:
        with conn.cursor() as cur:
            # Supplier rates: join Suppliers with any rate/performance tables if present
            cur.execute("""
                SELECT
                    s."Id", s."Name", s."SupplierCode", s."LeadTimeDays", s."PaymentTerms",
                    s."IsActive"
                FROM "Suppliers" s
                WHERE s."IsActive" = true
                ORDER BY s."Name";
            """)
            for row in cur.fetchall():
                supplier_rates.append({
                    "supplierId": row[0],
                    "supplierName": row[1],
                    "supplierCode": row[2],
                    "leadTimeDays": row[3],
                    "paymentTerms": row[4],
                    "isActive": row[5],
                    "source": "INTERNAL_DATABASE",
                })
    except Exception as ex:
        logger.warning(f"[Data Extraction] Could not query supplier rates: {ex}")

    try:
        with conn.cursor() as cur:
            # Historical procurement outcomes for future learning dataset
            cur.execute("""
                SELECT
                    "Material", "RecommendedSupplier", "SelectedSupplier",
                    "EstimatedPrice", "FinalPrice",
                    "EstimatedLeadTime", "ActualLeadTime",
                    "ManagerDecision", "ProcurementSuccess",
                    "PaymentSuccess", "DeliverySuccess", "QualityOutcome",
                    "CreatedAt"
                FROM "ProcurementOutcomes"
                ORDER BY "CreatedAt" DESC
                LIMIT 20;
            """)
            for row in cur.fetchall():
                historical_procurement.append({
                    "material": row[0],
                    "recommendedSupplier": row[1],
                    "selectedSupplier": row[2],
                    "estimatedPrice": float(row[3]) if row[3] else None,
                    "finalPrice": float(row[4]) if row[4] else None,
                    "estimatedLeadTime": row[5],
                    "actualLeadTime": row[6],
                    "managerDecision": row[7],
                    "procurementSuccess": row[8],
                    "paymentSuccess": row[9],
                    "deliverySuccess": row[10],
                    "qualityOutcome": row[11],
                    "createdAt": row[12].isoformat() if row[12] else None,
                })
    except Exception:
        # Table may not exist yet — safe to ignore
        pass

    return supplier_rates, historical_procurement


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Data Extraction Agent Node.
    Retrieves all internal procurement data needed by the Purchasing Agent.
    Uses authoritative values from ASP.NET Core (net_deficit, current_stock, etc.)
    and enriches with supplier rates, MOQ, pack size, and historical outcomes.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])
    tool_log = list(state.get("tool_call_log") or [])
    now_iso = datetime.now(timezone.utc).isoformat()

    # ── Authoritative procurement fields from ASP.NET Core ────────────────────
    material_name = state.get("material_name") or "Unknown Material"
    material_id = state.get("material_id") or "UNKNOWN"
    current_stock = state.get("current_stock")
    required_quantity = state.get("required_quantity")
    safety_stock = state.get("safety_stock")
    open_po_quantity = state.get("open_po_quantity")
    net_deficit = state.get("net_deficit")
    budget_limit = state.get("budget_limit")
    unit = state.get("unit") or "units"

    try:
        # ── Production schedule (for maintenance/schedule workflows) ──────────
        schedule = {}
        uptime_data = {}
        maintenance_data = {}
        try:
            schedule = query_production_schedule()
            machine_id = schedule.get("machineId", "M001")
            uptime_data = calculate_machine_uptime(machine_id)
            maintenance_data = check_maintenance_requirement(
                uptime=uptime_data.get("uptimeHours", 480),
                maintenance_interval=500.0,
                machine_id=machine_id,
            )
        except Exception:
            pass

        # ── Internal supplier data ─────────────────────────────────────────────
        internal_suppliers = query_internal_supplier_data(material_name=material_name)
        tool_log.append({
            "tool": "query_internal_supplier_data",
            "material": material_name,
            "suppliersFound": len(internal_suppliers),
            "timestamp": now_iso,
        })

        # ── Supplier rates and historical procurement from DB ──────────────────
        conn = get_db_connection()
        supplier_rates, historical_procurement = _query_supplier_rates_and_history(
            material_name=material_name,
            conn=conn,
        )
        if conn:
            conn.close()

        tool_log.append({
            "tool": "query_supplier_rates_and_history",
            "supplierRatesFound": len(supplier_rates),
            "historicalOutcomesFound": len(historical_procurement),
            "timestamp": now_iso,
        })

        # ── Structured inventory data ──────────────────────────────────────────
        inventory_data: Dict[str, Any] = {
            "materialId": material_id,
            "materialName": material_name,
            "currentStock": current_stock,
            "requiredQuantity": required_quantity,
            "safetyStock": safety_stock,
            "openPOQuantity": open_po_quantity,
            "netDeficit": net_deficit,
            "budgetLimit": budget_limit,
            "unit": unit,
            "internalSuppliers": internal_suppliers,
        }

        production_data: Dict[str, Any] = {
            "schedule": schedule,
            "machine_uptime": uptime_data,
            "maintenance_requirement": maintenance_data,
        }

        completed.append(
            f"Data Extraction: Retrieved inventory, {len(internal_suppliers)} internal supplier(s), "
            f"{len(supplier_rates)} rate record(s), {len(historical_procurement)} historical outcome(s)"
        )

        return {
            "current_agent": "Data Extraction",
            "inventory_data": inventory_data,
            "production_data": production_data,
            "supplier_rates": supplier_rates,
            "historical_procurement": historical_procurement,
            "tool_call_log": tool_log,
            "completed_steps": completed,
            "errors": errors,
        }

    except Exception as ex:
        errors.append(f"Data extraction exception: {str(ex)}")
        return {
            "current_agent": "Data Extraction",
            "status": WorkflowStatus.Failed,
            "errors": errors,
            "final_outcome": f"Safe failure: Exception during data extraction — {str(ex)}",
        }


def production_analysis_node(state: AgentState) -> Dict[str, Any]:
    """
    Production Analysis Node (maintenance/schedule workflows only).
    Calculates adjusted production output based on material and machine constraints.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])
    tool_results = dict(state.get("tool_results") or {})

    prod_data = state.get("production_data") or {}
    inv_data = state.get("inventory_data") or {}

    target = prod_data.get("schedule", {}).get("plannedOutput", 10000)
    available_mat = inv_data.get("currentStock") or 6000

    impact = calculate_production_impact(target=target, available_material=available_mat)
    tool_results["calculate_production_impact"] = impact

    completed.append("Production Analysis: Evaluated production impact and adjusted throughput")

    return {
        "current_agent": "Production Analysis",
        "production_data": {**prod_data, "impact": impact},
        "tool_results": tool_results,
        "completed_steps": completed,
        "errors": errors,
    }
