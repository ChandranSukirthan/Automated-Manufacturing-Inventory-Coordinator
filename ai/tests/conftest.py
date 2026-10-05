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
def mock_inventory_read_boundary(monkeypatch, tmp_path):
    from ai.core.config import settings
    from ai.graph import workflow
    from ai.session_store import SessionStore
    monkeypatch.setattr(settings, "demo_mode", True)
    monkeypatch.setattr(settings, "db_port", 1)
    monkeypatch.setattr(settings, "gemini_api_key", "")
    monkeypatch.setattr(settings, "openai_api_key", "")
    monkeypatch.setattr(workflow, "sync_to_database", lambda *_: None)
    monkeypatch.setattr(workflow, "save_procurement_outcome", lambda *_: None)
    monkeypatch.setattr(workflow, "WORKFLOW_SESSIONS", SessionStore(tmp_path / "sessions.sqlite3"))
    from ai.routes import workflow_routes
    monkeypatch.setattr(workflow_routes, "WORKFLOW_SESSIONS", workflow.WORKFLOW_SESSIONS)
    import psycopg
    def offline_connection(*_args, **_kwargs):
        raise psycopg.OperationalError("Database boundary is mocked for offline tests")
    monkeypatch.setattr(psycopg, "connect", offline_connection)
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


@pytest.fixture
def auth_headers(monkeypatch):
    import base64, hashlib, hmac, json, time
    from ai.core.config import settings
    monkeypatch.setattr(settings, "jwt_secret_key", "offline-tests-key-at-least-thirty-two-characters")
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b"=").decode()
    header = encode({"alg": "HS256", "typ": "JWT"})
    payload = encode({"sub": "test-manager", "role": "SupplyChainManager", "exp": time.time() + 600,
                      "iss": settings.jwt_issuer, "aud": settings.jwt_audience})
    body = header + "." + payload
    signature = base64.urlsafe_b64encode(hmac.new(settings.jwt_secret_key.encode(), body.encode(), hashlib.sha256).digest()).rstrip(b"=").decode()
    return {"Authorization": "Bearer " + body + "." + signature}
