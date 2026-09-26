from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from ai.core.state import WorkflowStatus, ApprovalStatus
from ai.graph.workflow import (
    run_workflow,
    approve_and_resume,
    reject_workflow,
    request_revision,
    get_final_output,
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


# ── Request / Response Schemas ─────────────────────────────────────────────────

class RunWorkflowRequest(BaseModel):
    """
    Procurement workflow trigger from ASP.NET Core.
    All quantity/budget fields are authoritative — the AI never invents them.
    """
    objective: str = Field(..., description="Business objective for the Planner agent.")
    workflowId: Optional[str] = Field(None)
    procurementRequestId: Optional[int] = Field(None)

    # Authoritative procurement fields from ASP.NET Core
    materialId: Optional[str] = None
    materialName: Optional[str] = None
    currentStock: Optional[float] = None
    requiredQuantity: Optional[float] = None
    safetyStock: Optional[float] = None
    openPOQuantity: Optional[float] = None
    netDeficit: Optional[float] = None          # authoritative — never invented by AI
    budgetLimit: Optional[float] = None
    unit: Optional[str] = None
    qualityRequirement: Optional[str] = None
    preferredRegion: Optional[str] = None
    requiredByDate: Optional[str] = None
    specification: Optional[str] = None

    # Legacy aliases (kept for backward compatibility)
    maximumBudget: Optional[float] = None
    requiredByDateLegacy: Optional[str] = Field(None, alias="requiredByDateLegacy")


class RejectWorkflowRequest(BaseModel):
    reason: Optional[str] = Field("Rejected by Supply Chain Manager")
    rejectedBy: Optional[str] = None


class RevisionRequest(BaseModel):
    revisionNotes: str = Field(..., description="Structured revision requirement from Supply Chain Manager.")
    requestedBy: Optional[str] = None


class ApproveRequest(BaseModel):
    approvedBy: Optional[str] = None


class MaintenanceCheckRequest(BaseModel):
    uptime: float
    maintenanceInterval: float
    machineId: str = "M001"


class ProductionImpactRequest(BaseModel):
    target: int
    availableMaterial: int


# ── Workflow Endpoints ─────────────────────────────────────────────────────────

@router.post("/run", status_code=status.HTTP_201_CREATED)
def trigger_workflow(request: RunWorkflowRequest):
    """
    Triggers the multi-agent procurement workflow.
    Called by ASP.NET Core ProcurementService.RunAiResearchAsync().
    All authoritative procurement values are passed directly — AI never invents them.
    """
    # Resolve budget (accept both field names)
    budget = request.budgetLimit or request.maximumBudget

    # Build legacy procurement_requirement dict for backward compatibility
    req_dict: Dict[str, Any] = {}
    if request.materialName:
        req_dict["materialName"] = request.materialName
    if request.specification:
        req_dict["requiredSpecification"] = request.specification
    if request.netDeficit is not None:
        req_dict["netDeficit"] = request.netDeficit
        req_dict["requiredQuantity"] = request.netDeficit
    elif request.requiredQuantity is not None:
        req_dict["requiredQuantity"] = request.requiredQuantity
    if budget is not None:
        req_dict["maximumBudget"] = budget
    if request.preferredRegion:
        req_dict["preferredRegion"] = request.preferredRegion
    if request.requiredByDate:
        req_dict["requiredByDate"] = request.requiredByDate
    if request.qualityRequirement:
        req_dict["qualityRequirement"] = request.qualityRequirement

    result = run_workflow(
        objective=request.objective,
        workflow_id=request.workflowId,
        procurement_requirement=req_dict if req_dict else None,
        material_id=request.materialId,
        material_name=request.materialName,
        current_stock=request.currentStock,
        required_quantity=request.requiredQuantity,
        safety_stock=request.safetyStock,
        open_po_quantity=request.openPOQuantity,
        net_deficit=request.netDeficit,
        budget_limit=budget,
        unit=request.unit,
        quality_requirement=request.qualityRequirement,
        preferred_region=request.preferredRegion,
        required_by_date=request.requiredByDate,
        specification=request.specification,
        procurement_request_id=request.procurementRequestId,
    )

    return get_final_output(result)


@router.get("")
def list_workflows():
    """Returns all active workflow sessions with structured final output."""
    return [get_final_output(s) for s in WORKFLOW_SESSIONS.values()]


@router.get("/{workflow_id}")
def get_workflow(workflow_id: str):
    """Retrieves the structured final output for a specific workflow."""
    session = WORKFLOW_SESSIONS.get(workflow_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found.",
        )
    return get_final_output(session)


@router.post("/{workflow_id}/approve")
def approve_workflow(workflow_id: str, request: ApproveRequest = ApproveRequest()):
    """
    Supply Chain Manager APPROVE action.
    Resumes execution and persists procurement outcome for future learning.
    """
    resumed = approve_and_resume(workflow_id, approved_by=request.approvedBy)
    if not resumed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found or cannot be resumed.",
        )
    return get_final_output(resumed)


@router.post("/{workflow_id}/reject")
def reject_workflow_endpoint(workflow_id: str, request: RejectWorkflowRequest):
    """
    Supply Chain Manager REJECT action.
    Persists rejection reason for future learning dataset.
    """
    rejected = reject_workflow(
        workflow_id,
        reason=request.reason or "Rejected by Supply Chain Manager",
        rejected_by=request.rejectedBy,
    )
    if not rejected:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found.",
        )
    return get_final_output(rejected)


@router.post("/{workflow_id}/revision")
def request_revision_endpoint(workflow_id: str, request: RevisionRequest):
    """
    Supply Chain Manager REQUEST_REVISION action.
    Sends structured revision requirement back into the purchasing → validation loop.
    """
    revised = request_revision(
        workflow_id,
        revision_notes=request.revisionNotes,
        requested_by=request.requestedBy,
    )
    if not revised:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found.",
        )
    return get_final_output(revised)


# ── Production Tool Direct Endpoints ──────────────────────────────────────────

@tools_router.get("/production-schedule")
def tool_query_schedule(machineId: str = "M001"):
    return query_production_schedule(machine_id=machineId)


@tools_router.get("/machine-uptime")
def tool_calculate_uptime(machineId: str = "M001"):
    return calculate_machine_uptime(machine_id=machineId)


@tools_router.post("/check-maintenance")
def tool_check_maintenance(request: MaintenanceCheckRequest):
    return check_maintenance_requirement(
        uptime=request.uptime,
        maintenance_interval=request.maintenanceInterval,
        machine_id=request.machineId,
    )


@tools_router.post("/production-impact")
def tool_calculate_impact(request: ProductionImpactRequest):
    return calculate_production_impact(
        target=request.target,
        available_material=request.availableMaterial,
    )
