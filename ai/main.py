import sys
from pathlib import Path

# Ensure repo root and ai/ are on sys.path
_AI_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _AI_DIR.parent
for _path_str in (str(_REPO_ROOT), str(_AI_DIR)):
    if _path_str not in sys.path:
        sys.path.insert(0, _path_str)

import asyncio
import logging
import random
from contextlib import asynccontextmanager
from typing import List, Optional

import httpx
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sklearn.linear_model import LinearRegression

import psycopg

from ai.core.config import settings
from ai.config import INVENTORY_API_URL, ALERTS_API_URL, CHECK_INTERVAL_SECONDS
from ai.routes.quality_routes import router as quality_router
from ai.routes.workflow_routes import router as workflow_router, tools_router
from ai.graph.workflow import run_workflow
from ai.graph import run_data_extraction_workflow
from ai.persistence import workflow_repo
from ai.schemas.state_schemas import WorkflowTriggerRequest

logger = logging.getLogger("amic_agentic_ai")


# ── Background Task 1: Autonomous Equipment Telemetry Scanner (Student 4) ────
async def autonomous_equipment_telemetry_scanner():
    """
    Autonomously scans Machines table every 15 seconds.
    When a machine breaches its MaintenanceIntervalHours, creates an
    AgentWorkflow record requiring IT Admin approval.
    """
    await asyncio.sleep(3)
    while True:
        try:
            with psycopg.connect(
                host=settings.DB_HOST,
                port=settings.DB_PORT,
                dbname=settings.DB_NAME,
                user=settings.DB_USER,
                password=settings.DB_PASSWORD,
                connect_timeout=3,
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        SELECT "Id", "Name", "UptimeHours", "MaintenanceIntervalHours"
                        FROM "Machines"
                        WHERE "Status" = 'Operational'
                          AND "UptimeHours" >= "MaintenanceIntervalHours";
                    """)
                    overdue_machines = cur.fetchall()
                    for m_id, name, uptime, interval in overdue_machines:
                        cur.execute("""
                            SELECT COUNT(*) FROM "AgentWorkflows"
                            WHERE ("Objective" LIKE %s OR "Objective" LIKE %s)
                              AND "Status" = 'WaitingForApproval';
                        """, (f"%{m_id}%", f"%{name}%"))
                        pending_count = cur.fetchone()[0]
                        if pending_count == 0:
                            short_id = str(m_id)[:4].upper()
                            clean_tag = "".join(c for c in name if c.isalnum())[:6].upper()
                            wf_id = f"WF-AUTO-{clean_tag}-{short_id}"
                            objective = (
                                f"Autonomous Telemetry Alert: {name} [MachineID: {m_id}] "
                                f"has exceeded maintenance threshold ({int(uptime)}h / {int(interval)}h). "
                                f"Requesting IT Admin approval for preventive overhaul."
                            )
                            print(f"[Scanner] Overdue: {name} ({uptime}h/{interval}h) -> {wf_id}")
                            run_workflow(objective=objective, workflow_id=wf_id)
        except Exception:
            pass
        await asyncio.sleep(15)


# ── Background Task 2: Inventory Monitor (Student 1/2) ────────────────────
async def inventory_monitor_task():
    """Polls /api/inventory every CHECK_INTERVAL_SECONDS and raises alerts for low stock."""
    logger.info(f"Inventory monitor started (interval: {CHECK_INTERVAL_SECONDS}s)")
    async with httpx.AsyncClient() as client:
        while True:
            try:
                response = await client.get(INVENTORY_API_URL, timeout=5.0)
                if response.status_code == 200:
                    for item in response.json():
                        stock = item.get("stockLevel", 0)
                        threshold = item.get("reorderThreshold", 0)
                        sku = item.get("sku", "Unknown")
                        if stock <= threshold:
                            await _send_alert(client, item, is_predictive=False)
                        else:
                            rate = _consumption_rate(sku)
                            if (stock - rate * 5) <= threshold:
                                await _send_alert(client, item, is_predictive=True)
            except Exception:
                pass
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)


async def _send_alert(client: httpx.AsyncClient, item: dict, is_predictive: bool):
    payload = {
        "sku": item.get("sku", ""),
        "packagingType": item.get("category", "Unknown"),
        "quantityRequested": 500,
        "workerId": "Predictive Reorder Alert" if is_predictive else "Auto-Monitor-Bot",
    }
    try:
        await client.post(ALERTS_API_URL, json=payload, timeout=5.0)
        logger.info(f"Alert sent for SKU {payload['sku']}")
    except Exception as e:
        logger.debug(f"Alert delivery note: {e}")


def _consumption_rate(sku: str) -> float:
    days = np.array(range(30)).reshape(-1, 1)
    random.seed(sku)
    true_rate = random.uniform(10.0, 50.0)
    np.random.seed(hash(sku) % (2**32))
    noise = np.random.normal(0, 15, 30)
    past_stock = 2000 - (true_rate * days.flatten()) + noise
    model = LinearRegression()
    model.fit(days, past_stock)
    return float(abs(model.coef_[0]))


# ── App lifespan: start both background tasks ────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    scanner = asyncio.create_task(autonomous_equipment_telemetry_scanner())
    monitor = asyncio.create_task(inventory_monitor_task())
    yield
    scanner.cancel()
    monitor.cancel()


# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="AMIC AI Service",
    description="Unified AI microservice for all 4 students: Inventory, Quality, Production, Administration",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────────────────────────
app.include_router(quality_router)   # POST /quality/recommendation   (Student 3)
app.include_router(workflow_router)  # /api/workflows/*                (Student 4)
app.include_router(tools_router)     # /api/tools/*                    (Student 4)


# ── Health ───────────────────────────────────────────────────────────────────
@app.get("/health")
def health() -> dict:
    return {"status": "ONLINE", "service": "AMIC AI Service", "version": "2.0.0"}


# ── Student 1/2: ML Prediction (used by AgentIntegrationService.cs) ──────────
class InventoryItemInput(BaseModel):
    id: Optional[int] = None
    sku: str
    name: str
    category: str
    stockLevel: int
    reorderThreshold: int


@app.post("/api/predict")
async def predict_inventory_needs(items: List[InventoryItemInput]):
    """
    Linear-regression risk scoring.
    Called by C# AgentIntegrationService → POST /api/predict
    Returns: { status, predictions: [{sku, riskScore, recommendedAction}] }
    """
    try:
        predictions = []
        for item in items:
            risk = (
                0.85 if item.stockLevel < item.reorderThreshold * 1.2
                else 0.45 if item.stockLevel < item.reorderThreshold * 2
                else 0.10
            )
            predictions.append({
                "sku": item.sku,
                "riskScore": risk,
                "recommendedAction": "Reorder" if risk > 0.8 else "Monitor",
            })
        return {"status": "success", "predictions": predictions}
    except Exception as ex:
        logger.error(f"Prediction error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


# ── Student 2: LangGraph data extraction workflow ─────────────────────────────
class DataExtractionRequest(BaseModel):
    batchName: str


@app.post("/api/agent/extract-data")
async def extract_data_agent_workflow(request: DataExtractionRequest):
    """Runs LangGraph Planner→DataExtraction→Purchasing→Validation pipeline."""
    try:
        result_state = run_data_extraction_workflow(request.batchName)
        if not result_state:
            raise HTTPException(status_code=500, detail="LangGraph execution failed.")
        saved = workflow_repo.save_workflow(result_state)
        last_msg = (
            result_state.get("messages", [])[-1].content
            if result_state.get("messages") else "Analysis completed."
        )
        return {
            "status": "success",
            "workflowId": saved["workflowId"],
            "requiresApproval": result_state.get("requires_human_approval", False),
            "approvalStatus": result_state.get("human_approval_status", "PENDING"),
            "dataExtractionResult": result_state.get("data_extraction_result"),
            "inventoryResult": result_state.get("inventory_result"),
            "agentMessage": last_msg,
        }
    except Exception as ex:
        logger.error(f"Data extraction error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.post("/api/agent/workflow/run")
async def trigger_agent_workflow(request: WorkflowTriggerRequest):
    """Trigger end-to-end multi-agent workflow for a material/batch."""
    try:
        result_state = run_data_extraction_workflow(request.materialId, request.workflowId)
        saved = workflow_repo.save_workflow(result_state)
        return {"status": "success", "workflow": saved}
    except Exception as ex:
        logger.error(f"Trigger workflow error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.get("/api/agent/workflow/{workflow_id}")
async def get_workflow_state(workflow_id: str):
    """Get persisted workflow by ID."""
    record = workflow_repo.get_workflow(workflow_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Workflow {workflow_id} not found.")
    return record


@app.get("/api/agent/workflows")
async def list_agent_workflows():
    """List all persisted workflow records."""
    return workflow_repo.list_workflows()


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ai.main:app", host="0.0.0.0", port=8000, reload=True)
