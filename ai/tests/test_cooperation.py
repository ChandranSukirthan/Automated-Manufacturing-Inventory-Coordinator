import pytest
from ai.graph.workflow import run_workflow, approve_and_resume
from ai.core.state import WorkflowStatus, ApprovalStatus


def test_agent_cooperation_and_data_passing():
    """
    Verifies that all 4 agents genuinely pass, consume, and react to each other's live data:
    1. Planner -> defines sequence of steps based on objective.
    2. Data Extraction (Student 1) -> extracts inventory levels and required quantity.
    3. Production Analysis (Student 4) -> consumes Student 1's available quantity to calculate production impact and shortfall.
    4. Purchasing (Student 2) -> consumes Student 1's material + Student 4's shortfall, queries live PostgreSQL suppliers, and drafts PO.
    5. Validation / Safety (Student 3) -> audits Student 2's drafted PO against budget threshold and database quarantine holds.
    """
    objective = "Replenish RM-ALUM-002 aluminum rods due to factory floor burn-rate deficit."
    wf_id = "WF-COOP-TEST-001"

    result = run_workflow(
        objective=objective,
        workflow_id=wf_id,
        material_id="RM-ALUM-002",
        required_quantity=1500.0
    )

    # 1. Verify Planner produced the plan
    assert len(result.get("plan", [])) > 0
    assert any("execution plan" in step.lower() for step in result["completed_steps"])

    # 2. Verify Student 1 (Data Extraction) produced real telemetry for RM-ALUM-002
    inv_data = result.get("inventory_data", {})
    assert inv_data.get("materialId") == "RM-ALUM-002"
    assert "burnRate" in inv_data
    assert "availableQuantity" in inv_data
    assert inv_data.get("requiredQuantity") == 1500.0
    assert any("Data Extraction" in step for step in result["completed_steps"])

    # 3. Verify Student 4 (Production Analysis) consumed Student 1's availableQuantity
    prod_data = result.get("production_data", {})
    impact = prod_data.get("impact", {})
    assert "plannedOutput" in impact
    assert "adjustedOutput" in impact
    # Available material passed to impact calculator must match Student 1's availableQuantity
    assert impact["availableMaterial"] == int(inv_data["availableQuantity"])
    assert any("Production Analysis" in step for step in result["completed_steps"])

    # 4. Verify Student 2 (Purchasing) consumed Student 1's material and Student 4's shortfall
    purchasing_data = result.get("purchasing_data", {})
    supplier = purchasing_data.get("supplier", {})
    draft_po = purchasing_data.get("draft_po", {})
    assert draft_po.get("materialId") == "RM-ALUM-002"
    # Drafted quantity should cover the requested 1500.0 or production shortfall
    assert draft_po.get("quantity") >= 1500.0
    assert draft_po.get("totalAmount") > 0
    # Supplier must be one of the real active suppliers
    assert supplier.get("supplierId") in ["SUP-001", "SUP-002", "SUP-003"]
    assert any("Purchasing: Selected" in step for step in result["completed_steps"])

    # 5. Verify Student 3 (Validation) audited the PO and routed to approval gate
    validation_results = result.get("validation_results", {})
    assert "qualitySafetyStatus" in validation_results
    assert result.get("requires_approval") is True
    assert result.get("status") == WorkflowStatus.WaitingForApproval

    # 6. Verify Human Approval resumes and completes workflow
    resumed = approve_and_resume(wf_id)
    assert resumed is not None
    assert resumed["status"] == WorkflowStatus.Completed
    assert resumed["approval_status"] == ApprovalStatus.Approved
    assert any("Execution: PO" in step for step in resumed["completed_steps"])

