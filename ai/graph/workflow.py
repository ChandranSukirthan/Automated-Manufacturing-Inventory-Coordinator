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

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import psycopg
from langgraph.graph import StateGraph, START, END

from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings
from ai.session_store import SessionStore
import threading
import re
import hashlib
import os
import time
from pathlib import Path
from functools import wraps

_LOCKS_GUARD = threading.Lock()
_WORKFLOW_LOCKS = {}

class _WorkflowLock:
    """Re-entrant in-process lock backed by an OS lock for other workers."""
    def __init__(self, path: Path, blocking: bool = True):
        self.path = path
        self.blocking = blocking
        self.thread_lock = threading.RLock()
        self.local = threading.local()

    def __enter__(self):
        self.thread_lock.acquire()
        depth = getattr(self.local, "depth", 0)
        if depth:
            self.local.depth = depth + 1
            return self
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = open(self.path, "a+b")
        if self.handle.tell() == 0:
            self.handle.write(b"0")
            self.handle.flush()
        self.handle.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                while True:
                    try:
                        msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
                        break
                    except OSError:
                        if not self.blocking:
                            raise BlockingIOError
                        time.sleep(0.05)
            else:
                import fcntl
                flags = fcntl.LOCK_EX | (0 if self.blocking else fcntl.LOCK_NB)
                fcntl.flock(self.handle.fileno(), flags)
        except Exception:
            self.handle.close()
            self.thread_lock.release()
            raise
        self.local.depth = 1
        return self

    def __exit__(self, *_):
        depth = self.local.depth
        if depth > 1:
            self.local.depth = depth - 1
            self.thread_lock.release()
            return
        self.handle.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        self.handle.close()
        self.local.depth = 0
        self.thread_lock.release()


def _workflow_lock(workflow_id, blocking=True):
    store_path = Path(WORKFLOW_SESSIONS.path)
    digest = hashlib.sha256(str(workflow_id).encode()).hexdigest()
    key = (str(store_path.resolve()), digest)
    with _LOCKS_GUARD:
        lock = _WORKFLOW_LOCKS.get(key)
        if lock is None or lock.blocking != blocking:
            lock = _WorkflowLock(store_path.parent / ".workflow_locks" / digest, blocking)
            _WORKFLOW_LOCKS[key] = lock
        return lock

def _serialized_action(action):
    @wraps(action)
    def execute(workflow_id, *args, **kwargs):
        with _workflow_lock(workflow_id):
            return action(workflow_id, *args, **kwargs)
    return execute
from ai.agents.planner import planner_node
from ai.agents.data_extraction import data_extraction_node
from ai.agents.production_analysis import production_analysis_node
from ai.agents.purchasing import purchasing_node
from ai.agents.validation import validation_node, execution_node
from ai.agents.supervisor import supervisor_node


# ── Database sync ──────────────────────────────────────────────────────────────

def _publication_headers(encoded_state: str):
    import hmac
    from ai.core.request_context import inventory_api_headers
    timestamp = str(int(time.time()))
    signature = hmac.new(settings.jwt_secret_key.encode(), (timestamp + "\n" + encoded_state).encode(), hashlib.sha256).hexdigest()
    return {**inventory_api_headers(), "Content-Type": "application/json", "X-AI-Timestamp": timestamp, "X-AI-Signature": signature}


