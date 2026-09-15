import json
import re
from typing import List, Dict, Any
from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus
from ai.core.config import settings

# Optional OpenAI integration if user configures a real key
def _generate_plan_llm(objective: str) -> List[str]:
    from langchain_openai import ChatOpenAI
    from langchain_core.messages import SystemMessage, HumanMessage

    llm = ChatOpenAI(
        model="gpt-4o-mini",
        temperature=0.0,
        api_key=settings.OPENAI_API_KEY
    )

    system_prompt = (
        "You are the Planner/Coordinator Agent for an automated manufacturing facility. "
        "Your role is to convert business objectives into a structured, ordered list of concrete operational steps. "
        "Strict restrictions: You must NOT pay, send email, directly modify arbitrary database data, or bypass human approval. "
        "Return your response ONLY as a JSON list of step strings. Example: "
        '["Check inventory", "Calculate burn rate", "Check production requirements", "Check machine status", '
        '"Check supplier availability", "Create draft purchase order", "Validate purchase order", "Request human approval"]'
    )

    response = llm.invoke([
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"Objective: {objective}")
    ])

    content = response.content.strip()
    match = re.search(r"\[.*\]", content, re.DOTALL)
    if match:
        return json.loads(match.group(0))
    return [line.strip("- *0123456789. ") for line in content.split("\n") if line.strip()]


def _generate_plan_heuristic(objective: str) -> List[str]:
    """
    Deterministic domain planner ensuring 100% reliability even when running offline
    without external API dependencies.
    """
    obj_lower = objective.lower()

    if any(k in obj_lower for k in ["replenish", "boxpouch", "film", "material", "inventory", "stock", "raw"]):
        return [
            "Check inventory",
            "Calculate burn rate",
            "Check production requirements",
            "Check machine status",
            "Check supplier availability",
            "Create draft purchase order",
            "Validate purchase order",
            "Request human approval"
        ]
    elif any(k in obj_lower for k in ["maintenance", "uptime", "overhaul", "repair", "service", "machine"]):
        return [
            "Check machine status",
            "Calculate machine uptime",
            "Check maintenance requirement",
            "Assess production line schedule impact",
            "Prepare maintenance work order",
            "Validate technician availability and safety lockout",
            "Request human approval"
        ]
    elif any(k in obj_lower for k in ["schedule", "shift", "capacity", "output", "target"]):
        return [
            "Query production schedule",
            "Calculate production impact",
            "Inspect raw material sufficiency",
            "Evaluate machine operational capacities",
            "Formulate revised shift targets",
            "Validate schedule feasibility",
            "Request human approval"
        ]
    else:
        return [
            "Check inventory",
            "Calculate burn rate",
            "Check production requirements",
            "Check machine status",
            "Check supplier availability",
            "Create draft purchase order",
            "Validate purchase order",
            "Request human approval"
        ]


def planner_node(state: AgentState) -> Dict[str, Any]:
    """
    Planner Agent Node:
    Takes objective, generates structured multi-step plan, delegates to downstream agents.
    """
    objective = state.get("objective", "Replenish BoxPouch film because inventory is low.")
    
    plan: List[str] = []
    has_valid_key = (
        settings.OPENAI_API_KEY
        and settings.OPENAI_API_KEY.strip() != ""
        and not settings.OPENAI_API_KEY.startswith("your-")
    )

    if has_valid_key:
        try:
            plan = _generate_plan_llm(objective)
        except Exception:
            plan = _generate_plan_heuristic(objective)
    else:
        plan = _generate_plan_heuristic(objective)

    return {
        "plan": plan,
        "current_agent": "Planner",
        "status": WorkflowStatus.Running,
        "approval_status": state.get("approval_status", ApprovalStatus.Pending),
        "completed_steps": state.get("completed_steps", []) + ["Generated execution plan"],
        "errors": state.get("errors", [])
    }

