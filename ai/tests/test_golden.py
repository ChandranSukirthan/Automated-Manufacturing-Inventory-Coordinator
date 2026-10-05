import pytest
from fastapi.testclient import TestClient

try:
    from ai.main import app
    from ai.tools.production_tools import (
        calculate_production_impact,
        check_maintenance_requirement,
        calculate_machine_uptime,
        query_production_schedule,
    )
    from ai.agents.planner import planner_node
    from ai.graph.workflow import run_workflow, approve_and_resume
    from ai.core.state import WorkflowStatus, ApprovalStatus
except ModuleNotFoundError:
    from main import app
    from tools.production_tools import (
        calculate_production_impact,
        check_maintenance_requirement,
        calculate_machine_uptime,
        query_production_schedule,
    )
    from agents.planner import planner_node
    from graph.workflow import run_workflow, approve_and_resume
    from core.state import WorkflowStatus, ApprovalStatus


client = TestClient(app)


# =======================================================
# 1. Golden Case: Production Target vs Available Material
# =======================================================
def test_golden_production_impact():
    """
    Prompt Test:
    Production target = 10000
    Available material = 6000
    Expected:
    Adjusted output = 6000
    """
    result = calculate_production_impact(target=10000, available_material=6000)

    assert result["plannedOutput"] == 10000
    assert result["availableMaterial"] == 6000
    assert result["adjustedOutput"] == 6000


# =======================================================
# 2. Maintenance Urgency Tests
# =======================================================
def test_maintenance_not_due():
    """
    Prompt Test:
    Uptime = 480, Interval = 500
    Expected: Maintenance due = false
    """
    result = check_maintenance_requirement(uptime=480.0, maintenance_interval=500.0, machine_id="M001")

    assert result["machineId"] == "M001"
    assert result["maintenanceDue"] is False
    assert result["remainingHours"] == 20.0


def test_maintenance_due():
    """
    Prompt Test:
    Uptime = 520, Interval = 500
    Expected: Maintenance due = true
    """
    result = check_maintenance_requirement(uptime=520.0, maintenance_interval=500.0, machine_id="M001")

    assert result["machineId"] == "M001"
    assert result["maintenanceDue"] is True
    assert result["remainingHours"] == -20.0


# =======================================================
# 3. Planner Agent Test: Structured Multi-Step Plan
# =======================================================
def test_planner_structured_multistep_plan():
    """
    Prompt Test:
    Planner Agent converts business objective into a structured multi-step plan.
    """
    objective = "Replenish BoxPouch film because inventory is low."
    initial_state = {
        "objective": objective,
        "completed_steps": [],
        "errors": []
    }

    result = planner_node(initial_state)

    assert "plan" in result
    assert isinstance(result["plan"], list)
    assert len(result["plan"]) >= 5
    assert result["current_agent"] == "Planner"
    assert result["status"] == WorkflowStatus.Running

    # Verify key manufacturing steps exist in plan
    plan_text = " ".join(result["plan"]).lower()
    assert "inventory" in plan_text
    assert "approval" in plan_text


# =======================================================
# 4. End-to-End Multi-Agent Workflow Execution
# =======================================================
def test_end_to_end_workflow_with_human_approval():
    """
    Tests complete workflow:
    Planner -> Data Extraction -> Production Analysis -> Purchasing -> Validation -> Human Approval -> Execution
    """
    wf_id = "WF-TEST-001"
    objective = "Replenish BoxPouch film because inventory is low."

    # Step 1: Run workflow up to human approval gate
    state = run_workflow(
        objective=objective,
        workflow_id=wf_id,
        material_id="CR-001",
        required_quantity=2000.0,
    )

    assert state["workflow_id"] == wf_id
    assert state["status"] == WorkflowStatus.WaitingForApproval
    assert state["approval_status"] == ApprovalStatus.Pending
    assert state["requires_approval"] is True
    assert "draft_po" in state.get("purchasing_data", {})
    assert state["purchasing_data"]["draft_po"]["paymentStatus"] == "UNPAID" # Planner must NOT pay
    assert state["purchasing_data"]["draft_po"]["emailSent"] is False       # Planner must NOT send email

    # Step 2: Human approval action
    resumed = approve_and_resume(wf_id)

    assert resumed is not None
    assert resumed["status"] == WorkflowStatus.WaitingForApproval
    assert resumed["approval_status"] == ApprovalStatus.Approved
    assert resumed["current_agent"] == "Payment / Dispatch"
    assert resumed["final_outcome"] is not None


# =======================================================
# 5. FastAPI Endpoints Testing
# =======================================================
def test_api_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ONLINE"


def test_api_tool_production_impact(auth_headers):
    payload = {"target": 10000, "availableMaterial": 6000}
    response = client.post("/api/tools/production-impact", json=payload, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["adjustedOutput"] == 6000


def test_api_trigger_and_approve_workflow(auth_headers):
    payload = {
        "objective": "Replenish BoxPouch film because inventory is low.",
        "workflowId": "WF-API-TEST",
        "material_id": "CR-001",
        "required_quantity": 2000.0,
    }
    response = client.post("/api/workflows/run", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["workflow_id"] == "WF-API-TEST"
    assert data["status"] == "WaitingForApproval"

    # Approve
    approve_resp = client.post("/api/workflows/WF-API-TEST/approve", headers=auth_headers)
    assert approve_resp.status_code == 200
    approved_data = approve_resp.json()
    assert approved_data["status"] == "WaitingForApproval"


# =======================================================
# 6. Cross-Agent Quality & Coordinator Validation Test
# =======================================================
def test_cross_agent_quality_and_planner_coordination(monkeypatch):
    from ai.agents.validation import validation_node
    from ai.agents.supervisor import supervisor_node
    import ai.agents.validation as validation
    monkeypatch.setattr(validation, "run_quality_validation", lambda state: {**state,
        "quality_data": {**state["quality_data"], "validation": {"valid": False, "quarantineRequired": True, "affectedInventory": ["R1"]}}})
    state = {"purchasing_data": {"draft_po": {"quantity": 4000, "unitPrice": 1.45, "estimatedCost": 5800}},
        "material_id": "RM001", "quality_data": {"defect": {"severity": "High", "description": "Contamination"}},
        "completed_steps": [], "errors": []}
    evidence = validation_node(state)
    assert "status" not in evidence and "requires_approval" not in evidence
    result = supervisor_node({**state, **evidence})
    assert result["requires_approval"] is False
    assert result["status"] == WorkflowStatus.Failed
    assert not result["automatic_retry_required"]
    assert result["required_action"] == "QA_REVIEW"
    assert evidence["validation_results"]["quarantinedRollsCount"] == 0
    assert evidence["validation_results"]["recommendedQuarantineRollsCount"] == 1


def test_validation_stops_after_third_rejected_supplier():
    from ai.agents.supervisor import supervisor_node
    from ai.core.validation_contract import NON_QUALITY_CHECKS
    result = supervisor_node({"supplier_selection_attempt": 3,
        "validation_results": {**{key: "PASSED" for key in NON_QUALITY_CHECKS}, "qualitySafetyStatus": "CLEAR", "isValid": False, "failedChecks": ["budgetCheck"], "budgetCheck": "BUDGET_EXCEEDED"}})
    assert result["requires_approval"] is False
    assert result["status"] == WorkflowStatus.Failed
    assert result["automatic_retry_required"] is False
    assert result["required_action"] == "REVIEW_SUPPLIER_QUOTES"
    assert "Payment approval is blocked" in result["final_outcome"]
