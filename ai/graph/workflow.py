import uuid
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from langgraph.graph import StateGraph, START, END
import psycopg

from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings
from ai.agents.planner import planner_node
from ai.agents.data_extraction import data_extraction_node
from ai.agents.production_analysis import production_analysis_node
from ai.agents.purchasing import purchasing_node
from ai.agents.validation import validation_node, execution_node


def sync_to_database(state: AgentState) -> None:
    """
    Syncs the workflow state to PostgreSQL AgentWorkflows table so ASP.NET and
    frontend dashboards see live updates immediately.
    """
    workflow_id = state.get("workflow_id")
    if not workflow_id:
        return

    objective = state.get("objective", "")
    current_agent = state.get("current_agent", "Planner")
    status = state.get("status", WorkflowStatus.Running).value if isinstance(state.get("status"), WorkflowStatus) else str(state.get("status", "Running"))
    approval_status = state.get("approval_status", ApprovalStatus.Pending).value if isinstance(state.get("approval_status"), ApprovalStatus) else str(state.get("approval_status", "Pending"))
    final_outcome = state.get("final_outcome")
    completed_at = datetime.now(timezone.utc) if status in [WorkflowStatus.Completed.value, WorkflowStatus.Failed.value] else None

    try:
        with psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=3
        ) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO "AgentWorkflows" ("Id", "WorkflowId", "Objective", "CurrentAgent", "Status", "ApprovalStatus", "StartedAt", "CompletedAt", "FinalOutcome")
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT ("WorkflowId") DO UPDATE
                    SET "Objective" = EXCLUDED."Objective",
                        "CurrentAgent" = EXCLUDED."CurrentAgent",
                        "Status" = EXCLUDED."Status",
                        "ApprovalStatus" = EXCLUDED."ApprovalStatus",
                        "CompletedAt" = COALESCE(EXCLUDED."CompletedAt", "AgentWorkflows"."CompletedAt"),
                        "FinalOutcome" = EXCLUDED."FinalOutcome";
                """, (
                    str(uuid.uuid4()),
                    workflow_id,
                    objective,
                    current_agent,
                    status,
                    approval_status,
                    datetime.now(timezone.utc),
                    completed_at,
                    final_outcome
                ))
            conn.commit()
    except Exception as ex:
        # Graceful fallback: If DB connection is temporarily unavailable, logging only
        print(f"[Workflow Sync Warning] Could not sync {workflow_id} to DB: {ex}")


# Conditional Router Functions
def check_data_extraction_result(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "production_analysis"


def check_purchasing_result(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    return "validation"


def check_risk_decision(state: AgentState) -> str:
    if state.get("status") == WorkflowStatus.Failed:
        return END
    if state.get("requires_approval") or state.get("status") == WorkflowStatus.WaitingForApproval:
        return END  # Pauses for human approval
    return "execution"


def build_workflow_graph():
    """
    Assembles the StateGraph according to the Planner workflow specification:
    START -> Planner -> Data Extraction -> Production Analysis -> Purchasing -> Validation/Safety -> Risk decision -> [Human Approval if required] -> Resume -> Execution -> END
    """
    workflow = StateGraph(AgentState)

    # Register Nodes
    workflow.add_node("planner", planner_node)
    workflow.add_node("data_extraction", data_extraction_node)
    workflow.add_node("production_analysis", production_analysis_node)
    workflow.add_node("purchasing", purchasing_node)
    workflow.add_node("validation", validation_node)
    workflow.add_node("execution", execution_node)

    # Add Edges
    workflow.add_edge(START, "planner")
    workflow.add_edge("planner", "data_extraction")
    workflow.add_conditional_edges(
        "data_extraction",
        check_data_extraction_result,
        {
            "production_analysis": "production_analysis",
            END: END
        }
    )
    workflow.add_edge("production_analysis", "purchasing")
    workflow.add_conditional_edges(
        "purchasing",
        check_purchasing_result,
        {
            "validation": "validation",
            END: END
        }
    )
    workflow.add_conditional_edges(
        "validation",
        check_risk_decision,
        {
            "execution": "execution",
            END: END
        }
    )
    workflow.add_edge("execution", END)

    return workflow.compile()


# In-memory session store for active workflows
WORKFLOW_SESSIONS: Dict[str, AgentState] = {}
COMPILED_APP = build_workflow_graph()


def run_workflow(objective: str, workflow_id: Optional[str] = None) -> AgentState:
    """
    Starts and executes a workflow up to completion or approval gate.
    """
    wf_id = workflow_id or f"WF-{uuid.uuid4().hex[:6].upper()}"

    initial_state: AgentState = {
        "workflow_id": wf_id,
        "objective": objective,
        "current_agent": "Planner",
        "status": WorkflowStatus.Running,
        "approval_status": ApprovalStatus.Pending,
        "plan": [],
        "completed_steps": [],
        "tool_results": {},
        "inventory_data": {},
        "production_data": {},
        "purchasing_data": {},
        "validation_results": {},
        "final_outcome": None,
        "errors": [],
        "requires_approval": False,
    }

    sync_to_database(initial_state)
    result_state = COMPILED_APP.invoke(initial_state)

    WORKFLOW_SESSIONS[wf_id] = result_state
    sync_to_database(result_state)

    return result_state


def approve_and_resume(workflow_id: str) -> Optional[AgentState]:
    """
    Handles human approval action: approves the workflow and resumes execution to completion.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None

    state["approval_status"] = ApprovalStatus.Approved
    state["requires_approval"] = False
    state["status"] = WorkflowStatus.Running

    # Execute the final execution node
    final_state_diff = execution_node(state)
    state.update(final_state_diff)

    WORKFLOW_SESSIONS[workflow_id] = state
    sync_to_database(state)

    return state


def reject_workflow(workflow_id: str, reason: str = "Rejected by IT Admin") -> Optional[AgentState]:
    """
    Handles human rejection action: marks workflow as Rejected/Failed.
    """
    state = WORKFLOW_SESSIONS.get(workflow_id)
    if not state:
        return None

    state["approval_status"] = ApprovalStatus.Rejected
    state["status"] = WorkflowStatus.Failed
    state["final_outcome"] = f"Workflow rejected by human administrator: {reason}"
    state["completed_steps"] = list(state.get("completed_steps", [])) + ["Rejected by IT Admin"]

    WORKFLOW_SESSIONS[workflow_id] = state
    sync_to_database(state)

    return state

