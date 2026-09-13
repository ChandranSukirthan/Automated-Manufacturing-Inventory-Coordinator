"""Read-only quarantine recommendation for the Validation/Safety Agent."""

from __future__ import annotations

from typing import Any

from .analyze_defect_context import analyze_defect_context
from .check_related_inventory import BatchReader, check_related_inventory


def recommend_quarantine(
    defect: dict[str, Any],
    client: BatchReader,
    related_inventory: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Combine defect assessment and API inventory data into a recommendation.

    This function only returns a recommendation. It never calls a mutation
    endpoint and never changes inventory or quarantine state.
    """
    context = analyze_defect_context(defect)
    inventory = related_inventory or check_related_inventory(context["batchId"], client)
    return {
        "batchId": context["batchId"],
        "quarantineRequired": context["quarantineRequired"],
        "affectedInventory": inventory["affectedInventory"],
        "riskLevel": _risk_level(context["severity"]),
    }


def _risk_level(value: Any) -> str:
    severity = str(value or "").strip().upper()
    if severity == "CRITICAL":
        return "CRITICAL"
    if severity == "HIGH":
        return "HIGH"
    if severity == "MEDIUM":
        return "MEDIUM"
    return "LOW"