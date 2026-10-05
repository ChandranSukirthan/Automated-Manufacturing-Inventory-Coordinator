import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from ai.main import app
from ai.core.supplier_ranking import supplier_rank_key
from ai.schemas.inventory_schemas import InventoryLevelsOutput
from ai.tools.inventory_tools import detect_low_stock, _normalize_material_id
from ai.tools.production_tools import calculate_production_impact, check_maintenance_requirement
from ai.session_store import clean_state
from ai.graph.workflow import sync_to_database as publish_state
from ai.graph import workflow


def test_publication_signature_matches_transmitted_json(monkeypatch):
    import hashlib
    import hmac
    import json
    import httpx

    # The suite's autouse inventory fixture replaces the public Client alias.
    from httpx._client import Client as real_client
    requests = []

    def backend(request):
        requests.append(request)
        body = request.content.decode("utf-8")
        # Match the backend's JsonElement.GetRawText() signature contract.
        raw_state = body[len('{"state":'):-1]
        expected = hmac.new(
            workflow.settings.jwt_secret_key.encode(),
            (request.headers["X-AI-Timestamp"] + "\n" + raw_state).encode(),
            hashlib.sha256,
        ).hexdigest()
        assert hmac.compare_digest(expected, request.headers["X-AI-Signature"])
        assert request.headers["content-type"] == "application/json"
        decoded = json.loads(raw_state)
        assert decoded["objective"] == "Replenish paper — 1,000 KG"
        assert decoded["inventory_data"]["currentStock"] == 125.0
        assert "authorization" not in decoded
        return httpx.Response(200, json={"status": "saved"})

    monkeypatch.setattr(httpx, "Client", lambda **kwargs: real_client(
        transport=httpx.MockTransport(backend), **kwargs))
    monkeypatch.setattr(workflow, "WORKFLOW_SESSIONS", {})
    state = {"workflow_id": "WF-WIRE-SIGNATURE", "objective": "Replenish paper — 1,000 KG",
             "status": "Running", "inventory_data": {"currentStock": 125.0},
             "authorization": "never-publish-this"}
    assert publish_state(state) is True
    assert len(requests) == 1
    assert state["synchronization_pending"] is False


def test_predictive_warning_without_selected_supplier():
    result = detect_low_stock.invoke(dict(materialId="RM001", currentStock=350, minimumStock=200, burnRate=80))
    assert result["daysRemaining"] == 4.375
    assert result["lowStock"] is True


def test_delivery_lead_time_preserves_safety_stock():
    result = detect_low_stock.invoke(dict(materialId="RM001", currentStock=1000, minimumStock=800, burnRate=10, supplierLeadTime=30))
    assert result["lowStock"] is True


@pytest.mark.parametrize("value", [float("nan"), float("inf"), -1])
def test_inventory_rejects_invalid_tool_output(value):
    with pytest.raises(ValidationError):
        InventoryLevelsOutput(materialId="RM001", currentStock=value, minimumStock=200, maximumStock=1000)


def test_invalid_material_cannot_be_rewritten_as_another_material():
    with pytest.raises(ValueError):
        _normalize_material_id("RM001; DROP TABLE")


def test_supplier_rank_uses_rounded_order_cost_and_zero_day_delivery():
    low_unit_price = dict(supplierId="A", supplierStatus="APPROVED", origin="Internal", totalCost=12000, leadTimeDays=0)
    lower_order_cost = dict(supplierId="B", supplierStatus="APPROVED", origin="Internal", totalCost=9000, leadTimeDays=7)
    assert min([low_unit_price, lower_order_cost], key=supplier_rank_key)["supplierId"] == "B"
    assert supplier_rank_key({**lower_order_cost, "leadTimeDays": 0}) < supplier_rank_key(lower_order_cost)


def test_production_conversion_and_invalid_maintenance():
    assert calculate_production_impact(10000, 6000, 2)["adjustedOutput"] == 3000
    with pytest.raises(ValueError):
        check_maintenance_requirement(float("nan"), 500)


def test_nested_prompts_and_tokens_are_excluded():
    assert clean_state({"nested": {"prompt": "private", "accessToken": "secret", "summary": "done"}}) == {"nested": {"summary": "done"}}


def test_failed_publication_is_durable_and_not_manager_ready(monkeypatch):
    import httpx
    class Unavailable:
        def __init__(self, **kwargs): pass
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def put(self, *args, **kwargs): raise httpx.TimeoutException("unavailable")
    monkeypatch.setattr(httpx, "Client", Unavailable)
    state = dict(workflow_id="WF-PUBLISH", objective="Replenish", status="WaitingForApproval")
    assert publish_state(state) is False
    restored = workflow.WORKFLOW_SESSIONS["WF-PUBLISH"]
    assert restored["synchronization_pending"] is True
    assert workflow.get_final_output(restored)["reviewStatus"] == "SYNC_PENDING"


@pytest.mark.parametrize("path,payload", [("/quality/recommendation", {"severity": "HIGH", "description": "defect"}), ("/api/tools/production-impact", {"target": 10, "availableMaterial": 5}), ("/api/agent/extract-data", {"batchName": "RM001"})])
def test_internal_ai_routes_require_backend_authentication(path, payload):
    assert TestClient(app).post(path, json=payload).status_code == 401


def test_supply_manager_cannot_make_quality_recommendation(auth_headers):
    assert TestClient(app).post("/quality/recommendation", json={"severity": "HIGH", "description": "defect"}, headers=auth_headers).status_code == 403
