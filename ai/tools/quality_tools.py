from __future__ import annotations
from ai.schemas.tool_contracts import QuarantineRecommendation, checked_output

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
    batch_id = str(defect.get("batchId") or "").strip()
    severity_value = _required_text(defect.get("severity"), "severity")
    description = _required_text(defect.get("description"), "description")

    product_type = str(defect.get("productType") or "").strip()
    if product_type and product_type not in PRODUCT_TYPES:
        raise ValueError(f"productType must be one of: {', '.join(sorted(PRODUCT_TYPES))}")

    severity = severity_value.upper()
    if severity not in SEVERITIES:
        raise ValueError(f"severity must be one of: {', '.join(sorted(SEVERITIES))}")

    previous_severe_defect = False
    if connection is not None and batch_id:
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

        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return _check_related_inventory(normalized_batch_id, owned_connection)
    return _check_related_inventory(normalized_batch_id, connection)


@checked_output(QuarantineRecommendation)
def recommend_quarantine(
    defect: Mapping[str, Any],
    connection: Connection[Any] | None = None,
    related_inventory: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Combine defect and inventory facts into a read-only recommendation."""
    if connection is None and related_inventory is None:
        from ai.core.config import settings
        from psycopg import connect
        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return recommend_quarantine(defect, owned_connection)
    context = analyze_defect_context(defect, connection)
    inventory = related_inventory or _inventory_for_defect(defect, context, connection)
    if not context["batchId"]:
        context["batchId"] = inventory["batchId"]
        if connection is not None and context["severity"].upper() == "MEDIUM":
            context["quarantineRequired"] = any(_has_previous_severe_defect(connection, batch) for batch in (inventory.get("batchIds") or [context["batchId"]])) or _contains_serious_term(str(defect.get("description", "")))
    result = {
        "batchId": context["batchId"],
        "quarantineRequired": context["quarantineRequired"],
        "affectedInventory": list(inventory["affectedInventory"]),
        "riskLevel": _risk_level(context["severity"]),
    }
    if "inventoryContext" in inventory:
        result["inventoryContext"] = inventory["inventoryContext"]
    return result


def _inventory_for_defect(
    defect: Mapping[str, Any],
    context: dict[str, Any],
    connection: Connection[Any] | None,
) -> dict[str, Any]:
    sku_code = str(defect.get("skuCode") or "").strip()
    if sku_code:
        return _inventory_by_sku(
            sku_code,
            [str(value) for value in (defect.get("affectedInventory") or [])],
            connection,
        )
    if not context["batchId"]:
        raise ValueError("SKU code is required")
    return check_related_inventory(context["batchId"], connection)


def _inventory_by_sku(
    sku_code: str,
    selected_inventory: list[str],
    connection: Connection[Any] | None,
) -> dict[str, Any]:
    if connection is None:
        from ai.core.config import settings
        from psycopg import connect

        with connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as owned_connection:
            return _query_inventory_by_sku(sku_code, selected_inventory, owned_connection)
    return _query_inventory_by_sku(sku_code, selected_inventory, connection)


def _query_inventory_by_sku(
    sku_code: str,
    selected_inventory: list[str],
    connection: Connection[Any],
) -> dict[str, Any]:
    with connection.cursor() as cursor:
        query = (
            'SELECT i."Id", i."RollIdentifier", i."RawMaterialId", '
            'r."SkuCode", r."Name", i."BatchId", i."Status", '
            'i."CurrentQuantity", i."InitialQuantity" '
            'FROM "InventoryRolls" i JOIN "RawMaterials" r '
            'ON r."Id" = i."RawMaterialId" WHERE r."SkuCode" = %s'
        )
        params: tuple[Any, ...] = (sku_code,)
        if selected_inventory:
            query += ' AND i."RollIdentifier" = ANY(%s)'
            params += (selected_inventory,)
        query += ' ORDER BY i."Id"'
        cursor.execute(query, params)
        rows = [row for row in cursor.fetchall() if row and row[0] is not None]

    if not rows:
        raise ValueError("No inventory rolls were found for the selected SKU")
    if selected_inventory and len(rows) != len(set(selected_inventory)):
        raise ValueError("Some selected physical roll identifiers do not belong to this SKU")
    batches = sorted({str(row[5]).strip() for row in rows if row[5]})
    if not batches:
        raise ValueError("The inventory rolls have no batch identity; reconcile missing batches first")
    batch_id = batches[0] if len(batches) == 1 else f"MULTI-{sku_code.upper()}"
    return {
        "batchId": batch_id,
        "batchIds": batches,
        "affectedInventory": [str(row[1]) for row in rows],
        "inventoryContext": [
            {
                "inventoryRollId": str(row[1]),
                "rollIdentifier": row[1] or str(row[0]),
                "rawMaterialId": row[2],
                "rawMaterialSku": row[3],
                "rawMaterialName": row[4],
                "batchId": row[5],
                "status": row[6],
                "currentQuantity": row[7],
                "initialQuantity": row[8],
            }
            for row in rows
        ],
    }


def _check_related_inventory(
    batch_id: str, connection: Connection[Any]
) -> dict[str, Any]:
    with connection.cursor() as cursor:
        cursor.execute('SELECT 1 FROM "Batches" WHERE "Id" = %s LIMIT 1', (batch_id,))
        if cursor.fetchone() is None:
            raise ValueError(f"Batch was not found: {batch_id}")

        cursor.execute(
            'SELECT "RollIdentifier" FROM "InventoryRolls" WHERE "BatchId" = %s ORDER BY "Id"',
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
