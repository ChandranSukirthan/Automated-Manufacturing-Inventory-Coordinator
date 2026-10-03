from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Header, HTTPException, status, Depends, BackgroundTasks
import uuid
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

from ai.security import require_actor, require_role
router = APIRouter(prefix="/api/workflows", tags=["Agent Workflows"], dependencies=[Depends(require_actor)])
tools_router = APIRouter(prefix="/api/tools", tags=["Production Tools"])


# ── Request / Response Schemas ─────────────────────────────────────────────────

class RunWorkflowRequest(BaseModel):
    """
    Procurement workflow trigger from ASP.NET Core and direct API callers.
    Supports both camelCase and snake_case formats.
    All quantity/budget fields are authoritative — the AI never invents them.
    """
    objective: str = Field(..., description="Business objective for the Planner agent.")
    workflowId: Optional[str] = Field(None)
    procurementRequestId: Optional[int] = Field(None)

    # Authoritative procurement fields
    materialId: Optional[str] = None
    material_id: Optional[str] = None
    materialName: Optional[str] = None
    currentStock: Optional[float] = None
    requiredQuantity: Optional[float] = None
    required_quantity: Optional[float] = None
    safetyStock: Optional[float] = None
    openPOQuantity: Optional[float] = None
    netDeficit: Optional[float] = None          # authoritative — never invented by AI
    budgetLimit: Optional[float] = None
    unit: Optional[str] = None
    qualityRequirement: Optional[str] = None
    preferredRegion: Optional[str] = None
    requiredByDate: Optional[str] = None
    specification: Optional[str] = None
    purchasing_data: Optional[Dict[str, Any]] = None
    quality_data: Optional[Dict[str, Any]] = None
    workflowType: str = "Procurement"
    machineId: Optional[str] = None
    background: bool = False

    # Legacy aliases (kept for backward compatibility)
    maximumBudget: Optional[float] = None
    requiredByDateLegacy: Optional[str] = Field(None, alias="requiredByDateLegacy")


class RejectWorkflowRequest(BaseModel):
    reason: Optional[str] = Field("Rejected by human administrator")
    rejectedBy: Optional[str] = None


class RevisionRequest(BaseModel):
    revisionNotes: str = Field(..., description="Structured revision requirement from Supply Chain Manager.")
    requestedBy: Optional[str] = None


class ApproveRequest(BaseModel):
    approvedBy: Optional[str] = None


class MaintenanceCheckRequest(BaseModel):
    uptime: float = Field(...)
    maintenanceInterval: float = Field(...)
    machineId: str = Field("M001")


class ProductionImpactRequest(BaseModel):
    target: int = Field(...)
    availableMaterial: int = Field(...)



# ── Workflow Endpoints ─────────────────────────────────────────────────────────

