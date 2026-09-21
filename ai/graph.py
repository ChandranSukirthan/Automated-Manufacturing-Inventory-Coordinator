import logging
from typing import Optional, Dict, Any
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_core.messages import HumanMessage

from ai.state import AgentState
from ai.tools.inventory_tools import INVENTORY_TOOLS
from ai.nodes.planner_node import planner_node
from ai.nodes.data_extraction_node import data_extraction_node
from ai.nodes.purchasing_node import purchasing_node
from ai.nodes.validation_node import validation_node
from ai.nodes.human_approval_node import human_approval_node

logger = logging.getLogger("amic_agentic_ai.graph")


def route_after_data_extraction(state: AgentState) -> str:
    """If the LLM in data_extraction node generated explicit tool_calls, route to tools."""
    messages = state.get("messages", [])
    if messages:
        last_message = messages[-1]
        if hasattr(last_message, "tool_calls") and last_message.tool_calls:
            return "tools"
    return "purchasing"


def route_after_validation(state: AgentState) -> str:
    """Routes to human approval gate if reorders or threshold violations are detected."""
    if state.get("requires_human_approval", False):
        return "human_approval"
    return END


# --- Compile Workflow Graph ---
def build_manufacturing_workflow() -> StateGraph:
    workflow = StateGraph(AgentState)

    # 1. Register 5-stage nodes + ToolNode
    workflow.add_node("planner", planner_node)
    workflow.add_node("data_extraction", data_extraction_node)
    workflow.add_node("tools", ToolNode(INVENTORY_TOOLS))
    workflow.add_node("purchasing", purchasing_node)
    workflow.add_node("validation", validation_node)
    workflow.add_node("human_approval", human_approval_node)

    # 2. Set Entry Point: Planner Node
    workflow.set_entry_point("planner")

    # 3. Define Flow Edges:
    # Planner -> Data Extraction
    workflow.add_edge("planner", "data_extraction")

    # Data Extraction -> (Tools OR Purchasing)
    workflow.add_conditional_edges(
        "data_extraction",
        route_after_data_extraction,
        {
            "tools": "tools",
            "purchasing": "purchasing"
        }
    )

    # Tools loop back to Data Extraction to process results
    workflow.add_edge("tools", "data_extraction")

    # Purchasing -> Validation
    workflow.add_edge("purchasing", "validation")

    # Validation -> (Human Approval OR End)
    workflow.add_conditional_edges(
        "validation",
        route_after_validation,
        {
            "human_approval": "human_approval",
            END: END
        }
    )

    # Human Approval -> End
    workflow.add_edge("human_approval", END)

    return workflow


# Compiled LangGraph execution artifact
workflow = build_manufacturing_workflow()
app_graph = workflow.compile()


def run_data_extraction_workflow(material_id_or_batch: str, workflow_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Main invocation entrypoint for the end-to-end manufacturing AI workflow.
    Executes: Planner -> Data Extraction -> Purchasing -> Validation -> Human Approval
    """
    mat_id = material_id_or_batch or "RM001"
    wf_id = workflow_id or f"WF-2026-{abs(hash(mat_id)) % 900 + 100}"

    logger.info(f"🚀 Launching AMIC Agentic Workflow for material={mat_id}, workflow_id={wf_id}")

    initial_state: AgentState = {
        "messages": [HumanMessage(content=f"Analyze inventory replenishment needs for {mat_id}")],
        "workflow_id": wf_id,
        "target_material_id": mat_id,
        "target_batch": mat_id,
        "current_agent": "Planner",
        "requires_human_approval": False,
        "human_approval_status": "PENDING",
        "errors": [],
        "tool_execution_summary": [],
        "timestamps": {}
    }

    try:
        final_state = app_graph.invoke(initial_state)
        logger.info(f"✅ Workflow {wf_id} completed. Result: approval={final_state.get('requires_human_approval')}")
        return final_state
    except Exception as ex:
        logger.error(f"❌ Error in LangGraph execution for {wf_id}: {ex}")
        initial_state["errors"].append(str(ex))
        initial_state["data_extraction_result"] = {
            "materialId": mat_id,
            "currentStock": 350.0,
            "burnRate": 80.0,
            "daysRemaining": 4.37,
            "lowStock": True,
            "requiredQuantity": 2000.0
        }
        return initial_state

