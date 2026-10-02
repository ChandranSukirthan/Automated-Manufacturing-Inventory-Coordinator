from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from ai.core.state import WorkflowStatus, ApprovalStatus
from ai.graph.workflow import (
    run_workflow,
    approve_and_resume,
    reject_workflow,
    WORKFLOW_SESSIONS,
)
from ai.tools.production_tools import (
    get_production_schedule,
    query_production_schedule,
    calculate_machine_uptime,
    check_maintenance_requirement,
    calculate_production_impact,
)
from ai.core.request_context import (
    reset_authorization_header,
    set_authorization_header,
)

router = APIRouter(prefix="/api/workflows", tags=["Agent Workflows"])
tools_router = APIRouter(prefix="/api/tools", tags=["Production Tools"])


# Request / Response Schemas
class RunWorkflowRequest(BaseModel):
    objective: str = Field(
        ...,
        json_schema_extra={"example": "Replenish BoxPouch film because inventory is low."},
        description="The business objective for the Planner agent."
    )
    workflowId: Optional[str] = Field(None, json_schema_extra={"example": "WF-1004"})
    material_id: Optional[str] = Field(None, json_schema_extra={"example": "RM-STEEL-001"})
    required_quantity: Optional[float] = Field(None, json_schema_extra={"example": 2000.0})


class RejectWorkflowRequest(BaseModel):
    reason: Optional[str] = Field(
        "Rejected by human administrator",
        json_schema_extra={"example": "Exceeds daily budget"},
    )


class MaintenanceCheckRequest(BaseModel):
    uptime: float = Field(..., json_schema_extra={"example": 480.0})
    maintenanceInterval: float = Field(..., json_schema_extra={"example": 500.0})
    machineId: str = Field("M001", json_schema_extra={"example": "M001"})


class ProductionImpactRequest(BaseModel):
    target: int = Field(..., json_schema_extra={"example": 10000})
    availableMaterial: int = Field(..., json_schema_extra={"example": 6000})


# Workflow Endpoints
@router.post("/run", status_code=status.HTTP_201_CREATED)
@router.post("/trigger", status_code=status.HTTP_201_CREATED)
def trigger_workflow(
    request: RunWorkflowRequest,
    authorization: Optional[str] = Header(default=None),
):
    """
    Triggers a multi-agent autonomous workflow via the Planner/Coordinator agent.
    """
    context_token = set_authorization_header(authorization)
    try:
        return run_workflow(
            objective=request.objective,
            workflow_id=request.workflowId,
            material_id=request.material_id,
            required_quantity=request.required_quantity,
        )
    finally:
        reset_authorization_header(context_token)


@router.get("")
def list_workflows():
    """
    Returns all in-memory or persisted active workflow sessions.
    """
    return list(WORKFLOW_SESSIONS.values())


@router.get("/{workflow_id}")
def get_workflow(workflow_id: str):
    """
    Retrieves the complete state and execution timeline for a specific workflow.
    """
    session = WORKFLOW_SESSIONS.get(workflow_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow with ID '{workflow_id}' not found."
        )
    return session


@router.post("/{workflow_id}/approve")
def approve_workflow(workflow_id: str):
    """
    Resumes a paused workflow after human review and completes execution.
    """
    resumed = approve_and_resume(workflow_id)
    if not resumed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found or cannot be resumed."
        )
    return resumed


@router.post("/{workflow_id}/reject")
def reject_workflow_endpoint(workflow_id: str, request: RejectWorkflowRequest):
    """
    Rejects a paused workflow at the human approval gate.
    """
    rejected = reject_workflow(workflow_id, reason=request.reason)
    if not rejected:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found."
        )
    return rejected


# Production Tool Direct Endpoints
@tools_router.get("/production-schedule")
def tool_get_production_schedule(shiftName: str = "Next shift"):
    """Return the allow-listed, read-only schedule for a selected shift."""
    return get_production_schedule.invoke({"shiftName": shiftName})


@tools_router.get("/machine-uptime")
def tool_calculate_uptime(machineId: str = "M001"):
    """Tool 2: calculate_machine_uptime()"""
    return calculate_machine_uptime(machine_id=machineId)


@tools_router.post("/check-maintenance")
def tool_check_maintenance(request: MaintenanceCheckRequest):
    """Tool 3: check_maintenance_requirement()"""
    return check_maintenance_requirement(
        uptime=request.uptime,
        maintenance_interval=request.maintenanceInterval,
        machine_id=request.machineId
    )


@tools_router.post("/production-impact")
def tool_calculate_impact(request: ProductionImpactRequest):
    """Tool 4: calculate_production_impact()"""
    return calculate_production_impact(
        target=request.target,
        available_material=request.availableMaterial
    )