@router.post("/run", status_code=status.HTTP_201_CREATED)
@router.post("/trigger", status_code=status.HTTP_201_CREATED)
def trigger_workflow(
    request: RunWorkflowRequest,
    authorization: Optional[str] = Header(default=None),
    background_tasks: BackgroundTasks = None,
):
    """
    Triggers the multi-agent procurement workflow.
    Called by ASP.NET Core ProcurementService.RunAiResearchAsync().
    All authoritative procurement values are passed directly — AI never invents them.
    """
    if request.background and background_tasks is not None:
        request.workflowId = request.workflowId or f"WF-{uuid.uuid4().hex[:20].upper()}"
        existing = WORKFLOW_SESSIONS.get(request.workflowId)
        if existing:
            if existing.get("objective") != request.objective or existing.get("material_id") != (request.materialId or request.material_id):
                raise HTTPException(409, "Workflow ID is already assigned to another request")
            return get_final_output(existing)
        queued = {"workflow_id": request.workflowId, "objective": request.objective,
                  "workflow_type": request.workflowType, "machine_id": request.machineId,
                  "material_id": request.materialId or request.material_id,
                  "status": WorkflowStatus.Running, "approval_status": ApprovalStatus.Pending,
                  "current_agent": "Queued", "queued_request": request.model_dump(), "errors": []}
        WORKFLOW_SESSIONS[request.workflowId] = queued
        from ai.graph.workflow import sync_to_database
        sync_to_database(queued)
        request.background = False
        background_tasks.add_task(trigger_workflow, request, authorization)
        return get_final_output(queued)

    # Resolve budget (accept both field names)
    budget = request.budgetLimit or request.maximumBudget
    resolved_material_id = request.materialId or request.material_id
    resolved_quantity = request.requiredQuantity if request.requiredQuantity is not None else request.required_quantity

    # Build legacy procurement_requirement dict for backward compatibility
    req_dict: Dict[str, Any] = {}
    if budget is not None:
        req_dict["budgetLimit"] = budget
        req_dict["maximumBudget"] = budget
    if resolved_material_id:
        req_dict["materialId"] = resolved_material_id
    if request.materialName:
        req_dict["materialName"] = request.materialName
    if request.netDeficit is not None:
        req_dict["netDeficit"] = request.netDeficit
    if resolved_quantity is not None:
        req_dict["requiredQuantity"] = resolved_quantity
        req_dict["productionRequirement"] = resolved_quantity
    if request.safetyStock is not None:
        req_dict["safetyStock"] = request.safetyStock
    if request.currentStock is not None:
        req_dict["currentStock"] = request.currentStock
    if request.specification:
        req_dict["requiredSpecification"] = request.specification
    if request.qualityRequirement:
        req_dict["qualityRequirement"] = request.qualityRequirement
    if request.preferredRegion:
        req_dict["preferredRegion"] = request.preferredRegion
    if request.requiredByDate:
        req_dict["requiredByDate"] = request.requiredByDate
    if request.unit:
        req_dict["unit"] = request.unit

    token = set_authorization_header(authorization)
    try:
        state = run_workflow(
        objective=request.objective,
        workflow_id=request.workflowId,
        procurement_requirement=req_dict if req_dict else None,
        # Direct authoritative parameters
        material_id=resolved_material_id,
        material_name=request.materialName,
        current_stock=request.currentStock,
        required_quantity=resolved_quantity,
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
        purchasing_data=request.purchasing_data,
        quality_data=request.quality_data,
        workflow_type=request.workflowType,
        machine_id=request.machineId,
        )
        return get_final_output(state)
    except ValueError as error:
        raise HTTPException(409, str(error))
    finally:
        reset_authorization_header(token)


@router.post("/{workflow_id}/retry")
def retry_workflow(workflow_id: str, background_tasks: BackgroundTasks,
                   authorization: Optional[str] = Header(default=None)):
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        raise HTTPException(404, "Workflow was not found")
    if state.get("status") != WorkflowStatus.Failed and state.get("current_agent") != "Supplier Review":
        raise HTTPException(409, "Only failed analyses or supplier review without an order can be retried")
    request = state.get("queued_request") or {
        "objective": state["objective"], "workflowId": workflow_id,
        "materialId": state.get("material_id"), "materialName": state.get("material_name"),
        "requiredQuantity": state.get("required_quantity"), "currentStock": state.get("current_stock"),
        "safetyStock": state.get("safety_stock"), "openPOQuantity": state.get("open_po_quantity"),
        "netDeficit": state.get("net_deficit"), "budgetLimit": state.get("budget_limit"),
        "unit": state.get("unit"), "workflowType": state.get("workflow_type", "Procurement"),
        "machineId": state.get("machine_id")}
    state.update(status=WorkflowStatus.Running, current_agent="Queued", errors=[])
    WORKFLOW_SESSIONS[workflow_id] = state
    background_tasks.add_task(trigger_workflow, RunWorkflowRequest(**{**request, "background": False}), authorization)
    return get_final_output(state)


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
def approve_workflow(workflow_id: str, request: ApproveRequest = ApproveRequest(), actor: dict = Depends(require_actor)):
    """
    Supply Chain Manager APPROVE action.
    Resumes execution and persists procurement outcome for future learning.
    """
    require_role(actor, "SupplyChainManager")
    try:
        resumed = approve_and_resume(workflow_id, approved_by=request.approvedBy)
    except ValueError as error:
        raise HTTPException(409, str(error))
    if not resumed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow '{workflow_id}' not found or cannot be resumed.",
        )
    return get_final_output(resumed)


@router.post("/{workflow_id}/reject")
def reject_workflow_endpoint(workflow_id: str, request: RejectWorkflowRequest, actor: dict = Depends(require_actor)):
    """
    Supply Chain Manager REJECT action.
    Persists rejection reason for future learning dataset.
    """
    require_role(actor, "SupplyChainManager")
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
def request_revision_endpoint(workflow_id: str, request: RevisionRequest, actor: dict = Depends(require_actor)):
    """
    Supply Chain Manager REQUEST_REVISION action.
    Sends structured revision requirement back into the purchasing → validation loop.
    """
    require_role(actor, "SupplyChainManager")
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
def tool_query_schedule(machineId: str = "M001", shiftName: Optional[str] = None):
    if shiftName is not None:
        return get_production_schedule.invoke({"shiftName": shiftName})
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
