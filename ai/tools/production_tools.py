from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
import psycopg
from langchain_core.tools import tool
from pydantic import BaseModel, Field, field_validator
from ai.core.config import settings


class ProductionScheduleInput(BaseModel):
    """Validated input for the allow-listed production schedule tool."""

    shiftName: str = Field(
        default="Next shift",
        min_length=1,
        max_length=80,
        description="The shift whose material requirements are requested.",
    )

    @field_validator("shiftName")
    @classmethod
    def validate_shift_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("shiftName must not be blank.")
        return cleaned


@tool(args_schema=ProductionScheduleInput)
def get_production_schedule(shiftName: str = "Next shift") -> Dict[str, Any]:
    """Return the approved dummy material plan for a factory shift.

    This deliberately has no database or ordering side effect.  It is an
    allow-listed read-only tool for the Data Extraction Agent to use when it
    checks whether low stock could affect the upcoming shift.
    """

    if not settings.demo_mode:
        return query_production_schedule()
    return {
        "shiftName": shiftName.strip(),
        "status": "Scheduled",
        "productionTarget": 10000,
        "requiredMaterials": [
            {"sku": "PAPER-A1", "name": "High Gloss Label Paper", "quantity": 500, "unit": "KG"},
            {"sku": "CR-001", "name": "BoxPouch film", "quantity": 300, "unit": "KG"},
            {"sku": "CAN-001", "name": "Can", "quantity": 250, "unit": "units"},
            {"sku": "BOTTLE-001", "name": "Bottle", "quantity": 400, "unit": "units"},
        ],
    }


# The workflow may bind only this explicit allow-list.  Keeping the tool list
# separate prevents an LLM from calling unapproved database or ordering code.
PRODUCTION_SCHEDULE_TOOLS: List[Any] = [get_production_schedule]


def get_db_connection():
    """Attempt to connect to PostgreSQL database, or return None if unreachable."""
    try:
        conn = psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=3
        )
        return conn
    except Exception:
        return None


def query_production_schedule(date_str: Optional[str] = None, machine_id: str = "M001") -> Dict[str, Any]:
    """
    Tool 1: Query planned production requirements and schedule.
    Returns:
    {
      "productionDate": "...",
      "machineId": "M001",
      "plannedOutput": 10000,
      "requiredMaterial": 2000
    }
    """
    prod_date = date_str or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Try reading from PostgreSQL Shifts table if available
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT "ProductionTarget", "AvailableMaterial" FROM "Shifts" ORDER BY "CreatedAt" DESC LIMIT 1')
                row = cur.fetchone()
                if row:
                    planned_output = int(row[0])
                    return {
                        "productionDate": prod_date,
                        "plannedOutput": planned_output,
                        "requiredMaterial": None,
                        "availableMaterial": int(row[1]),
                        "machineId": None
                    }
        except Exception:
            pass
        finally:
            conn.close()

    if not settings.demo_mode:
        return {"available": False, "reason": "No matching production schedule is available", "requiredMaterials": []}
    # Demo fixture
    return {
        "productionDate": prod_date,
        "machineId": machine_id,
        "plannedOutput": 10000,
        "requiredMaterial": 2000
    }


def calculate_machine_uptime(machine_id: str = "M001") -> Dict[str, Any]:
    """
    Tool 2: Calculate operational uptime hours for a machine.
    Returns:
    {
      "machineId": "M001",
      "uptimeHours": 480
    }
    """
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT "UptimeHours", "MaintenanceIntervalHours" FROM "Machines" WHERE "Id"::text = %s LIMIT 1', (machine_id,))
                row = cur.fetchone()
                if row:
                    return {
                        "machineId": machine_id,
                        "uptimeHours": float(row[0]), "maintenanceIntervalHours": float(row[1])
                    }
        except Exception:
            pass
        finally:
            conn.close()

    if not settings.demo_mode:
        return {"available": False, "machineId": machine_id, "reason": "No matching machine telemetry is available"}
    return {
        "machineId": machine_id,
        "uptimeHours": 480.0
    }


def check_maintenance_requirement(uptime: float, maintenance_interval: float, machine_id: str = "M001") -> Dict[str, Any]:
    """
    Tool 3: Compare uptime against maintenance interval to determine urgency.
    Input:
      uptime: current operating hours
      maintenance_interval: hours threshold for scheduled maintenance
    Returns:
    {
      "machineId": "M001",
      "maintenanceDue": bool,
      "remainingHours": float
    }
    """
    remaining = float(maintenance_interval - uptime)
    maintenance_due = remaining <= 0.0

    return {
        "machineId": machine_id,
        "maintenanceDue": maintenance_due,
        "remainingHours": remaining
    }


def calculate_production_impact(target: int, available_material: int) -> Dict[str, Any]:
    """
    Tool 4: Calculate production impact and adjusted output based on available inventory.
    Example: Target = 10000, Available material = 6000
    Returns:
    {
      "plannedOutput": 10000,
      "availableMaterial": 6000,
      "adjustedOutput": 6000
    }
    """
    adjusted_output = min(target, available_material)
    return {
        "plannedOutput": target,
        "availableMaterial": available_material,
        "adjustedOutput": adjusted_output
    }

