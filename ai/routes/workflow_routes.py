from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from ai.core.state import WorkflowStatus, ApprovalStatus
from ai.graph.workflow import (
    run_workflow,
    approve_and_resume,
    reject_workflow,
    WORKFLOW_SESSIONS,
)
from ai.tools.production_tools import (
    query_production_schedule,
    calculate_machine_uptime,
    check_maintenance_requirement,
    calculate_production_impact,
)

router = APIRouter(prefix="/api/workflows", tags=["Agent Workflows"])
tools_router = APIRouter(prefix="/api/tools", tags=["Production Tools"])


# Request / Response Schemas
class RunWorkflowRequest(BaseModel):
    objective: str = Field(
        ...,
        example="Replenish BoxPouch film because inventory is low.",
        description="The business objective for the Planner agent."
    )
    workflowId: Optional[str] = Field(None, example="WF-1004")


class RejectWorkflowRequest(BaseModel):
    reason: Optional[str] = Field("Rejected by human administrator", example="Exceeds daily budget")


class MaintenanceCheckRequest(BaseModel):
    uptime: float = Field(..., example=480.0)
    maintenanceInterval: float = Field(..., example=500.0)
    machineId: str = Field("M001", example="M001")


class ProductionImpactRequest(BaseModel):
    target: int = Field(..., example=10000)
    availableMaterial: int = Field(..., example=6000)


# Workflow Endpoints
@router.post("/run", status_code=status.HTTP_201_CREATED)
def trigger_workflow(request: RunWorkflowRequest):
    """
    Triggers a multi-agent autonomous workflow via the Planner/Coordinator agent.
    """
    result = run_workflow(objective=request.objective, workflow_id=request.workflowId)
    return result


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
def tool_query_schedule(machineId: str = "M001"):
    """Tool 1: query_production_schedule()"""
    return query_production_schedule(machine_id=machineId)


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

