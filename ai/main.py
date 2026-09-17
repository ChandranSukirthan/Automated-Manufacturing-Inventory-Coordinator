import asyncio
from contextlib import asynccontextmanager
from typing import cast
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import psycopg

from core.config import settings
from routes.workflow_routes import router as workflow_router, tools_router
from graph.workflow import run_workflow


async def autonomous_equipment_telemetry_scanner():
    """
    Continuous Autonomous Telemetry Scanner:
    Autonomously scans the factory floor database. Whenever any machine breaches
    its maintenance threshold, the AI autonomously initiates an overhaul workflow
    and requests IT Admin human approval without requiring human prompting.
    """
    # Wait 3 seconds on initial startup
    await asyncio.sleep(3)
    
    while True:
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
                    # Find operational machines that have breached maintenance interval
                    cur.execute("""
                        SELECT "Id", "Name", "UptimeHours", "MaintenanceIntervalHours"
                        FROM "Machines"
                        WHERE "Status" = 'Operational' AND "UptimeHours" >= "MaintenanceIntervalHours";
                    """)
                    overdue_machines = cur.fetchall()

                    for m_id, name, uptime, interval in overdue_machines:
                        # Check if a pending workflow already exists for this machine by ID or name
                        cur.execute("""
                            SELECT COUNT(*) FROM "AgentWorkflows"
                            WHERE ("Objective" LIKE %s OR "Objective" LIKE %s) AND "Status" = 'WaitingForApproval';
                        """, (f"%{m_id}%", f"%{name}%"))
                        pending_result = cur.fetchone()
                        pending_count = cast(int, pending_result[0]) if pending_result is not None else 0

                        if pending_count == 0:
                            short_id = str(m_id)[:4].upper()
                            clean_tag = "".join(c for c in name if c.isalnum())[:6].upper()
                            wf_id = f"WF-AUTO-{clean_tag}-{short_id}"
                            objective = (
                                f"Autonomous Telemetry Alert: {name} [MachineID: {m_id}] has exceeded maintenance threshold "
                                f"({int(uptime)}h / {int(interval)}h). Requesting IT Admin approval for preventive overhaul."
                            )
                            print(f"[Autonomous AI Scanner] Overdue machine detected: {name} (ID: {m_id}, {uptime}h / {interval}h). Dispatching workflow {wf_id}...")
                            run_workflow(objective=objective, workflow_id=wf_id)
        except Exception:
            pass

        await asyncio.sleep(10)  # Continuous background scan every 10 seconds


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start autonomous scanner in the background
    scanner_task = asyncio.create_task(autonomous_equipment_telemetry_scanner())
    yield
    scanner_task.cancel()


app = FastAPI(
    title="AMIC Production AI Service",
    description="Planner/Coordinator Agent for Production Scheduling & Equipment",
    version="1.0.0",
    lifespan=lifespan
)

# CORS — allow ASP.NET backend and React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5070",
        "https://localhost:7148",
        "http://localhost:5173",
        "*"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(workflow_router)
app.include_router(tools_router)


@app.get("/health")
async def health_check():
    """Health check endpoint used by the ASP.NET backend to verify service status."""
    return {
        "status": "ONLINE",
        "service": "FastAPI Production AI",
        "version": "1.0.0",
        "autonomous_scanner": "ACTIVE"
    }


@app.get("/")
async def root() -> dict[str, object]:
    return {
        "message": "AMIC Production AI Service is running with Autonomous Telemetry Monitoring.",
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "workflows": "/api/workflows",
            "tools": "/api/tools"
        }
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.FASTAPI_HOST,
        port=settings.FASTAPI_PORT,
        reload=True,
    )
