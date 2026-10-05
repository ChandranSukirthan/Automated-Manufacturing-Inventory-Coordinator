import asyncio
import pytest
from pydantic import ValidationError
from ai.routes.workflow_routes import RunWorkflowRequest
from ai.main import _send_alert


@pytest.mark.parametrize("quantity", [None, 0, -1, float("nan"), float("inf")])
def test_manual_trigger_requires_finite_positive_quantity(quantity):
    with pytest.raises(ValidationError):
        RunWorkflowRequest(objective="More stock", triggerType="Manual", requestedQuantity=quantity)


def test_low_stock_alert_wakes_workflow_with_stable_identifier(monkeypatch):
    monkeypatch.setenv("AMIC_MONITOR_TOKEN", "test-token")
    calls = []
    class Response:
        def raise_for_status(self): pass
        def json(self): return {"id": 42}
    class Client:
        async def post(self, url, **kwargs):
            calls.append((url, kwargs))
            return Response()
    assert asyncio.run(_send_alert(Client(), {"sku": "SKU-A", "category": "Film"}, False)) is True
    assert len(calls) == 2
    payload = calls[1][1]["json"]
    assert payload["triggerType"] == "AutoLowStock"
    assert payload["workflowId"] == "WF-AUTO-STOCK-42"
    assert calls[1][1]["headers"]["Authorization"] == "Bearer test-token"


def test_failed_agent_trigger_is_not_marked_delivered():
    class Client:
        async def post(self, *args, **kwargs): raise ConnectionError("offline")
    assert asyncio.run(_send_alert(Client(), {"sku": "SKU-A"}, False)) is False
