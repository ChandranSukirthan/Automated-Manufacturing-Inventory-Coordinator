import json
import logging
from typing import TypedDict, Annotated, Sequence, Union
import operator
import httpx

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage, ToolMessage
from langchain_core.tools import tool
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

# We assume the user has Ollama running locally with a model like 'llama3' or 'mistral'
try:
    from langchain_community.chat_models import ChatOllama
    llm = ChatOllama(model="llama3", temperature=0)
except ImportError:
    # Fallback to a mock LLM if libraries aren't installed yet
    llm = None

logger = logging.getLogger(__name__)

# --- 1. Define State ---
class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    target_batch: str
    requires_human_approval: bool
    human_approval_status: str # "PENDING", "APPROVED", "REJECTED"
    final_decision: str

# --- 2. Define Tools ---
@tool
def get_inventory_levels(target_batch: str) -> str:
    """Tool: Fetches current stock levels from the C# backend for a specific batch."""
    print(f"\n[Tool Execution] Fetching inventory for {target_batch}...")
    try:
        # Assuming the C# API is running
        response = httpx.get("http://localhost:5158/api/inventory", timeout=5.0)
        if response.status_code == 200:
            return json.dumps(response.json())
    except Exception as e:
        print(f"Error calling API: {e}")
        
    # Fallback for demonstration
    return json.dumps({"stock": 1000.5, "unit": "meters", "status": "In Stock"})

@tool
def query_production_db(target_batch: str) -> str:
    """Tool: Reads upcoming production schedules from the database."""
    print(f"\n[Tool Execution] Querying production DB for {target_batch} schedule...")
    # Mock data for demonstration since C# doesn't have this endpoint yet
    return json.dumps({
        "upcoming_runs": 2, 
        "required_material_per_run": 600,
        "total_required": 1200
    })

tools = [get_inventory_levels, query_production_db]

# --- 3. Define Nodes ---
def agent_node(state: AgentState):
    """The main LLM node that decides which tools to call or makes a final decision."""
    messages = state.get("messages", [])
    
    # Only bind tools if LLM exists
    if llm:
        llm_with_tools = llm.bind_tools(tools)
        response = llm_with_tools.invoke(messages)
    else:
        # Mock LLM behavior if langchain isn't installed properly
        response = AIMessage(
            content="I have analyzed the inventory. There is a shortage. We need to reorder.",
            additional_kwargs={"tool_calls": []}
        )
        
    return {"messages": [response]}

def validation_node(state: AgentState):
    """
    Evaluates the LLM's final response to see if it implies a high-impact action (like Reordering)
    that requires human approval.
    """
    messages = state.get("messages", [])
    last_message = messages[-1].content.lower()
    
    requires_approval = False
    
    # Deterministic validation check
    if "reorder" in last_message or "shortage" in last_message or "alert" in last_message:
        requires_approval = True
        
    return {"requires_human_approval": requires_approval}

# --- 4. Define Graph Routing ---
def should_continue(state: AgentState) -> str:
    """Determines if the agent called a tool, finished, or needs approval."""
    messages = state.get("messages", [])
    last_message = messages[-1]
    
    # If the LLM called a tool, route to the tools node
    if last_message.tool_calls:
        return "tools"
        
    # If it didn't call a tool, it's done reasoning. Route to validation.
    return "validate"

def route_after_validation(state: AgentState) -> str:
    if state.get("requires_human_approval"):
        return "human_approval"
    return END

def human_approval_node(state: AgentState):
    """
    Pauses the workflow for human approval. 
    In a real app, this would use an interrupt/checkpoint system.
    """
    print("\n==============================================")
    print("⚠️ HIGH IMPACT ACTION DETECTED. PAUSING... ⚠️")
    print("==============================================")
    print(f"Agent Findings: {state['messages'][-1].content}")
    
    # Simulate an external webhook approval
    state["human_approval_status"] = "APPROVED"
    state["final_decision"] = "Action Approved by Floor Manager via Webhook."
    return state

# --- 5. Compile Graph ---
workflow = StateGraph(AgentState)

# Add nodes
workflow.add_node("agent", agent_node)
workflow.add_node("tools", ToolNode(tools))
workflow.add_node("validate", validation_node)
workflow.add_node("human_approval", human_approval_node)

# Add edges
workflow.set_entry_point("agent")

# Agent -> (Tools OR Validate)
workflow.add_conditional_edges(
    "agent",
    should_continue,
    {
        "tools": "tools",
        "validate": "validate"
    }
)

# Tools -> Agent (Loop back to let agent think about tool results)
workflow.add_edge("tools", "agent")

# Validate -> (Human Approval OR End)
workflow.add_conditional_edges(
    "validate",
    route_after_validation,
    {
        "human_approval": "human_approval",
        END: END
    }
)

# Human Approval -> End
workflow.add_edge("human_approval", END)

# Compile
app_graph = workflow.compile()

# --- 6. Execution Wrapper ---
def run_data_extraction_workflow(batch_name: str):
    print(f"\n🚀 Starting Data Extraction Workflow for {batch_name}...\n")
    
    system_prompt = SystemMessage(
        content=f"You are the Data Extraction Agent for a manufacturing plant. "
                f"Your target batch is '{batch_name}'. "
                f"You MUST use your tools to check both the production schedule and the current inventory levels. "
                f"Compare the 'total_required' against the 'stock' level. "
                f"If stock < total_required, explicitly recommend a 'REORDER'. "
                f"If stock >= total_required, state that stock is sufficient."
    )
    
    initial_state = {
        "messages": [system_prompt, HumanMessage(content=f"Analyze stock for {batch_name}")],
        "target_batch": batch_name,
        "requires_human_approval": False,
        "human_approval_status": "PENDING",
        "final_decision": ""
    }
    
    try:
        final_state = app_graph.invoke(initial_state)
        print("\n✅ Final State Output:")
        print(f"Requires Approval: {final_state.get('requires_human_approval')}")
        print(f"Approval Status: {final_state.get('human_approval_status')}")
        print(f"Final Agent Message: {final_state['messages'][-1].content}")
        return final_state
    except Exception as e:
        print(f"\n❌ Error executing LangGraph: {e}")
        print("Please ensure you have run: pip install langgraph langchain-core langchain-community langchain-ollama")
        return None

if __name__ == "__main__":
    run_data_extraction_workflow("BoxPouch")
