"""Validated output boundaries for deterministic, allow-listed tools."""
import logging
from functools import wraps
from time import perf_counter
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator


class ToolResult(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False, extra="allow")


class DraftPO(ToolResult):
    supplierId: str | int
    materialId: str = Field(min_length=1, max_length=100)
    quantity: float = Field(gt=0)
    unitPrice: float = Field(gt=0)
    totalAmount: float = Field(gt=0)
    currency: str = Field(pattern=r"^[A-Z]{3}$")
    status: Literal["Draft"]
    paymentStatus: Literal["UNPAID"]
    emailSent: Literal[False]

    @model_validator(mode="after")
    def validate_math(self):
        if not str(self.supplierId).strip() or abs(round(self.quantity * self.unitPrice, 2) - self.totalAmount) > 0.01:
            raise ValueError("Draft supplier and rounded PO total must be valid")
        return self


class ProductionImpact(ToolResult):
    plannedOutput: float = Field(ge=0)
    availableMaterial: float = Field(ge=0)
    adjustedOutput: float = Field(ge=0)


class MaintenanceAssessment(ToolResult):
    machineId: str = Field(min_length=1)
    maintenanceDue: bool
    remainingHours: float


class QuarantineRecommendation(ToolResult):
    batchId: str
    quarantineRequired: bool
    affectedInventory: list[str]
    riskLevel: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"]


def checked_output(schema):
    def decorate(function):
        @wraps(function)
        def invoke(*args, **kwargs):
            started = perf_counter()
            logger = logging.getLogger("amic_agentic_ai.tool_contracts")
            try:
                result = function(*args, **kwargs)
                # Validate without changing existing response field types/contracts.
                schema.model_validate(result)
                logger.info("tool=%s status=success durationMs=%.2f", function.__name__, (perf_counter() - started) * 1000)
                return result
            except Exception as error:
                logger.warning("tool=%s status=failed errorType=%s durationMs=%.2f", function.__name__, type(error).__name__, (perf_counter() - started) * 1000)
                raise
        return invoke
    return decorate
