"""Deterministic inventory API responses for offline agent tests.

The production tools use the authenticated ASP.NET API. Unit and workflow
tests must not depend on a locally running server, JWT, or PostgreSQL, so this
fixture replaces only their read boundary with representative API responses.
"""

from datetime import datetime, timezone

import pytest

from ai.tools import inventory_tools


class _HistoryResponse:
    def raise_for_status(self) -> None:
        return None

    def json(self):
        return [
            {
                "transactionType": "CONSUMED",
                "quantity": 560.0,
                "date": datetime.now(timezone.utc).isoformat(),
            }
        ]


class _HistoryClient:
    def __init__(self, **_):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def get(self, *_args, **_kwargs):
        return _HistoryResponse()


@pytest.fixture(autouse=True)
def mock_inventory_read_boundary(monkeypatch):
    def live_level(material_id: str):
        return {
            "rawMaterialId": 1,
            "skuCode": material_id,
            "currentStock": 350.0,
            "minimumStock": 200.0,
            "maximumStock": 1000.0,
        }

    monkeypatch.setattr(inventory_tools, "_get_live_stock_level", live_level)
    monkeypatch.setattr(inventory_tools.httpx, "Client", _HistoryClient)
