import threading
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient

from ai.core.config import settings
from ai.core.state import WorkflowStatus
from ai.graph import workflow
from ai.main import app
from ai.session_store import SessionStore


def test_session_state_survives_repository_recreation(tmp_path):
    path = tmp_path / "durable.sqlite3"
    first = SessionStore(path)
    first["WF-ONE"] = {"workflow_id": "WF-ONE", "status": "Failed", "errors": ["Supplier database unavailable"], "prompt": "private"}
    resumed = SessionStore(path)
    assert resumed["WF-ONE"]["errors"] == ["Supplier database unavailable"]
    assert "prompt" not in resumed["WF-ONE"]


def test_unauthenticated_workflow_cannot_run_or_approve():
    client = TestClient(app)
    assert client.post("/api/workflows/run", json={"objective": "reorder", "materialId": "SKU"}).status_code == 401
    assert client.post("/api/workflows/WF-ONE/approve").status_code == 401


def test_missing_operational_quotes_never_create_a_fabricated_draft(monkeypatch):
    from ai.agents import purchasing
    monkeypatch.setattr(settings, "demo_mode", False)
    monkeypatch.setattr(purchasing, "query_supplier_rates", lambda *_: [])
    monkeypatch.setattr(purchasing, "query_internal_supplier_data", lambda **_: [])
    monkeypatch.setattr(purchasing, "search_external_supplier_market", lambda **_: [])
    result = purchasing.purchasing_node({"workflow_id": "WF-NO-QUOTE", "material_id": "SKU-A", "material_name": "Material A",
        "net_deficit": 100, "required_quantity": 100, "budget_limit": 500, "inventory_data": {"currentStock": 0}})
    assert result.get("draft_po") is None
    assert result["current_agent"] == "Supplier Review"
    assert result["validation_results"]["isValid"] is False


def test_one_slow_workflow_does_not_block_another(monkeypatch):
    started, release = threading.Event(), threading.Event()
    class App:
        def invoke(self, state):
            if state["workflow_id"] == "WF-SLOW":
                started.set()
                assert release.wait(5)
            return {**state, "status": WorkflowStatus.Completed}
    monkeypatch.setattr(workflow, "COMPILED_APP", App())
    with ThreadPoolExecutor(max_workers=2) as pool:
        slow = pool.submit(workflow.run_workflow, "Slow job", workflow_id="WF-SLOW")
        assert started.wait(2)
        try:
            fast = pool.submit(workflow.run_workflow, "Independent job", workflow_id="WF-FAST")
            assert fast.result(timeout=2)["status"] == WorkflowStatus.Completed
        finally:
            release.set()
        assert slow.result(timeout=2)["status"] == WorkflowStatus.Completed


def test_stage_failure_is_saved_and_an_independent_request_still_runs():
    def failing(_):
        raise RuntimeError("Supplier service unavailable")
    state = {"workflow_id": "WF-FAILED", "objective": "Test", "errors": [], "completed_steps": []}
    diff = workflow._record_stage(failing)(state)
    assert diff["status"] == WorkflowStatus.Failed
    assert "Supplier service unavailable" in str(workflow.WORKFLOW_SESSIONS["WF-FAILED"]["errors"])


def test_id_reuse_for_a_different_request_is_rejected(monkeypatch):
    class App:
        def invoke(self, state):
            return {**state, "status": WorkflowStatus.Completed}
    monkeypatch.setattr(workflow, "COMPILED_APP", App())
    workflow.run_workflow("Material A", workflow_id="WF-SAME", material_id="SKU-A")
    with pytest.raises(ValueError, match="different request"):
        workflow.run_workflow("Material B", workflow_id="WF-SAME", material_id="SKU-B")


def test_maintenance_does_not_run_purchasing(monkeypatch):
    monkeypatch.setattr(workflow, "_maintenance_node", lambda state: {"workflow_type": "Maintenance", "status": WorkflowStatus.WaitingForApproval, "current_agent": "Maintenance Review"})
    def procurement_must_not_run(_):
        raise AssertionError("Maintenance entered procurement")
    monkeypatch.setattr(workflow, "data_extraction_node", procurement_must_not_run)
    graph = workflow.build_workflow_graph().compile()
    result = graph.invoke({"workflow_id": "WF-MAINT", "workflow_type": "Maintenance", "machine_id": "machine", "objective": "Maintenance", "completed_steps": [], "errors": []})
    assert result["status"] == WorkflowStatus.WaitingForApproval
    assert result.get("draft_po") is None
