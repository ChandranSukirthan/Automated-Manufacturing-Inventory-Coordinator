import sys
from pathlib import Path

# Automatically ensure repository root and ai directory are in sys.path
_AI_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _AI_DIR.parent
for _path_str in (str(_REPO_ROOT), str(_AI_DIR)):
    if _path_str not in sys.path:
        sys.path.insert(0, _path_str)

import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psycopg

from ai.core.config import settings
from ai.routes.quality_routes import router as quality_router
from ai.routes.workflow_routes import router as workflow_router, tools_router
from ai.graph.workflow import run_workflow


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
                        pending_count = cur.fetchone()[0]

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
            # Gracefully wait and retry if DB not ready
            pass

        # Scan every 15 seconds
        await asyncio.sleep(15)


@asynccontextmanager
async def lifespan(app: FastAPI):
    scanner_task = asyncio.create_task(autonomous_equipment_telemetry_scanner())
    yield
    scanner_task.cancel()


app = FastAPI(title="AMIC AI Service", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5070",
        "https://localhost:7148",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:5174",
        "http://127.0.0.1:5174",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)
app.include_router(quality_router)
app.include_router(workflow_router)
app.include_router(tools_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ONLINE"}
