from __future__ import annotations

from typing import TYPE_CHECKING, Any
from math import isfinite

from ai.core.state import AgentState
from ai.tools.quality_tools import recommend_quarantine

if TYPE_CHECKING:
    from psycopg import Connection


MANDATORY_AGENTS = (
    "Planner",
    "Data Extraction",
    "Purchasing",
    "Validation/Safety",
)


def run_quality_validation(
    state: AgentState,
    connection: Connection[Any] | None = None,
) -> AgentState:
    """Run Quality tools inside the existing Validation/Safety stage."""
    if connection is None:
        from ai.core.config import settings
        from psycopg import connect
        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return run_quality_validation(state, owned_connection)
    defect = state.get("quality_data", {}).get("defect", {})
    recommendation = recommend_quarantine(defect, connection)
    has_quarantined_inventory = (
        _has_quarantined_inventory(recommendation["affectedInventory"], connection)
        if recommendation["affectedInventory"]
        else _has_quarantined_batch(recommendation["batchId"], connection)
    )
    if has_quarantined_inventory:
        outcome = ({**recommendation, "valid": False} if recommendation["affectedInventory"] else {})
        outcome.update(
            {
                "valid": False,
                "riskLevel": "HIGH",
                "reason": "Associated inventory is quarantined",
            }
        )
        requires_approval = False
    else:
        reason = _validate_purchase_order(
            state.get("purchasing_data", {}).get("purchase_order") or state.get("draft_po") or state.get("purchasing_data", {}).get("draft_po"),
            state.get("purchasing_data", {}).get("business_rules"),
        )
        if reason:
            outcome = {
                "valid": False,
                "riskLevel": recommendation["riskLevel"],
                "reason": reason,
            }
            requires_approval = False
        else:
            outcome = recommendation
            requires_approval = recommendation["quarantineRequired"]

    reason = outcome.get("reason")
    if recommendation["quarantineRequired"] and not reason:
        reason = "Defect assessment recommends quarantine; QA inspection is required"
    valid = not has_quarantined_inventory and not reason
    outcome = {**recommendation, **outcome, "valid": valid, "isValid": valid,
               "outcome": "PASSED" if valid else "BLOCKED",
               "failedChecks": [] if valid else ["qualitySafety" if has_quarantined_inventory or recommendation["quarantineRequired"] else "purchaseOrder"],
               "requiredAction": "NONE" if valid else "QA_REVIEW" if has_quarantined_inventory or recommendation["quarantineRequired"] else "CORRECT_DATA",
               "reason": reason or "Quality checks passed"}
    tool_results = dict(state.get("tool_results", {}))
    tool_results["recommend_quarantine"] = recommendation
    return {
        **state,
        "current_agent": "Validation/Safety",
        "quality_data": {
            **state.get("quality_data", {}),
            "recommendation": recommendation,
            "validation": outcome,
        },
        "tool_results": tool_results,
        "final_outcome": None,
        "requires_approval": requires_approval,
    }


def _has_quarantined_inventory(
    inventory_ids: list[str],
    connection: Connection[Any] | None,
) -> bool:
    if not inventory_ids:
        return False
    if connection is None:
        from ai.core.config import settings
        from psycopg import connect

        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return _query_has_quarantined_inventory(inventory_ids, owned_connection)
    return _query_has_quarantined_inventory(inventory_ids, connection)


def _has_quarantined_batch(
    batch_id: str,
    connection: Connection[Any] | None,
) -> bool:
    if connection is None:
        from ai.core.config import settings
        from psycopg import connect

        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return _query_has_quarantined_batch(batch_id, owned_connection)
    return _query_has_quarantined_batch(batch_id, connection)


def _validate_purchase_order(
    purchase_order: dict[str, Any] | None,
    business_rules: dict[str, Any] | None,
) -> str | None:
    if purchase_order is None:
        return None

    supplier = str(purchase_order.get("supplier") or purchase_order.get("supplierName") or purchase_order.get("supplierId") or "").strip()
    if not supplier:
        return "Supplier is required"

    quantity = _number(purchase_order.get("quantity"))
    if quantity is None or quantity <= 0:
        return "Quantity must be greater than zero"

    budget = _number(purchase_order.get("budget") if "budget" in purchase_order else purchase_order.get("budgetLimit"))
    if budget is None or budget < 0:
        return "Budget must be zero or greater"

    rules = business_rules or {}
    allowed_suppliers = rules.get("allowedSuppliers")
    if allowed_suppliers and supplier not in allowed_suppliers:
        return "Supplier is not allowed by business rules"

    max_quantity = _number(rules.get("maxQuantity"))
    if max_quantity is not None and quantity > max_quantity:
        return "Quantity exceeds the business rule limit"

    max_budget = _number(rules.get("maxBudget"))
    if max_budget is not None and budget > max_budget:
        return "Budget exceeds the business rule limit"

    return None


def _number(value: Any) -> float | None:
    try:
        number = None if value is None or isinstance(value, bool) else float(value)
        return number if number is not None and isfinite(number) else None
    except (TypeError, ValueError, OverflowError):
        return None


def _query_has_quarantined_inventory(
    inventory_ids: list[str],
    connection: Connection[Any],
) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            'SELECT 1 FROM "InventoryRolls" '
            '''WHERE "RollIdentifier" = ANY(%s) AND (UPPER("Status") IN (%s, 'LOCKED', 'ON HOLD') OR EXISTS (SELECT 1 FROM "Quarantines" q WHERE q."InventoryRollId" = "InventoryRolls"."RollIdentifier" AND q."Status" = 'Active')) LIMIT 1''',
            (inventory_ids, "QUARANTINED"),
        )
        return cursor.fetchone() is not None


def _query_has_quarantined_batch(
    batch_id: str,
    connection: Connection[Any],
) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            'SELECT 1 FROM "InventoryRolls" '
            '''WHERE "BatchId" = %s AND (UPPER("Status") IN (%s, 'LOCKED', 'ON HOLD') OR EXISTS (SELECT 1 FROM "Quarantines" q WHERE q."InventoryRollId" = "InventoryRolls"."RollIdentifier" AND q."Status" = 'Active')) LIMIT 1''',
            (batch_id, "QUARANTINED"),
        )
        return cursor.fetchone() is not None
