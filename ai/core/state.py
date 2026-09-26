from enum import StrEnum
from typing import Any, TypedDict


class WorkflowStatus(StrEnum):
    RUNNING = "Running"
    COMPLETED = "Completed"
    FAILED = "Failed"
    WAITING_FOR_APPROVAL = "WaitingForApproval"
    Running = "Running"
    Completed = "Completed"
    Failed = "Failed"
    WaitingForApproval = "WaitingForApproval"


class ApprovalStatus(StrEnum):
    PENDING = "Pending"
    APPROVED = "Approved"
    REJECTED = "Rejected"
    REVISION_REQUESTED = "RevisionRequested"
    Pending = "Pending"
    Approved = "Approved"
    Rejected = "Rejected"
    RevisionRequested = "RevisionRequested"


class AgentState(TypedDict, total=False):
    # ── Workflow metadata ──────────────────────────────────────────────────────
    workflow_id: str
    procurement_request_id: int | None
    objective: str
    plan: list[str]
    current_agent: str
    status: WorkflowStatus
    approval_status: ApprovalStatus

    # ── Procurement input (authoritative values from ASP.NET Core) ─────────────
    material_id: str | None
    material_name: str | None
    current_stock: float | None
    required_quantity: float | None
    safety_stock: float | None
    open_po_quantity: float | None
    net_deficit: float | None          # authoritative — never invented by AI
    budget_limit: float | None
    unit: str | None
    quality_requirement: str | None
    preferred_region: str | None
    required_by_date: str | None
    specification: str | None

    # ── Data extraction output ─────────────────────────────────────────────────
    inventory_data: dict[str, Any]
    production_data: dict[str, Any]
    supplier_rates: list[dict[str, Any]]
    historical_procurement: list[dict[str, Any]]

    # ── Purchasing agent output ────────────────────────────────────────────────
    supplier_candidates: list[dict[str, Any]]
    recommended_supplier: dict[str, Any] | None
    alternative_suppliers: list[str]
    recommended_quantity: float | None
    estimated_unit_price: float | None
    estimated_total_cost: float | None
    quality_evidence: list[dict[str, Any]]
    supplier_verification: str | None       # VERIFIED | UNVERIFIED | BLOCKED
    recommendation_summary: str | None
    risks: list[str]
    sources: list[str]
    draft_po: dict[str, Any] | None

    # ── Validation output ──────────────────────────────────────────────────────
    validation_results: dict[str, Any]

    # ── Human approval gate ────────────────────────────────────────────────────
    requires_approval: bool
    approved_by: str | None
    manager_decision: str | None           # APPROVE | REJECT | REQUEST_REVISION
    revision_request: str | None

    # ── Audit / execution trail ────────────────────────────────────────────────
    completed_steps: list[str]
    tool_call_log: list[dict[str, Any]]
    tool_results: dict[str, Any]
    errors: list[str]
    final_outcome: str | None

    # ── Timestamps ────────────────────────────────────────────────────────────
    created_at: str | None
    updated_at: str | None

    # ── Legacy fields kept for backward compatibility ──────────────────────────
    purchasing_data: dict[str, Any]
    quality_data: dict[str, Any]
    procurement_requirement: dict[str, Any]
    required_quantity_legacy: float | None
    total_cost: float | None
    final_decision: str | None
