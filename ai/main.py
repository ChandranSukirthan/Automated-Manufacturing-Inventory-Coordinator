import sys
from pathlib import Path

# Ensure repo root and ai/ are on sys.path
_AI_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _AI_DIR.parent
for _path_str in (str(_REPO_ROOT), str(_AI_DIR)):
    if _path_str not in sys.path:
        sys.path.insert(0, _path_str)

import asyncio
import os
import logging
import random
import uuid
from contextlib import asynccontextmanager
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Depends, Header
from ai.security import require_actor
from ai.core.request_context import set_authorization_header, reset_authorization_header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    import numpy as np
    from sklearn.linear_model import LinearRegression
    HAS_ML = True
except ImportError:
    HAS_ML = False

import psycopg

from ai.core.config import settings
from ai.config import INVENTORY_API_URL, ALERTS_API_URL, CHECK_INTERVAL_SECONDS, BACKEND_HOST
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
                            WHERE "MachineId" = %s AND "WorkflowType" = 'Maintenance'
                              AND "Status" = 'WaitingForApproval';
                        """, (m_id,))
                        pending_count = cur.fetchone()[0]
                        if pending_count == 0:
                            short_id = str(m_id)[:4].upper()
                            clean_tag = "".join(c for c in name if c.isalnum())[:6].upper()
                            wf_id = f"WF-AUTO-{uuid.uuid4().hex[:24].upper()}"
                            objective = (
                                f"Autonomous Telemetry Alert: {name} [MachineID: {m_id}] "
                                f"has exceeded maintenance threshold ({int(uptime)}h / {int(interval)}h). "
                                f"Requesting IT Admin approval for preventive overhaul."
                            )
                            print(f"[Scanner] Overdue: {name} ({uptime}h/{interval}h) -> {wf_id}")
                            await asyncio.to_thread(run_workflow, objective=objective, workflow_id=wf_id,
                                                    workflow_type="Maintenance", machine_id=str(m_id))
        except Exception:
            pass
        await asyncio.sleep(15)


# ── Background Task 2: Inventory Monitor (Student 1/2) ────────────────────
_active_alerted_skus = set()

async def inventory_monitor_task():
    """Polls /api/inventory every CHECK_INTERVAL_SECONDS and raises alerts for low stock."""
    """Polls /api/inventory every CHECK_INTERVAL_SECONDS and raises alerts for low stock without spamming duplicates."""
    logger.info(f"Inventory monitor started (interval: {CHECK_INTERVAL_SECONDS}s)")
    async with httpx.AsyncClient() as client:
        while True:
            try:
                token = os.environ.get("AMIC_MONITOR_TOKEN")
                if not token:
                    await asyncio.sleep(CHECK_INTERVAL_SECONDS)
                    continue
                response = await client.get(INVENTORY_API_URL, timeout=5.0, headers={"Authorization": f"Bearer {token}"})
                if response.status_code == 200:
                    for item in response.json():
                        stock = item.get("stockLevel", 0)
                        threshold = item.get("reorderThreshold", 0)
                        sku = item.get("sku", "Unknown")
                        if stock <= threshold:
                            if sku not in _active_alerted_skus:
                                if await _send_alert(client, item, is_predictive=False):
                                    _active_alerted_skus.add(sku)
                        else:
                            if sku in _active_alerted_skus:
                                _active_alerted_skus.discard(sku)
                            rate = 0.0  # Historical burn-rate analysis is performed by authenticated inventory tools.
                            if (stock - rate * 5) <= threshold:
                                if sku not in _active_alerted_skus:
                                    if await _send_alert(client, item, is_predictive=True):
                                        _active_alerted_skus.add(sku)
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
        response = await client.post(ALERTS_API_URL, json=payload, timeout=5.0,
            headers={"Authorization": f"Bearer {os.environ.get('AMIC_MONITOR_TOKEN', '')}"})
        response.raise_for_status()
        alert = response.json()
        alert_id = alert.get("id") or alert.get("alertId")
        if alert_id is None:
            raise ValueError("Low-stock alert returned no persistent identifier")
        trigger = await client.post(f"{BACKEND_HOST}/api/inventory/trigger-replenishment", json={
            "materialId": payload["sku"], "requiredQuantity": payload["quantityRequested"],
            "triggerType": "AutoLowStock", "workflowId": f"WF-AUTO-STOCK-{alert_id}",
            "objective": f"Automatic low-stock replenishment for {payload['sku']}"}, timeout=10.0,
            headers={"Authorization": f"Bearer {os.environ.get('AMIC_MONITOR_TOKEN', '')}"})
        trigger.raise_for_status()
        logger.info(f"Low-stock workflow queued for SKU {payload['sku']}")
        return True
    except Exception as e:
        logger.warning(f"Low-stock workflow delivery failed: {e}")
        return False


def _consumption_rate(sku: str) -> float:
    if not HAS_ML:
        random.seed(sku)
        return float(random.uniform(15.0, 45.0))
    days = np.array(range(30)).reshape(-1, 1)
    random.seed(sku)
    true_rate = random.uniform(10.0, 50.0)
    np.random.seed(hash(sku) % (2**32))
    noise = np.random.normal(0, 15, 30)
    past_stock = 2000 - (true_rate * days.flatten()) + noise
    model = LinearRegression()
    model.fit(days, past_stock)
    return float(abs(model.coef_[0]))


def init_db_tables():
    """
    Ensures required database tables exist in PostgreSQL upon AI service startup.
    Creates AgentWorkflows and ProcurementOutcomes if they don't already exist.
    """
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
                    CREATE TABLE IF NOT EXISTS "AgentWorkflows" (
                        "Id" uuid NOT NULL PRIMARY KEY,
                        "WorkflowId" character varying(50) NOT NULL,
                        "Objective" character varying(500) NOT NULL,
                        "CurrentAgent" character varying(200) NOT NULL,
                        "Status" text NOT NULL,
                        "ApprovalStatus" text NOT NULL,
                        "StartedAt" timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
                        "CompletedAt" timestamp with time zone NULL,
                        "FinalOutcome" character varying(1000) NULL
                    );
                    CREATE UNIQUE INDEX IF NOT EXISTS "IX_AgentWorkflows_WorkflowId" ON "AgentWorkflows" ("WorkflowId");

                    CREATE TABLE IF NOT EXISTS "ProcurementOutcomes" (
                        "Id" serial PRIMARY KEY,
                        "Material" character varying(200),
                        "RequestedQuantity" double precision,
                        "RecommendedQuantity" double precision,
                        "FinalOrderedQuantity" double precision,
                        "RecommendedSupplier" character varying(200),
                        "SelectedSupplier" character varying(200),
                        "EstimatedPrice" double precision,
                        "FinalPrice" double precision,
                        "EstimatedLeadTime" integer,
                        "ActualLeadTime" integer,
                        "QualityEvidence" text,
                        "SupplierVerification" character varying(100),
                        "ManagerDecision" character varying(100),
                        "ManagerRevision" text,
                        "ProcurementSuccess" boolean,
                        "PaymentSuccess" boolean,
                        "DeliverySuccess" boolean,
                        "CreatedAt" timestamp with time zone DEFAULT timezone('utc', now())
                    );
                """)
            conn.commit()
            logger.info("AgentWorkflows and ProcurementOutcomes DB tables verified/initialized.")
    except Exception as ex:
        logger.debug(f"DB table init note: {ex}")


