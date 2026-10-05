"""Real graph nodes with deterministic external read boundaries, demo mode disabled."""
from copy import deepcopy
import pytest
from ai.graph import workflow
from ai.core.config import settings
from ai.core.state import WorkflowStatus


@pytest.fixture
def pipeline(monkeypatch):
    import psycopg
    from ai.agents import purchasing, production_analysis, validation
    from ai.tools import production_tools
    monkeypatch.setattr(settings, "demo_mode", False)
    class ReadConnection:
        def __enter__(self): return self
        def __exit__(self, *_): return False
        def cursor(self): return self
        def execute(self, sql, *args): self.sql = sql
        def fetchone(self):
            if '"AgentWorkflows"' in self.sql: return (None,)
            if '"Suppliers"' in self.sql: return (True, "Supplier A")
            if 'SELECT "Name"' in self.sql: return ("Material A",)
            if '"RawMaterials"' in self.sql: return (1, "SKU-A", "Material A")
            raise AssertionError(self.sql)
    monkeypatch.setattr(psycopg, "connect", lambda *a, **kw: ReadConnection())
    schedule = lambda *a, **kw: {"plannedOutput": 500, "available": True}
    monkeypatch.setattr(production_tools, "query_production_schedule", schedule)
    monkeypatch.setattr(production_analysis, "query_production_schedule", schedule)
    monkeypatch.setattr(validation, "_check_material_quarantine_count", lambda *a, **kw: 0)
    monkeypatch.setattr(validation, "_check_historical_material_quality_risk", lambda *a: None)
    quote = dict(supplierId=9, supplierCode="SUP-A", supplierName="Supplier A",
        unitPrice=2, minimumOrderQuantity=20, packSize=10, availableQuantity=100,
        leadTimeDays=0, qualityEvidence="Food grade", verificationStatus="VERIFIED",
        supplierStatus="APPROVED")
    monkeypatch.setattr(purchasing, "query_supplier_rates", lambda *a: [])
    monkeypatch.setattr(purchasing, "query_internal_supplier_data", lambda **kw: [quote.copy()])
    market_inputs = []
    monkeypatch.setattr(purchasing, "search_external_supplier_market",
                        lambda **kw: market_inputs.append(kw) or [])
    received = {}
    for name in ["planner_node", "data_extraction_node", "production_analysis_node", "purchasing_node", "validation_node"]:
        original = getattr(workflow, name)
        def capture(state, original=original, name=name):
            received[name] = deepcopy(state)
            return original(state)
        capture.__name__ = name
        monkeypatch.setattr(workflow, name, capture)
    monkeypatch.setattr(workflow, "COMPILED_APP", workflow.build_workflow_graph())
    request = dict(objective="Replenish material", material_id="SKU-A", required_quantity=367,
        net_deficit=17, current_stock=350, safety_stock=0, open_po_quantity=0,
        budget_limit=100, specification="Exact gauge", quality_requirement="Food grade",
        required_by_date="2099-10-20", preferred_region="Sri Lanka", unit="kg", procurement_request_id=12)
    return request, received, quote, market_inputs


def test_real_nodes_receive_upstream_results_and_preserve_constraints(pipeline):
    request, received, _, _ = pipeline
    result = workflow.run_workflow(**request)
    assert result["status"] == WorkflowStatus.WaitingForApproval, result.get("errors")
    assert result["validation_results"]["isValid"] is True, result["validation_results"]
    assert result["recommended_quantity"] == 20
    assert result["estimated_total_cost"] == 40
    for state in received.values():
        for key in ("material_id", "required_quantity", "budget_limit", "specification",
                    "quality_requirement", "required_by_date", "procurement_request_id"):
            assert state[key] == request[key]
    assert received["production_analysis_node"]["inventory_data"]["availableQuantity"] == 350
    assert received["purchasing_node"]["production_data"]["impact"]["available"] is False
    assert "conversion" in received["purchasing_node"]["production_data"]["impact"]["reason"]
    assert received["validation_node"]["draft_po"]["quantity"] == 20
    assert received["validation_node"]["tool_results"]["get_inventory_levels"]["currentStock"] == 350
    assert "calculate_production_impact" in result["tool_results"]
    assert len(result["agent_handoffs"]) == 6
    assert workflow.WORKFLOW_SESSIONS[result["workflow_id"]]["required_quantity"] == 367


def test_revision_researches_again_and_replaces_stale_draft(pipeline):
    request, _, quote, market = pipeline
    result = workflow.run_workflow(**request)
    quote["unitPrice"] = 3
    revised = workflow.request_revision(result["workflow_id"], "Use the latest supplier quote")
    assert revised["estimated_total_cost"] == 60
    assert revised["draft_po"]["totalAmount"] == 60
    assert revised["required_quantity"] == 367
    assert market[-1]["revision_notes"] == "Use the latest supplier quote"


@pytest.mark.parametrize("budget", [None, 0])
def test_missing_or_zero_budget_fails_without_draft(pipeline, budget):
    request, _, _, _ = pipeline
    result = workflow.run_workflow(**{**request, "budget_limit": budget})
    assert result["status"] == WorkflowStatus.Failed
    assert not result.get("draft_po")


def test_moq_rounded_cost_must_fit_budget(pipeline):
    request, _, _, _ = pipeline
    result = workflow.run_workflow(**{**request, "budget_limit": 35})
    assert not result.get("draft_po")
    assert result["validation_results"]["isValid"] is False


