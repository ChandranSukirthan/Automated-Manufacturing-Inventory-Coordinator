"""
LangGraph Workflow — Goal-Based Purchasing Agent
Architecture prepared for future learning-based procurement intelligence.

Flow:
START → planner → data_extraction → production_analysis → purchasing
      → validation → [human approval gate] → execution → END

Human approval outcomes:
  APPROVE          → execution → END
  REJECT           → END (persisted)
  REQUEST_REVISION → purchasing → validation → [human approval gate] (loop)
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import psycopg
from langgraph.graph import StateGraph, START, END

from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings
from ai.agents.planner import planner_node
from ai.agents.data_extraction import data_extraction_node, production_analysis_node
from ai.agents.purchasing import purchasing_node
from ai.agents.validation import validation_node, execution_node


# ── Database sync ──────────────────────────────────────────────────────────────

def sync_to_database(state: AgentState) -> None:
    """
    Syncs workflow state to PostgreSQL AgentWorkflows table.
    ASP.NET Core and React dashboards read live updates from this table.
    Does NOT store chain-of-thought — only structured execution fields.
    """
    workflow_id = state.get("workflow_id")
    if not workflow_id:
        return

    status_val = (
        state.get("status").value
        if isinstance(state.get("status"), WorkflowStatus)
        else str(state.get("status") or "Running")
    )
    approval_val = (
        state.get("approval_status").value
        if isinstance(state.get("approval_status"), ApprovalStatus)
        else str(state.get("approval_status") or "Pending")
    )
    completed_at = (
        datetime.now(timezone.utc)
        if status_val in (WorkflowStatus.Completed.value, WorkflowStatus.Failed.value)
        else None
    )

    try:
        with psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=3,
        ) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO "AgentWorkflows"
                        ("Id", "WorkflowId", "Objective", "CurrentAgent", "Status",
                         "ApprovalStatus", "StartedAt", "CompletedAt", "FinalOutcome")
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT ("WorkflowId") DO UPDATE
                    SET "Objective"       = EXCLUDED."Objective",
                        "CurrentAgent"    = EXCLUDED."CurrentAgent",
                        "Status"          = EXCLUDED."Status",
                        "ApprovalStatus"  = EXCLUDED."ApprovalStatus",
                        "CompletedAt"     = COALESCE(EXCLUDED."CompletedAt", "AgentWorkflows"."CompletedAt"),
                        "FinalOutcome"    = EXCLUDED."FinalOutcome";
                    """,
                    (
                        str(uuid.uuid4()),
                        workflow_id,
                        state.get("objective", ""),
                        state.get("current_agent", "Planner"),
                        status_val,
                        approval_val,
                        datetime.now(timezone.utc),
                        completed_at,
                        state.get("final_outcome"),
                    ),
                )
            conn.commit()
    except Exception as ex:
        print(f"[Workflow Sync Warning] Could not sync {workflow_id} to DB: {ex}")


def save_procurement_outcome(state: AgentState) -> None:
    """
    Persists a structured procurement outcome record for the future learning dataset.
    Called after manager approval/rejection so the full cycle is captured.
    Never stores chain-of-thought — only structured outcome fields.
    """
    try:
        with psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=3,
        ) as conn:
            with conn.cursor() as cur:
                rec_supplier = state.get("recommended_supplier") or {}
                cur.execute(
                    """
                    INSERT INTO "ProcurementOutcomes"
                        ("Material", "RequestedQuantity", "RecommendedQuantity",
                         "FinalOrderedQuantity", "RecommendedSupplier", "SelectedSupplier",
                         "EstimatedPrice", "FinalPrice", "EstimatedLeadTime", "ActualLeadTime",
                         "QualityEvidence", "SupplierVerification",
                         "ManagerDecision", "ManagerRevision",
                         "ProcurementSuccess", "PaymentSuccess", "DeliverySuccess",
                         "CreatedAt")
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT DO NOTHING;
                    """,
                    (
                        state.get("material_name") or "Unknown",
                        state.get("net_deficit") or 0,
                        state.get("recommended_quantity") or 0,
                        state.get("recommended_quantity") or 0,
                        rec_supplier.get("supplierName") or "Unknown",
                        rec_supplier.get("supplierName") or "Unknown",
                        state.get("estimated_unit_price") or 0,
                        state.get("estimated_unit_price") or 0,
                        int(str(rec_supplier.get("leadTime") or "0").split()[0]) if rec_supplier.get("leadTime") else 0,
                        0,  # actualLeadTime — updated after delivery
                        rec_supplier.get("qualityEvidence") or "UNKNOWN",
                        state.get("supplier_verification") or "UNVERIFIED",
                        state.get("manager_decision") or "Pending",
                        state.get("revision_request"),
                        state.get("manager_decision") == "APPROVE",
                        False,   # paymentSuccess — updated by ASP.NET after Stripe
                        False,   # deliverySuccess — updated after delivery
                        datetime.now(timezone.utc),
                    ),
                )
            conn.commit()
    except Exception as ex:
        print(f"[Procurement Outcome Warning] Could not persist outcome: {ex}")


