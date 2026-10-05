import threading
import multiprocessing
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient

from ai.core.config import settings
from ai.core.state import WorkflowStatus
from ai.graph import workflow
from ai.main import app
from ai.session_store import SessionStore


def _hold_workflow_lock(store_path, ready, release):
    from ai.graph import workflow as child_workflow
    child_workflow.WORKFLOW_SESSIONS = SessionStore(store_path)
    with child_workflow._workflow_lock("WF-MULTIPROCESS"):
        ready.set()
        release.wait(10)


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
    assert result["current_agent"] == "Student 2 Supplier Selection"
    assert result["status"] == WorkflowStatus.Failed
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


def test_nonblocking_lock_detects_an_active_copy_of_the_same_workflow():
    with workflow._workflow_lock("WF-CROSS-PROCESS"):
        with pytest.raises(BlockingIOError):
            with workflow._workflow_lock("WF-CROSS-PROCESS", blocking=False):
                pass


def test_operating_system_lock_coordinates_two_ai_processes(tmp_path, monkeypatch):
    store_path = tmp_path / "shared-sessions.sqlite3"
    monkeypatch.setattr(workflow, "WORKFLOW_SESSIONS", SessionStore(store_path))
    context = multiprocessing.get_context("spawn")
    ready, release = context.Event(), context.Event()
    process = context.Process(target=_hold_workflow_lock, args=(store_path, ready, release))
    process.start()
    try:
        assert ready.wait(10)
        with pytest.raises(BlockingIOError):
            with workflow._workflow_lock("WF-MULTIPROCESS", blocking=False):
                pass
    finally:
        release.set()
        process.join(10)
        if process.is_alive():
            process.terminate()
            process.join(5)
    assert process.exitcode == 0


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


def test_queued_request_id_reuse_cannot_change_its_budget(auth_headers):
    from fastapi import BackgroundTasks
    from fastapi import HTTPException
    from ai.routes.workflow_routes import RunWorkflowRequest, trigger_workflow
    actor = {"sub": "scm", "role": "SupplyChainManager"}
    request = dict(objective="Replenish", workflowId="WF-QUEUED", materialId="SKU-A",
                   budgetLimit=100, background=True)
    trigger_workflow(RunWorkflowRequest(**request), auth_headers["Authorization"], BackgroundTasks(), actor)
    with pytest.raises(HTTPException) as error:
        trigger_workflow(RunWorkflowRequest(**{**request, "budgetLimit": 200}),
                         auth_headers["Authorization"], BackgroundTasks(), actor)
    assert error.value.status_code == 409
    assert workflow.WORKFLOW_SESSIONS["WF-QUEUED"]["queued_request"]["budgetLimit"] == 100


def test_maintenance_does_not_run_purchasing(monkeypatch):
    monkeypatch.setattr(workflow, "_maintenance_node", lambda state: {"workflow_type": "Maintenance", "status": WorkflowStatus.WaitingForApproval, "current_agent": "Maintenance Review"})
    def procurement_must_not_run(_):
        raise AssertionError("Maintenance entered procurement")
    monkeypatch.setattr(workflow, "data_extraction_node", procurement_must_not_run)
    graph = workflow.build_workflow_graph()
    result = graph.invoke({"workflow_id": "WF-MAINT", "workflow_type": "Maintenance", "machine_id": "machine", "objective": "Maintenance", "completed_steps": [], "errors": []})
    assert result["status"] == WorkflowStatus.WaitingForApproval
    assert result.get("draft_po") is None


def test_production_failure_cannot_continue_into_purchasing(monkeypatch):
    monkeypatch.setattr(workflow, "data_extraction_node", lambda _: {"status": WorkflowStatus.Running})
    monkeypatch.setattr(workflow, "production_analysis_node", lambda _: (_ for _ in ()).throw(RuntimeError("Telemetry offline")))
    calls = []
    monkeypatch.setattr(workflow, "purchasing_node", lambda state: calls.append(state) or {})
    result = workflow.build_workflow_graph().invoke({"workflow_id": "WF-ISOLATED", "workflow_type": "Procurement",
        "objective": "Procure material", "errors": [], "completed_steps": []})
    assert result["status"] == WorkflowStatus.Failed
    assert calls == []


def test_restart_retry_preserves_constraints_and_uses_fresh_authorization(monkeypatch, auth_headers):
    from ai.core.request_context import inventory_api_headers
    captured = []
    class App:
        def invoke(self, state):
            captured.append((state.copy(), inventory_api_headers().get("Authorization")))
            return {**state, "status": WorkflowStatus.WaitingForApproval}
    monkeypatch.setattr(workflow, "COMPILED_APP", App())
    workflow.WORKFLOW_SESSIONS["WF-RESTART"] = {
        "workflow_id": "WF-RESTART", "objective": "Replenish", "workflow_type": "Procurement",
        "material_id": "SKU-1", "status": "Running", "current_agent": "Data Extraction",
        "required_quantity": 8, "net_deficit": 8, "budget_limit": 100,
        "specification": "Exact film gauge", "quality_requirement": "Food grade",
        "preferred_region": "Sri Lanka", "required_by_date": "2026-10-10", "procurement_request_id": 12,
    }
    with TestClient(app) as client:
        interrupted = workflow.WORKFLOW_SESSIONS["WF-RESTART"]
        assert interrupted["status"] == "Failed"
        assert interrupted["current_agent"] == "Interrupted"
        response = client.post("/api/workflows/WF-RESTART/retry", headers=auth_headers)
        assert response.status_code == 200
    state, authorization = captured[0]
    assert state["specification"] == "Exact film gauge"
    assert state["quality_requirement"] == "Food grade"
    assert state["budget_limit"] == 100
    assert state["required_by_date"] == "2026-10-10"
    assert state["procurement_request_id"] == 12
    assert authorization == auth_headers["Authorization"]
    assert workflow.WORKFLOW_SESSIONS["WF-RESTART"]["status"] == WorkflowStatus.WaitingForApproval


def test_supply_chain_manager_cannot_trigger_maintenance_or_reject_its_request(auth_headers):
    client = TestClient(app)
    assert client.post("/api/workflows/run", headers=auth_headers, json={
        "objective": "Maintenance", "workflowType": "Maintenance", "machineId": "machine"}).status_code == 403
    workflow.WORKFLOW_SESSIONS["WF-MAINT"] = {"workflow_id": "WF-MAINT", "workflow_type": "Maintenance",
        "status": "WaitingForApproval", "approval_status": "Pending"}
    assert client.post("/api/workflows/WF-MAINT/reject", headers=auth_headers, json={"reason": "Reject"}).status_code == 409


def test_graph_runtime_failure_is_durable(monkeypatch):
    class App:
        def invoke(self, _):
            raise RuntimeError("Graph interrupted")
    monkeypatch.setattr(workflow, "COMPILED_APP", App())
    result = workflow.run_workflow("Replenish", workflow_id="WF-RUNTIME", material_id="SKU-1")
    assert result["status"] == WorkflowStatus.Failed
    assert "Graph interrupted" in workflow.WORKFLOW_SESSIONS["WF-RUNTIME"]["errors"]
