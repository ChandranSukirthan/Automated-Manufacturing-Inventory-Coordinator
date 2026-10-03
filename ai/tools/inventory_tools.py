import logging
import httpx
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from langchain_core.tools import tool
from ai.config import INVENTORY_API_URL, API_TIMEOUT_SECONDS
from ai.core.request_context import inventory_api_headers
from ai.schemas.inventory_schemas import (
    InventoryLevelsInput,
    InventoryLevelsOutput,
    InventoryHistoryInput,
    InventoryHistoryOutput,
    BurnRateInput,
    BurnRateOutput,
    LowStockInput,
    LowStockOutput,
)

logger = logging.getLogger("amic_agentic_ai.inventory_tools")

def _normalize_material_id(raw_id: str) -> str:
    """Sanitize and normalize material identifier against injection and formatting bugs."""
    if not raw_id:
        raise ValueError("A material ID is required.")
    cleaned = str(raw_id).strip().upper()
    # Remove potentially dangerous characters
    cleaned = "".join(c for c in cleaned if c.isalnum() or c in ("-", "_"))
    if not cleaned:
        raise ValueError("A material ID is required.")
    return cleaned


# ── TOOL 1: get_inventory_levels() ─────────────────────────────────────────

@tool(args_schema=InventoryLevelsInput)
def get_inventory_levels(materialId: str) -> Dict[str, Any]:
    """
    TOOL 1: Fetches the current stock, safety minimum stock, and warehouse capacity.
    Input: materialId (e.g. 'RM001', 'RM-STEEL-001')
    Output: {"materialId": "RM001", "currentStock": 350, "minimumStock": 200, "maximumStock": 1000}
    """
    safe_id = _normalize_material_id(materialId)
    logger.info(f"[TOOL 1] Executing get_inventory_levels for: {safe_id}")

    level = _get_live_stock_level(safe_id)
    out = InventoryLevelsOutput(
        materialId=level["skuCode"],
        currentStock=float(level["currentStock"]),
        minimumStock=float(level["minimumStock"]),
        maximumStock=float(level["maximumStock"]),
    )
    return out.model_dump()


def _get_live_stock_level(material_id: str) -> Dict[str, Any]:
    """Return the exact stock-level record for one material from the API."""
    with httpx.Client(timeout=API_TIMEOUT_SECONDS) as client:
        response = client.get(
            f"{INVENTORY_API_URL}/stock-levels",
            headers=inventory_api_headers(),
        )
        response.raise_for_status()
        levels = response.json()

    if not isinstance(levels, list):
        raise ValueError("The inventory API returned an invalid stock-level response.")

    for level in levels:
        sku = str(level.get("skuCode", "")).upper()
        raw_material_id = str(level.get("rawMaterialId", ""))
        if material_id == sku or material_id == raw_material_id:
            return level

    raise ValueError(f"No live stock level exists for material '{material_id}'.")


# ── TOOL 2: query_inventory_history() ──────────────────────────────────────

