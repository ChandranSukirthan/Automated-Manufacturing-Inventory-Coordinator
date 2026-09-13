"""Read-only related inventory lookup for the Validation/Safety Agent."""

from __future__ import annotations

from typing import Any, Protocol


class BatchReader(Protocol):
    """Minimum API client contract required by the inventory tool."""

    def get_batch(self, batch_id: str) -> dict[str, Any]: ...


def check_related_inventory(
    batch: dict[str, Any] | str, client: BatchReader
) -> dict[str, Any]:
    """Read inventory roll IDs related to a batch through the backend API."""
    batch_id = batch.get("batchId") if isinstance(batch, dict) else batch
    normalized_batch_id = _required_batch_id(batch_id)
    batch_response = client.get_batch(normalized_batch_id)
    inventory = batch_response.get("inventoryRolls", [])
    affected_inventory = [
        str(roll["id"])
        for roll in inventory
        if roll.get("id") is not None
    ]
    return {
        "batchId": normalized_batch_id,
        "affectedInventory": affected_inventory,
    }


def _required_batch_id(value: Any) -> str:
    batch_id = str(value or "").strip()
    if not batch_id:
        raise ValueError("batchId is required")
    return batch_id