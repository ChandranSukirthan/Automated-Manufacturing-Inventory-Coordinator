import datetime
import logging
from langchain_core.messages import AIMessage
from ai.state import AgentState

logger = logging.getLogger("amic_agentic_ai.planner_node")


def planner_node(state: AgentState) -> dict:
    """
    Stage 1: Planner Agent Node
    Defines the replenishment goal and sets up context for the Data Extraction Agent.
    """
    now = datetime.datetime.now(datetime.timezone.utc)
    mat_id = state.get("target_material_id") or state.get("target_batch") or "RM001"
    wf_id = state.get("workflow_id") or f"WF-{now.strftime('%Y%m%d%H%M%S')}"

    logger.info(f"[Planner] Initiating procurement planning for material: {mat_id} (Workflow: {wf_id})")

    plan_message = (
        f"Objective: Evaluate inventory stock levels, consumption telemetry, and burn rate for {mat_id}. "
        f"Step 1: Execute Data Extraction tools. "
        f"Step 2: Check shortage risk. "
        f"Step 3: Route to Purchasing and Validation."
    )

    now_iso = now.isoformat()
    timestamps = state.get("timestamps", {})
    timestamps["planner_started"] = now_iso

    return {
        "workflow_id": wf_id,
        "target_material_id": mat_id,
        "current_agent": "Data Extraction",
        "timestamps": timestamps,
        "messages": [AIMessage(content=plan_message, name="PlannerAgent")]
    }
