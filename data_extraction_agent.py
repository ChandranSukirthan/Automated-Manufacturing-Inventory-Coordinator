"""
AMIC Shared Agentic AI - Data Extraction Agent (Student 1 Ownership)
Bridged module re-exporting Student 1's Inventory & Data Extraction tools, state, and workflow.
"""
from ai.state import AgentState
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock,
    INVENTORY_TOOLS as tools,
)
from ai.nodes.planner_node import planner_node
from ai.nodes.data_extraction_node import data_extraction_node, agent_node
from ai.nodes.purchasing_node import purchasing_node
from ai.nodes.validation_node import validation_node
from ai.nodes.human_approval_node import human_approval_node
from ai.graph import app_graph, workflow, run_data_extraction_workflow

__all__ = [
    "AgentState",
    "get_inventory_levels",
    "query_inventory_history",
    "calculate_burn_rate",
    "detect_low_stock",
    "tools",
    "agent_node",
    "data_extraction_node",
    "planner_node",
    "purchasing_node",
    "validation_node",
    "human_approval_node",
    "workflow",
    "app_graph",
    "run_data_extraction_workflow",
]

if __name__ == "__main__":
    result = run_data_extraction_workflow("RM001")
    print("\nWorkflow Execution Output:")
    print(result)
