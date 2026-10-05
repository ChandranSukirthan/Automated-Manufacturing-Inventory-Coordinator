from ai.schemas.tool_contracts import ProductionImpact, MaintenanceAssessment, checked_output
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
            connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on"
        )
        return conn
    except Exception:
        return None


def query_production_schedule(date_str: Optional[str] = None, machine_id: str = "M001", shift_id: Optional[str] = None, material_id: Optional[str] = None) -> Dict[str, Any]:
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

    # Existing shifts have no material/BOM association. Require explicit context
    # rather than silently using another product's newest shift.
    if not shift_id and not material_id and not settings.demo_mode:
        return {"available": False, "reason": "Select a shift and provide material-per-output conversion", "requiredMaterials": []}
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT "ProductionTarget", "AvailableMaterial", "MachineId", "MaterialPerUnit", "MaterialSku", "StartTime" FROM "Shifts" WHERE (%s::text IS NULL OR "Id"::text = %s) AND (%s::text IS NULL OR "MaterialSku" = %s) AND "EndTime" >= NOW() ORDER BY "StartTime", "Id" LIMIT 1', (shift_id, shift_id, material_id, material_id))
                row = cur.fetchone()
                if row:
                    planned_output = int(row[0])
                    return {
                        "productionDate": prod_date,
                        "plannedOutput": planned_output,
                        "requiredMaterial": None,
                        "availableMaterial": int(row[1]),
                        "machineId": str(row[2]) if row[2] else None,
                        "materialPerUnit": float(row[3]) if row[3] is not None else None,
                        "materialId": row[4],
                        "productionDate": str(row[5])
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


@checked_output(MaintenanceAssessment)
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
    import math
    if not math.isfinite(uptime) or not math.isfinite(maintenance_interval) or uptime < 0 or maintenance_interval <= 0:
        raise ValueError("Uptime must be nonnegative and maintenance interval positive and finite")
    remaining = float(maintenance_interval - uptime)
    maintenance_due = remaining <= 0.0

    return {
        "machineId": machine_id,
        "maintenanceDue": maintenance_due,
        "remainingHours": remaining
    }


@checked_output(ProductionImpact)
def calculate_production_impact(target: int, available_material: float, material_per_unit: float = 1.0) -> Dict[str, Any]:
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
    import math
    if not all(math.isfinite(float(v)) for v in (target, available_material, material_per_unit)) or target < 0 or available_material < 0 or material_per_unit <= 0:
        raise ValueError("Production quantities must be finite and nonnegative; material-per-unit must be positive")
    adjusted_output = min(target, math.floor(available_material / material_per_unit))
    return {
        "plannedOutput": target,
        "availableMaterial": available_material,
        "adjustedOutput": adjusted_output
    }

