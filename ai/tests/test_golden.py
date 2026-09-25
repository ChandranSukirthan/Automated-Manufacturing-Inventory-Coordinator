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
except ImportError:
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
    state = run_workflow(objective=objective, workflow_id=wf_id)

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
    assert resumed["status"] == WorkflowStatus.Completed
    assert resumed["approval_status"] == ApprovalStatus.Approved
    assert resumed["current_agent"] == "Execution"
    assert resumed["final_outcome"] is not None


# =======================================================
# 5. FastAPI Endpoints Testing
# =======================================================
def test_api_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ONLINE"


def test_api_tool_production_impact():
    payload = {"target": 10000, "availableMaterial": 6000}
    response = client.post("/api/tools/production-impact", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["adjustedOutput"] == 6000


def test_api_trigger_and_approve_workflow():
    payload = {
        "objective": "Replenish BoxPouch film because inventory is low.",
        "workflowId": "WF-API-TEST"
    }
    response = client.post("/api/workflows/run", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["workflow_id"] == "WF-API-TEST"
    assert data["status"] == "WaitingForApproval"

    # Approve
    approve_resp = client.post("/api/workflows/WF-API-TEST/approve")
    assert approve_resp.status_code == 200
    approved_data = approve_resp.json()
    assert approved_data["status"] == "Completed"


# =======================================================
# 6. Cross-Agent Quality & Coordinator Validation Test
# =======================================================
def test_cross_agent_quality_and_planner_coordination():
    """
    Cross-Agent Collaboration Test:
    Verifies that Agent 4 (Validation/Safety) integrates Nithushan's Quality Agent.
    When a defect is attached to the state, the Validation Agent runs
    the Quality Agent validation and requires quarantine approval.
    """
    try:
        from ai.agents.validation import validation_node

    except ImportError:
        from agents.validation import validation_node


    state = {
        "purchasing_data": {
            "draft_po": {
                "poNumber": "PO-DRAFT-2026-004",
                "supplier": "Apex Polymer Solutions Ltd",
                "quantity": 4000,
                "estimatedCostUsd": 5800.0,
            }
        },
        "production_data": {"impact": {"adjustedOutput": 6000, "plannedOutput": 10000}},
        "quality_data": {
            "defect": {
                "batchId": "BATCH-QA-01",
                "productType": "BoxPouch",
                "severity": "High",
                "description": "Contaminated seal defect",
            }
        },
        "completed_steps": [],
        "errors": []
    }

    result = validation_node(state)

    # Must require approval due to High severity defect quarantine recommendation
    assert result["requires_approval"] is True
    assert result["status"] == WorkflowStatus.WaitingForApproval
    assert "quality_data" in result
    assert result["validation_results"]["qualitySafetyStatus"] == "QUARANTINE_REQUIRED"
    assert any("Quality Agent: Quarantine required" in step for step in result["completed_steps"])