def sync_to_database(state: AgentState) -> bool:
    """Publish structured state through the backend. SQLite retains failed updates.

    No AI-owned PostgreSQL mutation; the backend authenticates and persists this
    bounded contract. A failed publication is visible and blocks manager readiness.
    Retry occurs on the next workflow/revalidation action using the durable session.
    """
    import httpx
    import logging
    from ai.config import BACKEND_HOST, API_TIMEOUT_SECONDS
    from ai.core.request_context import inventory_api_headers
    from ai.session_store import clean_state
    if not state.get("workflow_id"):
        return False
    state["synchronization_pending"] = True
    clean = clean_state(state)
    try:
        # Sign and transmit identical JSON bytes across HTTPX versions.
        encoded_state = json.dumps(clean, separators=(",", ":"), ensure_ascii=False, default=str)
        with httpx.Client(timeout=API_TIMEOUT_SECONDS) as client:
            response = client.put(
                f"{BACKEND_HOST}/api/internal/workflows/{state['workflow_id']}/state",
                headers=_publication_headers(encoded_state), content='{"state":' + encoded_state + '}')
            response.raise_for_status()
        state["synchronization_pending"] = False
        state.pop("synchronization_error", None)
        success = True
    except Exception as error:
        # Do not persist headers, tokens or arbitrary provider exception text.
        state["synchronization_error"] = "Backend state publication failed; retry with an authorized session"
        logging.getLogger(__name__).warning("Workflow publication failed: %s (%s)", state["workflow_id"], type(error).__name__)
        success = False
    WORKFLOW_SESSIONS[state["workflow_id"]] = state
    return success


def save_procurement_outcome(state: AgentState) -> None:
    """Actual order/payment/delivery outcomes belong to the backend lifecycle.

    The manager decision is already included in structured workflow publication;
    recording an AI approval as completed procurement would corrupt learning data.
    """
    return None


# ── Conditional routers ────────────────────────────────────────────────────────