# ── Conditional routers ────────────────────────────────────────────────────────

def _after_data_extraction(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "production_analysis"


def _after_purchasing(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "validation"


def _after_validation(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    if state.get("requires_approval") or state.get("status") == WorkflowStatus.WaitingForApproval:
        return END  # pause for human approval
    return "execution"


# ── Graph assembly ─────────────────────────────────────────────────────────────

def build_workflow_graph():
    """
    Assembles the LangGraph StateGraph.
    Four agents only — no fifth agent added.
    """
    workflow = StateGraph(AgentState)

    workflow.add_node("planner", planner_node)
    workflow.add_node("data_extraction", data_extraction_node)
    workflow.add_node("production_analysis", production_analysis_node)
    workflow.add_node("purchasing", purchasing_node)
    workflow.add_node("validation", validation_node)
    workflow.add_node("execution", execution_node)

    workflow.add_edge(START, "planner")
    workflow.add_edge("planner", "data_extraction")
    workflow.add_conditional_edges(
        "data_extraction",
        _after_data_extraction,
        {"production_analysis": "production_analysis", END: END},
    )
    workflow.add_edge("production_analysis", "purchasing")
    workflow.add_conditional_edges(
        "purchasing",
        _after_purchasing,
        {"validation": "validation", END: END},
    )
    workflow.add_conditional_edges(
        "validation",
        _after_validation,
        {"execution": "execution", END: END},
    )
    workflow.add_edge("execution", END)

    return workflow.compile()


WORKFLOW_SESSIONS: Dict[str, AgentState] = {}
COMPILED_APP = build_workflow_graph()


# ── Public API ─────────────────────────────────────────────────────────────────

def run_workflow(
    objective: str,
    workflow_id: Optional[str] = None,
    procurement_requirement: Optional[Dict[str, Any]] = None,
    # Authoritative procurement fields from ASP.NET Core
    material_id: Optional[str] = None,
    material_name: Optional[str] = None,
    current_stock: Optional[float] = None,
    required_quantity: Optional[float] = None,
    safety_stock: Optional[float] = None,
    open_po_quantity: Optional[float] = None,
    net_deficit: Optional[float] = None,
    budget_limit: Optional[float] = None,
    unit: Optional[str] = None,
    quality_requirement: Optional[str] = None,
    preferred_region: Optional[str] = None,
    required_by_date: Optional[str] = None,
    specification: Optional[str] = None,
    procurement_request_id: Optional[int] = None,
) -> AgentState:
    """
    Starts and executes the workflow up to completion or the human approval gate.
    Authoritative procurement values from ASP.NET Core are passed directly as
    top-level state fields — the AI never invents them.
    """
    wf_id = workflow_id or f"WF-{uuid.uuid4().hex[:6].upper()}"
    now_iso = datetime.now(timezone.utc).isoformat()

    initial_state: AgentState = {
        "workflow_id": wf_id,
        "procurement_request_id": procurement_request_id,
        "objective": objective,
        "current_agent": "Planner",
        "status": WorkflowStatus.Running,
        "approval_status": ApprovalStatus.Pending,
        "plan": [],
        "completed_steps": [],
        "tool_results": {},
        "tool_call_log": [],
        "procurement_requirement": procurement_requirement or {},
        # Authoritative ASP.NET Core fields
        "material_id": material_id,
        "material_name": material_name,
        "current_stock": current_stock,
        "required_quantity": required_quantity,
        "safety_stock": safety_stock,
        "open_po_quantity": open_po_quantity,
        "net_deficit": net_deficit,
        "budget_limit": budget_limit,
        "unit": unit,
        "quality_requirement": quality_requirement,
        "preferred_region": preferred_region,
        "required_by_date": required_by_date,
        "specification": specification,
        # Outputs (initialised empty)
        "inventory_data": {},
        "production_data": {},
        "supplier_rates": [],
        "historical_procurement": [],
        "supplier_candidates": [],
        "recommended_supplier": None,
        "alternative_suppliers": [],
        "recommended_quantity": None,
        "estimated_unit_price": None,
        "estimated_total_cost": None,
        "quality_evidence": [],
        "supplier_verification": None,
        "recommendation_summary": None,
        "risks": [],
        "sources": [],
        "draft_po": None,
        "validation_results": {},
        "requires_approval": False,
        "manager_decision": None,
        "revision_request": None,
        "purchasing_data": {},
        "quality_data": {},
        "errors": [],
        "final_outcome": None,
        "created_at": now_iso,
        "updated_at": now_iso,
    }

    sync_to_database(initial_state)
    result_state = COMPILED_APP.invoke(initial_state)
    WORKFLOW_SESSIONS[wf_id] = result_state
    sync_to_database(result_state)

    return result_state


def approve_and_resume(workflow_id: str, approved_by: Optional[str] = None) -> Optional[AgentState]:
    """
    Handles Supply Chain Manager APPROVE action.
    Resumes execution and persists procurement outcome for future learning.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None

    state["approval_status"] = ApprovalStatus.Approved
    state["requires_approval"] = False
    state["status"] = WorkflowStatus.Running
    state["manager_decision"] = "APPROVE"
    if approved_by:
        state["approved_by"] = approved_by

    final_diff = execution_node(state)
    state.update(final_diff)

    WORKFLOW_SESSIONS[workflow_id] = state
    sync_to_database(state)
    save_procurement_outcome(state)

    return state


def reject_workflow(
    workflow_id: str,
    reason: str = "Rejected by Supply Chain Manager",
    rejected_by: Optional[str] = None,
) -> Optional[AgentState]:
    """
    Handles Supply Chain Manager REJECT action.
    Persists rejection reason and outcome for future learning.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None

    state["approval_status"] = ApprovalStatus.Rejected
    state["status"] = WorkflowStatus.Failed
    state["manager_decision"] = "REJECT"
    state["final_outcome"] = f"Procurement rejected by Supply Chain Manager: {reason}"
    state["completed_steps"] = list(state.get("completed_steps") or []) + [
        f"Rejected by Supply Chain Manager: {reason}"
    ]
    if rejected_by:
        state["approved_by"] = rejected_by

    WORKFLOW_SESSIONS[workflow_id] = state
    sync_to_database(state)
    save_procurement_outcome(state)

    return state


def request_revision(
    workflow_id: str,
    revision_notes: str,
    requested_by: Optional[str] = None,
) -> Optional[AgentState]:
    """
    Handles Supply Chain Manager REQUEST_REVISION action.
    Re-enters the purchasing → validation loop with the revision context.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None

    state["approval_status"] = ApprovalStatus.RevisionRequested
    state["manager_decision"] = "REQUEST_REVISION"
    state["revision_request"] = revision_notes
    state["requires_approval"] = False
    state["status"] = WorkflowStatus.Running
    state["completed_steps"] = list(state.get("completed_steps") or []) + [
        f"Revision requested: {revision_notes}"
    ]
    if requested_by:
        state["approved_by"] = requested_by

    # Re-run from purchasing node with revision context
    result_state = COMPILED_APP.invoke(state)
    WORKFLOW_SESSIONS[workflow_id] = result_state
    sync_to_database(result_state)

    return result_state


def get_final_output(state: AgentState) -> Dict[str, Any]:
    """
    Returns the structured final agent output for ASP.NET Core / React display.
    No hidden reasoning — only structured procurement result fields.
    """
    validation = state.get("validation_results") or {}
    status_val = state.get("status")
    approval_val = state.get("approval_status")

    if isinstance(status_val, WorkflowStatus):
        status_str = status_val.value
    else:
        status_str = str(status_val or "Running")

    if status_str == WorkflowStatus.WaitingForApproval.value:
        output_status = "READY_FOR_MANAGER_REVIEW"
    elif status_str == WorkflowStatus.Completed.value:
        output_status = "COMPLETED"
    elif status_str == WorkflowStatus.Failed.value:
        output_status = "FAILED"
    else:
        output_status = "IN_PROGRESS"

    return {
        "workflowId": state.get("workflow_id"),
        "procurementRequestId": state.get("procurement_request_id"),
        "status": output_status,
        "material": state.get("material_name"),
        "materialId": state.get("material_id"),
        "netDeficit": state.get("net_deficit"),
        "requiredQuantity": state.get("net_deficit"),
        "recommendedQuantity": state.get("recommended_quantity"),
        "recommendedSupplier": state.get("recommended_supplier"),
        "alternativeSuppliers": state.get("alternative_suppliers") or [],
        "estimatedUnitPrice": state.get("estimated_unit_price"),
        "estimatedTotalCost": state.get("estimated_total_cost"),
        "budgetLimit": state.get("budget_limit"),
        "unit": state.get("unit"),
        "supplierCandidates": state.get("supplier_candidates") or [],
        "qualityEvidence": state.get("quality_evidence") or [],
        "supplierVerification": state.get("supplier_verification"),
        "validationResults": validation,
        "approvalStatus": approval_val.value if isinstance(approval_val, ApprovalStatus) else str(approval_val or "Pending"),
        "managerDecision": state.get("manager_decision"),
        "revisionRequest": state.get("revision_request"),
        "risks": state.get("risks") or [],
        "sources": state.get("sources") or [],
        "recommendationSummary": state.get("recommendation_summary"),
        "completedSteps": state.get("completed_steps") or [],
        "errors": state.get("errors") or [],
        "finalOutcome": state.get("final_outcome"),
        "draftPo": state.get("draft_po"),
    }
