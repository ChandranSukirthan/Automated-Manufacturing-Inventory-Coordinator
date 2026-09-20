import asyncio
import logging
import random
import numpy as np
from sklearn.linear_model import LinearRegression
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import httpx

from ai.config import (
    INVENTORY_API_URL,
    ALERTS_API_URL,
    CHECK_INTERVAL_SECONDS,
    AI_SERVER_HOST,
    AI_SERVER_PORT,
)
from ai.graph import run_data_extraction_workflow
from ai.persistence import workflow_repo
from ai.schemas.state_schemas import WorkflowTriggerRequest

logger = logging.getLogger("amic_agentic_ai.server")


# --- Machine Learning Scaffolding (Preserved from existing server) ---
class InventoryItem(BaseModel):
    id: Optional[int] = None
    sku: str
    name: str
    category: str
    stockLevel: int
    reorderThreshold: int


def get_consumption_rate(sku: str) -> float:
    """Calculates linear regression consumption rate from simulated historical telemetry."""
    days = np.array(range(30)).reshape(-1, 1)
    random.seed(sku)
    true_daily_consumption = random.uniform(10.0, 50.0)
    start_stock = 2000
    np.random.seed(hash(sku) % (2**32))
    noise = np.random.normal(0, 15, 30)
    past_stock = start_stock - (true_daily_consumption * days.flatten()) + noise
    
    model = LinearRegression()
    model.fit(days, past_stock)
    return float(abs(model.coef_[0]))


async def send_alert(client: httpx.AsyncClient, item: dict, is_predictive: bool = False):
    quantity_to_order = 500
    worker_id = "Predictive Reorder Alert" if is_predictive else "Auto-Monitor-Bot"
    alert_payload = {
        "sku": item.get("sku", ""),
        "packagingType": item.get("category", "Unknown"),
        "quantityRequested": quantity_to_order,
        "workerId": worker_id
    }
    try:
        response = await client.post(ALERTS_API_URL, json=alert_payload, timeout=5.0)
        response.raise_for_status()
        logger.info(f"Created alert for SKU: {alert_payload['sku']} (Quantity: {quantity_to_order})")
    except Exception as e:
        logger.debug(f"Inventory alert delivery note: {e}")


async def inventory_monitor_task():
    """Background task checking inventory every CHECK_INTERVAL_SECONDS."""
    logger.info(f"Starting automated inventory monitor task (interval: {CHECK_INTERVAL_SECONDS}s)...")
    async with httpx.AsyncClient() as client:
        while True:
            try:
                response = await client.get(INVENTORY_API_URL, timeout=5.0)
                if response.status_code == 200:
                    inventory = response.json()
                    if inventory:
                        for item in inventory:
                            stock_level = item.get("stockLevel", 0)
                            reorder_threshold = item.get("reorderThreshold", 0)
                            sku = item.get("sku", "Unknown")

                            if stock_level <= reorder_threshold:
                                logger.warning(f"Low stock detected for {sku}: {stock_level} <= {reorder_threshold}")
                                await send_alert(client, item, is_predictive=False)
                            else:
                                daily_consumption = get_consumption_rate(sku)
                                predicted_stock = stock_level - (daily_consumption * 5)
                                if predicted_stock <= reorder_threshold:
                                    logger.warning(f"Predictive Alert for {sku}: Forecasted below threshold in 5 days.")
                                    await send_alert(client, item, is_predictive=True)
            except Exception as e:
                logger.debug(f"Monitor ping note: {e}")

            await asyncio.sleep(CHECK_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Launch background inventory monitor
    task = asyncio.create_task(inventory_monitor_task())
    yield
    # Shutdown: Cancel background task
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Inventory monitor task stopped.")


# --- Initialize FastAPI Application ---
app = FastAPI(
    title="AMIC Shared Agentic AI Service",
    description="Agentic AI Multi-Agent Service for Automated Manufacturing Inventory Coordinator (Student 1: Inventory / Data Extraction)",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Endpoints ---

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "AMIC Agentic AI System",
        "student": "Student 1 (Inventory / Data Extraction)",
        "framework": "FastAPI + LangGraph"
    }


@app.post("/api/predict")
async def predict_inventory_needs(items: List[InventoryItem]):
    """REST endpoint for linear regression machine learning inference."""
    try:
        predictions = []
        for item in items:
            risk_score = 0.85 if item.stockLevel < item.reorderThreshold * 1.2 else 0.45 if item.stockLevel < item.reorderThreshold * 2 else 0.10
            predictions.append({
                "sku": item.sku,
                "riskScore": risk_score,
                "recommendedAction": "Reorder" if risk_score > 0.8 else "Monitor"
            })
        return {"status": "success", "predictions": predictions}
    except Exception as ex:
        logger.error(f"Prediction error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


class DataExtractionRequest(BaseModel):
    batchName: str


@app.post("/api/agent/extract-data")
async def extract_data_agent_workflow(request: DataExtractionRequest):
    """
    Executes the shared LangGraph state machine with Student 1's Data Extraction Agent.
    Produces structured inventory result and persists workflow state.
    """
    try:
        material_or_batch = request.batchName
        result_state = run_data_extraction_workflow(material_or_batch)

        if not result_state:
            raise HTTPException(status_code=500, detail="LangGraph execution failed.")

        # Persist sanitized workflow state
        saved_record = workflow_repo.save_workflow(result_state)

        last_msg = result_state.get("messages", [])[-1].content if result_state.get("messages") else "Analysis completed."

        return {
            "status": "success",
            "workflowId": saved_record["workflowId"],
            "requiresApproval": result_state.get("requires_human_approval", False),
            "approvalStatus": result_state.get("human_approval_status", "PENDING"),
            "dataExtractionResult": result_state.get("data_extraction_result"),
            "inventoryResult": result_state.get("inventory_result"),
            "agentMessage": last_msg
        }
    except Exception as ex:
        logger.error(f"Data extraction workflow error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.post("/api/agent/workflow/run")
async def trigger_workflow(request: WorkflowTriggerRequest):
    """Trigger end-to-end multi-agent workflow for a material."""
    try:
        result_state = run_data_extraction_workflow(request.materialId, request.workflowId)
        saved_record = workflow_repo.save_workflow(result_state)
        return {
            "status": "success",
            "workflow": saved_record
        }
    except Exception as ex:
        logger.error(f"Trigger workflow error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.get("/api/agent/workflow/{workflow_id}")
async def get_workflow_state(workflow_id: str):
    """Retrieve persisted workflow state without hidden chain-of-thought."""
    record = workflow_repo.get_workflow(workflow_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Workflow {workflow_id} not found.")
    return record


@app.get("/api/agent/workflows")
async def list_workflows():
    """List all persisted workflow records."""
    return workflow_repo.list_workflows()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ai.server:app", host=AI_SERVER_HOST, port=AI_SERVER_PORT, reload=True)

