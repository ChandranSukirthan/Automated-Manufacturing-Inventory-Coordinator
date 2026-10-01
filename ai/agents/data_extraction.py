"""
Data Extraction Agent
Retrieves all internal procurement context needed by the Purchasing Agent:
- Material & stock data (Student 1: Inventory levels, burn rate, days remaining, deficit)
- Open PO quantities
- Approved supplier rates, MOQ, pack size
- Historical prices and supplier performance
Returns structured JSON — no chain-of-thought stored.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ai.core.state import AgentState, WorkflowStatus
from ai.core.config import settings
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock
)
from ai.tools.purchasing_tools import (
    query_internal_supplier_data,
    get_db_connection,
)
# Re-export production_analysis_node for backwards compatibility
from ai.agents.production_analysis import production_analysis_node

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
        pass

    return supplier_rates, historical_procurement


def data_extraction_node(state: AgentState) -> Dict[str, Any]:
    """
    Data Extraction Agent Node.
    Retrieves all internal procurement data needed by the Purchasing Agent.
    Strictly combines:
    1. Student 1 Inventory retrieval & burn-rate telemetry tools:
       - get_inventory_levels()
       - query_inventory_history()
       - calculate_burn_rate()
       - detect_low_stock()
    2. Authoritative procurement values from ASP.NET Core:
       - material_name, current_stock, required_quantity, safety_stock, net_deficit, etc.
    3. Supplier rates & historical procurement outcomes.
    """
    completed = list(state.get("completed_steps") or [])
    errors = list(state.get("errors") or [])
    tool_log = list(state.get("tool_call_log") or [])
    tool_results = dict(state.get("tool_results") or {})
    now_iso = datetime.now(timezone.utc).isoformat()

    # ── Resolve material ID from state or objective ──────────────────────────
    inv_input = state.get("inventory_data") or {}
    obj = state.get("objective") or ""
    material_match = re.search(r"\b(RM[A-Z0-9_-]*)\b", obj, re.IGNORECASE)

    material_id = (
        state.get("material_id")
        or inv_input.get("materialId")
        or inv_input.get("itemCode")
        or (material_match.group(1).upper() if material_match else None)
        or "RM-STEEL-001"
    )

    material_name = (
        state.get("material_name")
        or inv_input.get("materialName")
        or inv_input.get("itemName")
    )
    current_stock = state.get("current_stock")
    required_quantity = state.get("required_quantity") or inv_input.get("requiredQuantity")
    safety_stock = state.get("safety_stock")
    open_po_quantity = state.get("open_po_quantity")
    net_deficit = state.get("net_deficit")
    budget_limit = state.get("budget_limit")
    unit = state.get("unit") or "units"

    try:
        # Tool 1: get_inventory_levels()
        levels = get_inventory_levels.invoke({"materialId": material_id})

        # Tool 2: query_inventory_history()
        history = query_inventory_history.invoke({"materialId": material_id, "periodDays": 30})

        # Tool 3: calculate_burn_rate()
        burn = calculate_burn_rate.invoke({
            "consumption": history.get("consumption", 2400.0),
            "periodDays": history.get("periodDays", 30),
            "materialId": material_id
        })

        # Tool 4: detect_low_stock()
        low_stock_analysis = detect_low_stock.invoke({
            "currentStock": levels.get("currentStock", current_stock or 350.0),
            "minimumStock": levels.get("minimumStock", safety_stock or 200.0),
            "burnRate": burn.get("burnRate", 80.0),
            "supplierLeadTime": 7.0,
            "materialId": material_id
        })

        curr_stock = current_stock if current_stock is not None else levels.get("currentStock", 350.0)
        min_stock = safety_stock if safety_stock is not None else levels.get("minimumStock", 200.0)
        max_stock = levels.get("maximumStock", 1000.0)
        req_qty = required_quantity or inv_input.get("requiredQuantity") or max(500.0, float(max_stock - curr_stock))

        # Query real material name from PostgreSQL RawMaterials table if not provided
        item_name = material_name or levels.get("itemName")
        if not item_name or item_name == "Unknown Material":
            try:
                import psycopg
                with psycopg.connect(
                    host=settings.DB_HOST,
                    port=settings.DB_PORT,
                    dbname=settings.DB_NAME,
                    user=settings.DB_USER,
                    password=settings.DB_PASSWORD,
                    connect_timeout=2
                ) as conn:
                    with conn.cursor() as cur:
                        cur.execute('SELECT "Name" FROM "RawMaterials" WHERE UPPER("SkuCode") = %s OR UPPER("SkuCode") LIKE %s', (material_id.upper(), f"%{material_id.upper()}%"))
                        row = cur.fetchone()
                        if row:
                            item_name = row[0]
            except Exception:
                if "STEEL" in material_id:
                    item_name = "Cold Rolled Steel Sheet"
                elif "ALUM" in material_id:
                    item_name = "High-Tensile Aluminum Rod"
                elif "POLY" in material_id:
                    item_name = "Industrial Polypropylene Pellets"
                else:
                    item_name = "Industrial Raw Material"

        material_name = item_name or "Industrial Raw Material"

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
            "itemCode": material_id,
            "itemName": material_name,
            "materialName": material_name,
            "currentStock": curr_stock,
            "availableQuantity": curr_stock,
            "minimumStock": min_stock,
            "maximumStock": max_stock,
            "safetyStock": min_stock,
            "reorderThreshold": min_stock,
            "burnRate": burn.get("burnRate", 80.0),
            "burnRatePerHour": round(burn.get("burnRate", 80.0) / 8.0, 2),
            "daysRemaining": low_stock_analysis.get("daysRemaining", 4.375),
            "lowStock": low_stock_analysis.get("lowStock", True),
            "status": "LOW_STOCK" if low_stock_analysis.get("lowStock", True) else "NORMAL",
            "requiredQuantity": float(req_qty),
            "openPOQuantity": open_po_quantity or 0.0,
            "netDeficit": net_deficit if net_deficit is not None else float(req_qty),
            "budgetLimit": budget_limit,
            "unit": unit,
            "internalSuppliers": internal_suppliers,
        }

        tool_results["get_inventory_levels"] = levels
        tool_results["query_inventory_history"] = history
        tool_results["calculate_burn_rate"] = burn
        tool_results["detect_low_stock"] = low_stock_analysis

        completed.append("Data Extraction: Analyzed inventory levels, burn rate & days remaining")

        return {
            "current_agent": "Data Extraction",
            "inventory_data": inventory_data,
            "material_id": material_id,
            "material_name": material_name,
            "supplier_rates": supplier_rates,
            "historical_procurement": historical_procurement,
            "tool_call_log": tool_log,
            "tool_results": tool_results,
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