@tool(args_schema=InventoryHistoryInput)
def query_inventory_history(materialId: str, periodDays: int = 7) -> Dict[str, Any]:
    """
    TOOL 2: Queries historical material consumption over a specified lookback period.
    Input: materialId, periodDays (default 7)
    Output: {"materialId": "RM001", "periodDays": 7, "consumption": 560}
    """
    safe_id = _normalize_material_id(materialId)
    safe_period = max(1, int(periodDays))
    logger.info(f"[TOOL 2] Querying consumption history for {safe_id} over {safe_period} days")

    level = _get_live_stock_level(safe_id)
    raw_material_id = level.get("rawMaterialId")
    if raw_material_id is None:
        raise ValueError(f"The live stock level for '{safe_id}' has no material ID.")

    with httpx.Client(timeout=API_TIMEOUT_SECONDS) as client:
        response = client.get(
            f"{INVENTORY_API_URL}/{raw_material_id}/history",
            headers=inventory_api_headers(),
        )
        response.raise_for_status()
        history = response.json()

    if not isinstance(history, list):
        raise ValueError("The inventory API returned an invalid history response.")

    cutoff = datetime.now(timezone.utc) - timedelta(days=safe_period)
    total_consumption = 0.0
    for entry in history:
        if str(entry.get("transactionType", "")).upper() != "CONSUMED":
            continue
        raw_date = entry.get("date")
        try:
            occurred_at = datetime.fromisoformat(str(raw_date).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            continue
        if occurred_at.tzinfo is None:
            occurred_at = occurred_at.replace(tzinfo=timezone.utc)
        if occurred_at >= cutoff:
            total_consumption += float(entry.get("quantity") or 0)

    out = InventoryHistoryOutput(
        materialId=str(level.get("skuCode") or safe_id),
        periodDays=safe_period,
        consumption=round(total_consumption, 2),
    )
    return out.model_dump()


# ── TOOL 3: calculate_burn_rate() ──────────────────────────────────────────

@tool(args_schema=BurnRateInput)
def calculate_burn_rate(consumption: float, periodDays: int, materialId: Optional[str] = None) -> Dict[str, Any]:
    """
    TOOL 3: Calculates average daily consumption rate from total consumption and days.
    Input: consumption (>= 0), periodDays (> 0)
    Safe Failure: Handles periodDays <= 0 without division by zero error.
    Output: {"materialId": "RM001", "burnRate": 80.0}
    """
    safe_id = _normalize_material_id(materialId or "")
    logger.info(f"[TOOL 3] Calculating burn rate for {safe_id}: {consumption} units over {periodDays} days")

    # Safe error handling: Prevent division by zero
    if periodDays <= 0:
        logger.warning(f"[TOOL 3] Safe failure: periodDays ({periodDays}) <= 0. Returning 0.0 to prevent division by zero.")
        return BurnRateOutput(materialId=safe_id, burnRate=0.0).model_dump()

    if consumption < 0:
        logger.warning(f"[TOOL 3] Negative consumption ({consumption}) clamped to 0.")
        consumption = 0.0

    calculated_rate = round(float(consumption) / float(periodDays), 2)
    
    out = BurnRateOutput(
        materialId=safe_id,
        burnRate=calculated_rate
    )
    return out.model_dump()


# ── TOOL 4: detect_low_stock() ─────────────────────────────────────────────

@tool(args_schema=LowStockInput)
def detect_low_stock(
    currentStock: float,
    minimumStock: float,
    burnRate: float,
    daysRemaining: Optional[float] = None,
    supplierLeadTime: float = 0.0,
    materialId: Optional[str] = None,
) -> Dict[str, Any]:
    """
    TOOL 4: Evaluates inventory against minimum thresholds, burn rates, and lead times.
    Calculates days of supply remaining and flags low stock situations.
    Safe Failure: If burnRate == 0, safe buffer assigned (no division by zero).
    Output: {"materialId": "RM001", "lowStock": true, "daysRemaining": 4.37, "severity": "HIGH"}
    """
    safe_id = _normalize_material_id(materialId or "")
    logger.info(f"[TOOL 4] Detecting stock status for {safe_id}: stock={currentStock}, min={minimumStock}, burn={burnRate}")

    current_stock = max(0.0, float(currentStock))
    min_stock = max(0.0, float(minimumStock))
    burn_rate = max(0.0, float(burnRate))
    lead_time = max(0.0, float(supplierLeadTime))

    # Calculate days remaining if not supplied
    if daysRemaining is None:
        if burn_rate > 0:
            # Case 1: 350 / 80 = 4.375
            days_rem = round(current_stock / burn_rate, 3)
        else:
            # Case 3: Burn rate is 0 -> Infinite safe buffer, no division error!
            days_rem = 999.0
    else:
        days_rem = round(float(daysRemaining), 3)

    # Determine low stock condition
    # Stock is low if below minimum OR will breach safety stock within lead time horizon (leadTime * 1.5)
    is_below_min = current_stock <= min_stock
    is_near_runout = days_rem <= (lead_time * 1.5)
    low_stock = is_below_min or is_near_runout

    # Assess severity level
    if current_stock <= (min_stock * 0.5) or days_rem <= lead_time:
        severity = "CRITICAL"
    elif low_stock:
        severity = "HIGH"
    elif days_rem <= (lead_time * 3.0):
        severity = "MEDIUM"
    else:
        severity = "NORMAL"

    out = LowStockOutput(
        materialId=safe_id,
        lowStock=low_stock,
        daysRemaining=days_rem,
        severity=severity
    )
    return out.model_dump()


# Export allow-listed tool collection for LangGraph ToolNode
INVENTORY_TOOLS = [
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock,
]

