"""
AMIC Shared Agentic AI Server
Unified FastAPI Application for Automated Manufacturing Inventory Coordinator
Integrates Student 1's Inventory / Data Extraction Agent & Multi-Agent LangGraph Workflow.
"""
from ai.server import app, lifespan, predict_inventory_needs, extract_data_agent_workflow
from ai.config import AI_SERVER_HOST, AI_SERVER_PORT

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("agent_server:app", host=AI_SERVER_HOST, port=AI_SERVER_PORT, reload=True)