def _after_data_extraction(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "production_analysis"


def _after_purchasing(state: AgentState) -> str:
    if state.get("status") in (WorkflowStatus.Failed, WorkflowStatus.WaitingForApproval, WorkflowStatus.Completed):
        return END
    return "validation"


def _after_validation(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    if state.get("automatic_retry_required"):
        return "purchasing"
    if state.get("requires_approval") or state.get("status") == WorkflowStatus.WaitingForApproval:
        return END  # Pause for human approval gate
    if state.get("approval_status") == ApprovalStatus.RevisionRequested:
        return "purchasing"  # Loop back to purchasing on revision
    return END


# ── Graph assembly ─────────────────────────────────────────────────────────────

def _maintenance_node(state):
    machine_id = state.get("machine_id")
    if not machine_id:
        raise ValueError("Maintenance requires an exact machine ID")
    with psycopg.connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as connection:
        with connection.cursor() as cursor:
            cursor.execute('SELECT "Name", "UptimeHours", "MaintenanceIntervalHours", "Status" FROM "Machines" WHERE "Id" = %s', (machine_id,))
            row = cursor.fetchone()
    if not row:
        raise ValueError("The maintenance target machine does not exist")
    return {"current_agent": "Maintenance Review", "status": WorkflowStatus.WaitingForApproval,
            "requires_approval": True, "approval_status": ApprovalStatus.Pending,
            "production_data": {"machineId": machine_id, "name": row[0], "uptimeHours": row[1],
                                "maintenanceIntervalHours": row[2], "status": row[3]},
            "completed_steps": state.get("completed_steps", []) + ["Maintenance: assessed the exact machine's live telemetry"],
            "final_outcome": "Waiting for IT Admin maintenance authorization"}


def _record_stage(node):
    def recorded(state):
        started = time.perf_counter()
        try:
            difference = node(state)
        except Exception as error:
            difference = {"status": WorkflowStatus.Failed, "requires_approval": False,
                          "required_action": "RESTORE_SERVICE" if "unavailable" in str(error).lower() else "CORRECT_DATA",
                          "validation_results": {**(state.get("validation_results") or {}), "isValid": False, "valid": False, "overallStatus": "BLOCKED"}, "errors": state.get("errors", []) + [str(error)],
                          "current_agent": node.__name__, "final_outcome": "This workflow failed; correct the reported issue and retry."}
        difference["agent_handoffs"] = state.get("agent_handoffs", []) + [{
            "durationMs": round((time.perf_counter() - started) * 1000, 2),
            "agent": node.__name__, "receivedFields": sorted(state.keys()),
            "receivedToolResults": sorted((state.get("tool_results") or {}).keys()),
            "producedFields": sorted(difference.keys()),
            "status": str(difference.get("status", state.get("status"))),
        }]
        updated = {**state, **difference}
        WORKFLOW_SESSIONS[updated["workflow_id"]] = updated
        sync_to_database(updated)
        difference["synchronization_pending"] = updated.get("synchronization_pending", False)
        difference["synchronization_error"] = updated.get("synchronization_error")
        return difference
    return recorded


def _after_planner(state):
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "maintenance" if state.get("workflow_type") == "Maintenance" else "data_extraction"


def build_workflow_graph():
    """
    Assembles the LangGraph StateGraph connecting all 4 collaborative agents:
    1. planner (Planner / Coordinator)
    2. data_extraction (Data Extraction Agent - Inventory)
    3. production_analysis (Production Analysis Agent - IT Admin/Equipment)
    4. purchasing (Goal-Based Purchasing Agent - Supply Chain Manager)
    5. validation (Validation / Safety Agent - Quality & Risk Gate)
    """
    workflow = StateGraph(AgentState)

    workflow.add_node("planner", _record_stage(planner_node))
    workflow.add_node("data_extraction", _record_stage(data_extraction_node))
    workflow.add_node("production_analysis", _record_stage(production_analysis_node))
    workflow.add_node("purchasing", _record_stage(purchasing_node))
    workflow.add_node("validation", _record_stage(validation_node))
    workflow.add_node("supervisor", _record_stage(supervisor_node))

    workflow.add_edge(START, "planner")
    workflow.add_node("maintenance", _record_stage(_maintenance_node))
    workflow.add_conditional_edges("planner", _after_planner, {"maintenance": "maintenance", "data_extraction": "data_extraction", END: END})
    workflow.add_edge("maintenance", END)
    workflow.add_conditional_edges(
        "data_extraction",
        _after_data_extraction,
        {"production_analysis": "production_analysis", END: END},
    )
    workflow.add_conditional_edges("production_analysis",
        lambda state: END if state.get("status") == WorkflowStatus.Failed else "purchasing",
        {"purchasing": "purchasing", END: END})
    workflow.add_conditional_edges(
        "purchasing",
        _after_purchasing,
        {"validation": "validation", END: END},
    )
    workflow.add_conditional_edges("validation", lambda state: END if state.get("status") == WorkflowStatus.Failed else "supervisor", {END: END, "supervisor": "supervisor"})
    workflow.add_conditional_edges(
        "supervisor",
        _after_validation,
        {"purchasing": "purchasing", END: END},
    )

    return workflow.compile()


WORKFLOW_SESSIONS = SessionStore()
COMPILED_APP = build_workflow_graph()


# ── Public API ─────────────────────────────────────────────────────────────────

def run_workflow(objective, workflow_id=None, **kwargs):
    wf_id = workflow_id or f"WF-{uuid.uuid4().hex[:24].upper()}"
    with _workflow_lock(wf_id):
        return _run_workflow_unlocked(objective, workflow_id=wf_id, **kwargs)


def _run_workflow_unlocked(
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
    quality_data: Optional[Dict[str, Any]] = None,
    purchasing_data: Optional[Dict[str, Any]] = None,
    workflow_type: str = "Procurement",
    machine_id: Optional[str] = None,
    trigger_type: str = "AutoLowStock",
    requested_quantity: Optional[float] = None,
    request_reason: Optional[str] = None,
) -> AgentState:
    """
    Starts and executes the workflow up to completion or the human approval gate.
    Authoritative procurement values from ASP.NET Core are passed directly as
    top-level state fields — the AI never invents them.
    """
    wf_id = workflow_id or f"WF-{uuid.uuid4().hex[:6].upper()}"
    existing = WORKFLOW_SESSIONS.get(wf_id)
    identity = dict(trigger_type=trigger_type, requested_quantity=requested_quantity, objective=objective,
                    material_id=material_id, workflow_type=workflow_type, machine_id=machine_id,
                    required_quantity=required_quantity, budget_limit=budget_limit, net_deficit=net_deficit,
                    procurement_request_id=procurement_request_id, specification=specification,
                    quality_requirement=quality_requirement, preferred_region=preferred_region,
                    required_by_date=required_by_date)
    if existing and existing.get("current_agent") != "Queued":
        original = existing.get("request_identity") or existing
        if any(original.get(key) != value for key, value in identity.items()):
            raise ValueError("Workflow ID is already assigned to a different request")
        return existing
    now_iso = datetime.now(timezone.utc).isoformat()

    initial_inv = {}
    if material_id:
        initial_inv["materialId"] = material_id
        initial_inv["itemCode"] = material_id
    if required_quantity:
        initial_inv["requiredQuantity"] = required_quantity

    initial_state: AgentState = {
        "workflow_id": wf_id,
        "queued_request": existing.get("queued_request") if existing else None,
        "request_identity": identity,
        "workflow_type": workflow_type,
        "trigger_type": trigger_type, "requested_quantity": requested_quantity, "request_reason": request_reason,
        "machine_id": machine_id,
        "procurement_request_id": procurement_request_id,
        "objective": objective,
        "current_agent": "Planner",
        "status": WorkflowStatus.Running,
        "approval_status": ApprovalStatus.Pending,
        "plan": [],
        "completed_steps": [],
        "tool_results": {},
        "agent_handoffs": [],
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
        # Outputs (initialised)
        "inventory_data": initial_inv,
        "production_data": {},
        "purchasing_data": purchasing_data or {},
        "quality_data": quality_data or {},
        "supplier_rates": [],
        "historical_procurement": [],
        "supplier_candidates": [],
        "recommended_supplier": None,
        "alternative_suppliers": [],
        "supplier_selection_attempt": (existing or {}).get("supplier_selection_attempt", 0),
        "max_supplier_selection_attempts": 3,
        "excluded_supplier_ids": (existing or {}).get("excluded_supplier_ids", []),
        "automatic_retry_required": False,
        "recommended_quantity": None,
        "estimated_unit_price": None,
        "estimated_total_cost": None,
        "quality_evidence": [],
        "supplier_verification": None,
        "recommendation_summary": None,
        "risks": [],
        "sources": [],
        "draft_po": None,
        "validation_results": (existing or {}).get("validation_results", {}),
        "validation_history": (existing or {}).get("validation_history", []),
        "requires_approval": False,
        "manager_decision": None,
        "revision_request": None,
        "errors": [],
        "final_outcome": None,
        "created_at": now_iso,
        "updated_at": now_iso,
    }

    WORKFLOW_SESSIONS[wf_id] = initial_state
    sync_to_database(initial_state)
    try:
        with _workflow_lock(wf_id):
            result_state = COMPILED_APP.invoke(initial_state)
    except Exception as error:
        result_state = WORKFLOW_SESSIONS.get(wf_id, initial_state)
        result_state.update(status=WorkflowStatus.Failed, current_agent="Interrupted",
                            errors=result_state.get("errors", []) + [str(error)],
                            final_outcome="Workflow execution failed. Correct the reported issue and retry.")
    WORKFLOW_SESSIONS[wf_id] = result_state
    sync_to_database(result_state)

    return result_state


def _refresh_quality_decision(state):
    """Read QA decisions from their authoritative store; never copy stale finance checks."""
    if settings.demo_mode:
        return
    with psycopg.connect(settings.database_url, connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on") as connection:
        with connection.cursor() as cursor:
            cursor.execute('SELECT "ValidationResults" FROM "AgentWorkflows" WHERE "WorkflowId" = %s', (state["workflow_id"],))
            row = cursor.fetchone()
    if row and row[0]:
        results = json.loads(row[0]) if isinstance(row[0], str) else row[0]
        prior = dict(state.get("validation_results") or {})
        for key in ("manualResolutionStatus", "manualResolutionNote", "resolvedBy", "resolvedAt", "historicalRisk", "defectFingerprint"):
            if key in results:
                prior[key] = results[key]
        state["validation_results"] = prior


def _evaluate_proposal(state):
    while True:
        state.update(_record_stage(validation_node)(state))
        # A crashed specialist must never be interpreted as a successful assessment.
        if state.get("status") == WorkflowStatus.Failed:
            return
        state.update(_record_stage(supervisor_node)(state))
        if not state.get("automatic_retry_required"):
            return
        state.update(_record_stage(purchasing_node)(state))
        if state.get("status") == WorkflowStatus.Failed:
            return


@_serialized_action
def revalidate_workflow(workflow_id):
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None
    if state.get("approval_status") in (ApprovalStatus.Approved, ApprovalStatus.Rejected):
        raise ValueError("A decided workflow cannot be resumed")
    if not state.get("draft_po"):
        raise ValueError("There is no proposal to revalidate")
    _refresh_quality_decision(state)
    state.update(status=WorkflowStatus.Running, automatic_retry_required=False)
    _evaluate_proposal(state)
    WORKFLOW_SESSIONS[workflow_id] = state
    sync_to_database(state)
    return state


@_serialized_action
def approve_and_resume(workflow_id: str, approved_by: Optional[str] = None) -> Optional[AgentState]:
    """
    Handles Supply Chain Manager APPROVE action.
    Resumes execution and persists procurement outcome for future learning.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if state and state.get("synchronization_pending") and not sync_to_database(state):
        raise ValueError("Publish the durable workflow to the backend before approving")
    if not state:
        return None

    if state.get("approval_status") == ApprovalStatus.Approved:
        return state
    if state.get("status") != WorkflowStatus.WaitingForApproval or not state.get("validation_results", {}).get("isValid"):
        raise ValueError("Workflow is not ready for approval; resolve its validation findings first")
    if state.get("workflow_type") == "Maintenance":
        raise ValueError("Maintenance authorization is performed by the backend IT Admin service")

    _refresh_quality_decision(state)
    state.update(_record_stage(validation_node)(state))
    if state.get("status") != WorkflowStatus.Failed:
        state.update(_record_stage(supervisor_node)(state))
    if state.get("status") != WorkflowStatus.WaitingForApproval or not state.get("validation_results", {}).get("isValid"):
        state.update(status=WorkflowStatus.Failed, requires_approval=False, automatic_retry_required=False)
        WORKFLOW_SESSIONS[workflow_id] = state
        sync_to_database(state)
        raise ValueError("Fresh validation failed; resolve the findings before approval")
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


@_serialized_action
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
    if state.get("approval_status") == ApprovalStatus.Approved:
        raise ValueError("An approved workflow cannot be rejected")
    if state.get("workflow_type") == "Maintenance":
        raise ValueError("Maintenance decisions belong to the backend IT Admin service")

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


@_serialized_action
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
    if state.get("approval_status") == ApprovalStatus.Approved:
        raise ValueError("An approved workflow cannot be revised")
    if state.get("workflow_type") == "Maintenance":
        raise ValueError("Maintenance decisions belong to the backend IT Admin service")

    if int(state.get("supplier_selection_attempt") or 0) >= 3:
        raise ValueError("Three supplier attempts have been used; start a new reviewed request")
    _refresh_quality_decision(state)
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
    state["approval_status"] = ApprovalStatus.Pending
    state["errors"] = []
    state["draft_po"] = None
    state["purchasing_data"] = {key: value for key, value in state.get("purchasing_data", {}).items() if key != "draft_po"}
    with _workflow_lock(workflow_id):
        result_state = {**state, **_record_stage(purchasing_node)(state)}
        if result_state.get("draft_po") and result_state.get("status") != WorkflowStatus.Failed:
            _evaluate_proposal(result_state)
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

    if state.get("synchronization_pending"):
        output_status = "SYNC_PENDING"
    elif status_str == WorkflowStatus.WaitingForApproval.value:
        output_status = "READY_FOR_MANAGER_REVIEW"
    elif status_str == WorkflowStatus.Completed.value:
        output_status = "COMPLETED"
    elif status_str == WorkflowStatus.Failed.value:
        output_status = "FAILED"
    else:
        output_status = "IN_PROGRESS"

    return {
        "synchronizationPending": bool(state.get("synchronization_pending")),
        "synchronizationError": state.get("synchronization_error"),
        "workflowType": state.get("workflow_type", "Procurement"),
        "agentHandoffs": state.get("agent_handoffs", []),
        "machineId": state.get("machine_id"),
        "workflowId": state.get("workflow_id"),
        "workflow_id": state.get("workflow_id"),
        "procurementRequestId": state.get("procurement_request_id"),
        "procurement_request_id": state.get("procurement_request_id"),
        "status": status_str,
        "reviewStatus": output_status,
        "review_status": output_status,
        "material": state.get("material_name"),
        "materialName": state.get("material_name"),
        "material_name": state.get("material_name"),
        "materialId": state.get("material_id"),
        "material_id": state.get("material_id"),
        "netDeficit": state.get("net_deficit"),
        "net_deficit": state.get("net_deficit"),
        "requiredQuantity": state.get("required_quantity"),
        "required_quantity": state.get("required_quantity"),
        "recommendedQuantity": state.get("recommended_quantity"),
        "recommended_quantity": state.get("recommended_quantity"),
        "recommendedSupplier": state.get("recommended_supplier"),
        "recommended_supplier": state.get("recommended_supplier"),
        "alternativeSuppliers": state.get("alternative_suppliers") or [],
        "alternative_suppliers": state.get("alternative_suppliers") or [],
        "estimatedUnitPrice": state.get("estimated_unit_price"),
        "estimated_unit_price": state.get("estimated_unit_price"),
        "estimatedTotalCost": state.get("estimated_total_cost"),
        "estimated_total_cost": state.get("estimated_total_cost"),
        "budgetLimit": state.get("budget_limit"),
        "budget_limit": state.get("budget_limit"),
        "unit": state.get("unit"),
        "supplierCandidates": state.get("supplier_candidates") or [],
        "supplier_candidates": state.get("supplier_candidates") or [],
        "qualityEvidence": state.get("quality_evidence") or [],
        "quality_evidence": state.get("quality_evidence") or [],
        "supplierVerification": state.get("supplier_verification"),
        "supplier_verification": state.get("supplier_verification"),
        "requiredAction": state.get("required_action"),
        "triggerType": state.get("trigger_type", "AutoLowStock"),
        "requestedQuantity": state.get("requested_quantity"),
        "validationResults": validation,
        "validation_results": validation,
        "validationHistory": state.get("validation_history") or [],
        "validation_history": state.get("validation_history") or [],
        "supplierSelectionAttempt": state.get("supplier_selection_attempt") or 0,
        "maxSupplierSelectionAttempts": state.get("max_supplier_selection_attempts") or 3,
        "approvalStatus": approval_val.value if isinstance(approval_val, ApprovalStatus) else str(approval_val or "Pending"),
        "approval_status": approval_val.value if isinstance(approval_val, ApprovalStatus) else str(approval_val or "Pending"),
        "managerDecision": state.get("manager_decision"),
        "manager_decision": state.get("manager_decision"),
        "revisionRequest": state.get("revision_request"),
        "revision_request": state.get("revision_request"),
        "risks": state.get("risks") or [],
        "sources": state.get("sources") or [],
        "recommendationSummary": state.get("recommendation_summary"),
        "recommendation_summary": state.get("recommendation_summary"),
        "completedSteps": state.get("completed_steps") or [],
        "completed_steps": state.get("completed_steps") or [],
        "errors": state.get("errors") or [],
        "finalOutcome": state.get("final_outcome"),
        "final_outcome": state.get("final_outcome"),
        "draftPo": state.get("draft_po"),
        "draft_po": state.get("draft_po"),
        "purchasing_data": state.get("purchasing_data") or {},
        "current_agent": state.get("current_agent"),
    }