# ── App lifespan: start both background tasks ────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # The backend migrations own the shared PostgreSQL schema.
    from ai.graph.workflow import WORKFLOW_SESSIONS, sync_to_database
    for workflow_id in list(WORKFLOW_SESSIONS):
        state = WORKFLOW_SESSIONS[workflow_id]
        if state.get("status") == "Running":
            from ai.graph.workflow import _workflow_lock
            try:
                with _workflow_lock(workflow_id, blocking=False):
                    state.update(status="Failed", current_agent="Interrupted",
                                 errors=["Service restarted during execution. Retry to resume with fresh authorization."])
                    WORKFLOW_SESSIONS[workflow_id] = state
                    sync_to_database(state)
            except BlockingIOError:
                logger.info("Workflow %s is active in another AI worker; leaving it running", workflow_id)
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
    allow_origins=[],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────────────────────────
app.include_router(quality_router)   # POST /quality/recommendation   (Student 3)
app.include_router(workflow_router)  # /api/workflows/*                (Student 4)
app.include_router(tools_router)     # /api/tools/*                    (Student 4)


from typing import Optional, List, Union
from pydantic import BaseModel, ConfigDict


class PredictInventoryItem(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: Optional[int] = None
    sku: str = ""
    name: Optional[str] = ""
    category: Optional[str] = ""
    stockLevel: int = 0
    reorderThreshold: int = 0


class PredictionItem(BaseModel):
    sku: str
    riskScore: float
    recommendedAction: str


class PredictResponse(BaseModel):
    status: str = "Success"
    predictions: List[PredictionItem]


# ── Health ───────────────────────────────────────────────────────────────────
@app.get("/health")
def health() -> dict:
    return {"status": "ONLINE", "service": "AMIC AI Service", "version": "2.0.0"}


# ── Student 1/2: ML Prediction (used by AgentIntegrationService.cs & UI) ─────
@app.post("/api/predict", response_model=PredictResponse, dependencies=[Depends(require_actor)])
@app.post("/predict", response_model=PredictResponse, dependencies=[Depends(require_actor)])
def predict_stock_risk(items: Union[List[PredictInventoryItem], PredictInventoryItem]) -> PredictResponse:
    item_list = [items] if isinstance(items, PredictInventoryItem) else items
    predictions = []
    for item in item_list:
        stock = item.stockLevel
        threshold = item.reorderThreshold
        if stock <= threshold:
            deficit = max(0, threshold - stock)
            risk = round(min(1.0, 0.6 + (deficit / (threshold + 1)) * 0.4), 2)
            action = "Reorder"
        else:
            surplus = stock - threshold
            risk = round(max(0.05, 0.3 - (surplus / (threshold + 1)) * 0.25), 2)
            action = "Maintain"
        predictions.append(PredictionItem(sku=item.sku, riskScore=risk, recommendedAction=action))
    return PredictResponse(status="Success", predictions=predictions)


# ── Student 2: LangGraph data extraction workflow ─────────────────────────────
class DataExtractionRequest(BaseModel):
    batchName: str


@app.post("/api/agent/extract-data", dependencies=[Depends(require_actor)])
async def extract_data_agent_workflow(request: DataExtractionRequest, authorization: Optional[str] = Header(default=None)):
    """Runs LangGraph Planner→DataExtraction→Purchasing→Validation pipeline."""
    try:
        from ai.core.request_context import set_authorization_header, reset_authorization_header
        token = set_authorization_header(authorization)
        try:
            result_state = await asyncio.to_thread(run_data_extraction_workflow, request.batchName)
        finally:
            reset_authorization_header(token)
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


@app.post("/api/agent/workflow/run", dependencies=[Depends(require_actor)])
async def trigger_agent_workflow(request: WorkflowTriggerRequest, authorization: Optional[str] = Header(default=None)):
    """Trigger end-to-end multi-agent workflow for a material/batch."""
    try:
        token = set_authorization_header(authorization)
        try:
            result_state = await asyncio.to_thread(run_data_extraction_workflow, request.materialId, request.workflowId)
        finally:
            reset_authorization_header(token)
        saved = workflow_repo.save_workflow(result_state)
        return {"status": "success", "workflow": saved}
    except Exception as ex:
        logger.error(f"Trigger workflow error: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.get("/api/agent/workflow/{workflow_id}", dependencies=[Depends(require_actor)])
async def get_workflow_state(workflow_id: str):
    """Get persisted workflow by ID."""
    record = workflow_repo.get_workflow(workflow_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Workflow {workflow_id} not found.")
    return record


@app.get("/api/agent/workflows", dependencies=[Depends(require_actor)])
async def list_agent_workflows():
    """List all persisted workflow records."""
    return workflow_repo.list_workflows()


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ai.main:app", host="0.0.0.0", port=8000, reload=True)
