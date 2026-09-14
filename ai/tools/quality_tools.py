from __future__ import annotations

from collections.abc import Mapping
from typing import TYPE_CHECKING, Any, Protocol

if TYPE_CHECKING:
    from psycopg import Connection


PRODUCT_TYPES = {
    "BoxPouch",
    "BiscuitPackaging",
    "TeaBag",
    "Bag",
    "Can",
    "Bottle",
}
SEVERITIES = {"LOW", "MEDIUM", "HIGH", "CRITICAL"}
_SERIOUS_TERMS = {"contamination", "unsafe", "structural", "material defect", "failure"}


class ConnectionFactory(Protocol):
    def __call__(self) -> Connection[Any]: ...


def analyze_defect_context(
    defect: Mapping[str, Any],
    connection: Connection[Any] | None = None,
) -> dict[str, Any]:
    """Validate a defect and produce a deterministic quarantine assessment."""
    batch_id = _required_text(defect.get("batchId"), "batchId")
    product_type = _required_text(defect.get("productType"), "productType")
    severity_value = _required_text(defect.get("severity"), "severity")
    description = _required_text(defect.get("description"), "description")

    if product_type not in PRODUCT_TYPES:
        raise ValueError(f"productType must be one of: {', '.join(sorted(PRODUCT_TYPES))}")

    severity = severity_value.upper()
    if severity not in SEVERITIES:
        raise ValueError(f"severity must be one of: {', '.join(sorted(SEVERITIES))}")

    previous_severe_defect = False
    if connection is not None:
        previous_severe_defect = _has_previous_severe_defect(connection, batch_id)

    quarantine_required = severity in {"HIGH", "CRITICAL"}
    if severity == "MEDIUM":
        quarantine_required = previous_severe_defect or _contains_serious_term(description)

    return {
        "batchId": batch_id,
        "severity": severity_value,
        "quarantineRequired": quarantine_required,
    }


def check_related_inventory(
    batch_id: str | Mapping[str, Any],
    connection: Connection[Any] | None = None,
) -> dict[str, Any]:
    """Read inventory roll IDs associated with a batch from PostgreSQL."""
    normalized_batch_id = _required_text(
        batch_id.get("batchId") if isinstance(batch_id, Mapping) else batch_id,
        "batchId",
    )

    if connection is None:
        from ai.core.config import settings
        from psycopg import connect

        with connect(settings.database_url) as owned_connection:
            return _check_related_inventory(normalized_batch_id, owned_connection)
    return _check_related_inventory(normalized_batch_id, connection)


def recommend_quarantine(
    defect: Mapping[str, Any],
    connection: Connection[Any] | None = None,
    related_inventory: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Combine defect and inventory facts into a read-only recommendation."""
    context = analyze_defect_context(defect, connection)
    inventory = related_inventory or check_related_inventory(context["batchId"], connection)
    return {
        "batchId": context["batchId"],
        "quarantineRequired": context["quarantineRequired"],
        "affectedInventory": list(inventory["affectedInventory"]),
        "riskLevel": _risk_level(context["severity"]),
    }


def _check_related_inventory(
    batch_id: str, connection: Connection[Any]
) -> dict[str, Any]:
    with connection.cursor() as cursor:
        cursor.execute('SELECT 1 FROM "Batches" WHERE "Id" = %s LIMIT 1', (batch_id,))
        if cursor.fetchone() is None:
            raise ValueError(f"Batch was not found: {batch_id}")

        cursor.execute(
            'SELECT "Id" FROM "InventoryRolls" WHERE "BatchId" = %s ORDER BY "Id"',
            (batch_id,),
        )
        affected_inventory = [str(row[0]) for row in cursor.fetchall() if row[0] is not None]
    return {"batchId": batch_id, "affectedInventory": affected_inventory}


def _has_previous_severe_defect(connection: Connection[Any], batch_id: str) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            'SELECT 1 FROM "DefectReports" '
            'WHERE "BatchId" = %s AND UPPER("Severity") IN (%s, %s) LIMIT 1',
            (batch_id, "HIGH", "CRITICAL"),
        )
        return cursor.fetchone() is not None


def _required_text(value: Any, field_name: str) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _contains_serious_term(description: str) -> bool:
    normalized = description.casefold()
    return any(term in normalized for term in _SERIOUS_TERMS)


def _risk_level(value: Any) -> str:
    severity = str(value or "").strip().upper()
    return severity if severity in SEVERITIES else "LOW"