def test_new_quality_risk_invalidates_an_older_manual_resolution(pipeline, monkeypatch):
    from ai.agents import validation
    request, _, _, _ = pipeline
    result = workflow.run_workflow(**request)
    result["validation_results"] = {
        "manualResolutionStatus": "RESOLVED",
        "historicalRisk": {"defectId": "old-defect"},
    }
    monkeypatch.setattr(validation, "_check_historical_material_quality_risk", lambda *a: {
        "defectId": "new-defect", "material": "Material A", "issue": "New tear",
        "severity": "High", "relatedRoll": "ROLL-2",
    })
    checked = validation.validation_node(result)
    assert checked["validation_results"]["manualResolutionStatus"] == "PENDING_REVIEW"
    assert checked["validation_results"]["isValid"] is False


def test_manual_request_above_threshold_still_proposes_purchase(pipeline):
    request, _, _, _ = pipeline
    result = workflow.run_workflow(**{**request, "trigger_type": "Manual", "requested_quantity": 30, "net_deficit": 0, "required_quantity": 30})
    assert result["status"] == WorkflowStatus.WaitingForApproval, result.get("errors")
    assert result["recommended_quantity"] == 30
    assert result["net_deficit"] == 0
    repeated = workflow.run_workflow(**{**request, "workflow_id": result["workflow_id"], "trigger_type": "Manual", "requested_quantity": 30, "net_deficit": 0, "required_quantity": 30})
    assert repeated["supplier_selection_attempt"] == 1
    assert result["validation_results"]["isValid"] is True


def test_new_quarantine_blocks_approval_without_supplier_retry(pipeline, monkeypatch):
    from ai.agents import validation
    request, _, _, _ = pipeline
    result = workflow.run_workflow(**request)
    monkeypatch.setattr(validation, "_check_material_quarantine_count", lambda *a, **kw: 2)
    with pytest.raises(ValueError, match="Fresh validation failed"):
        workflow.approve_and_resume(result["workflow_id"], "manager")
    stored = workflow.WORKFLOW_SESSIONS[result["workflow_id"]]
    assert stored["required_action"] == "QA_REVIEW"
    assert not stored["requires_approval"]
    assert stored["supplier_selection_attempt"] == 1
    assert stored["validation_results"]["quarantinedRollsCount"] == 2


def test_quality_clearance_returns_to_approval_and_survives_revision(pipeline, monkeypatch):
    import json
    from ai.agents import validation
    request, _, _, _ = pipeline
    risk = {"defectId": "D1", "severity": "High", "material": "Material A", "relatedRoll": "R1"}
    monkeypatch.setattr(validation, "_check_historical_material_quality_risk", lambda *a: risk)
    result = workflow.run_workflow(**request)
    assert result["required_action"] == "QA_REVIEW"
    assert result["supplier_selection_attempt"] == 1
    decision = {**result["validation_results"], "manualResolutionStatus": "RESOLVED", "resolvedBy": "inspector"}
    class DecisionConnection:
        def __enter__(self): return self
        def __exit__(self, *_): return False
        def cursor(self): return self
        def execute(self, *_): pass
        def fetchone(self): return (json.dumps(decision),)
    import psycopg
    original_connect = psycopg.connect
    # The authoritative decision query shares the regular live-check connection factory.
    class RoutedConnection:
        def __enter__(self): return self
        def __exit__(self, *_): return False
        def cursor(self): return self
        def execute(self, sql, *args):
            self.selected = DecisionConnection() if '"AgentWorkflows"' in sql else original_connect()
            self.selected.execute(sql, *args)
        def fetchone(self): return self.selected.fetchone()
    monkeypatch.setattr(psycopg, "connect", lambda *a, **kw: RoutedConnection())
    resumed = workflow.revalidate_workflow(result["workflow_id"])
    assert resumed["status"] == WorkflowStatus.WaitingForApproval
    assert resumed["validation_results"]["qualitySafetyStatus"] == "CLEAR"
    assert resumed["supplier_selection_attempt"] == 1
    revised = workflow.request_revision(result["workflow_id"], "Recheck quote")
    assert revised["validation_results"]["manualResolutionStatus"] == "RESOLVED"
    assert revised["validation_results"]["isValid"] is True


def test_supplier_retry_loop_stops_at_three_and_cannot_be_reset(pipeline, monkeypatch):
    from ai.core.validation_contract import NON_QUALITY_CHECKS
    request, _, _, _ = pipeline
    def reject_budget(state):
        checks = {key: "PASSED" for key in NON_QUALITY_CHECKS}
        checks.update(isValid=False, qualitySafetyStatus="CLEAR", budgetCheck="BUDGET_EXCEEDED", failedChecks=["budgetCheck"])
        return {"validation_results": checks}
    # Keep a proposal available on each supplier attempt to exercise the coordinator's cap.
    original_purchasing = workflow.purchasing_node
    def purchasing(state):
        return original_purchasing({**state, "excluded_supplier_ids": []})
    monkeypatch.setattr(workflow, "purchasing_node", purchasing)
    monkeypatch.setattr(workflow, "validation_node", reject_budget)
    monkeypatch.setattr(workflow, "COMPILED_APP", workflow.build_workflow_graph())
    result = workflow.run_workflow(**request)
    assert result["supplier_selection_attempt"] == 3
    assert result["required_action"] == "REVIEW_SUPPLIER_QUOTES"
    assert result["status"] == WorkflowStatus.Failed
    assert not result["requires_approval"]
    with pytest.raises(ValueError, match="Three supplier attempts"):
        workflow.request_revision(result["workflow_id"], "Try again")
