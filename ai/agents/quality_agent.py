from __future__ import annotations

from typing import TYPE_CHECKING, Any

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
    defect = state.get("quality_data", {}).get("defect", {})
    recommendation = recommend_quarantine(defect, connection)
    if _has_quarantined_inventory(defect["batchId"], connection):
        outcome = {
            "valid": False,
            "riskLevel": "HIGH",
            "reason": "Associated inventory is quarantined",
        }
        requires_approval = False
    else:
        outcome = recommendation
        requires_approval = recommendation["quarantineRequired"]

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
    batch_id: str,
    connection: Connection[Any] | None,
) -> bool:
    if connection is None:
        from ai.core.config import settings
        from psycopg import connect

        with connect(settings.database_url) as owned_connection:
            return _query_has_quarantined_inventory(batch_id, owned_connection)
    return _query_has_quarantined_inventory(batch_id, connection)


def _query_has_quarantined_inventory(
    batch_id: str,
    connection: Connection[Any],
) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            'SELECT 1 FROM "InventoryRolls" '
            'WHERE "BatchId" = %s AND UPPER("Status") = %s LIMIT 1',
            (batch_id, "QUARANTINED"),
        )
        return cursor.fetchone() is not None
