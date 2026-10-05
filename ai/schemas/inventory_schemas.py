from pydantic import BaseModel, ConfigDict, Field, field_validator
from typing import Optional, Literal


class InventoryContract(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)


class InventoryLevelsInput(InventoryContract):
    materialId: str = Field(..., min_length=1, description="Material identifier or SKU code (e.g. 'RM001', 'RM-STEEL-001')")

    @field_validator("materialId")
    @classmethod
    def validate_material_id(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("materialId must not be empty or whitespace.")
        return cleaned


class InventoryLevelsOutput(InventoryContract):
    materialId: str = Field(..., description="Unique material identifier")
    currentStock: float = Field(..., ge=0, description="Current stock on hand")
    minimumStock: float = Field(..., ge=0, description="Minimum safety stock threshold")
    maximumStock: float = Field(..., ge=0, description="Maximum warehouse storage capacity")


class InventoryHistoryInput(InventoryContract):
    materialId: str = Field(..., min_length=1, description="Material identifier or SKU code")
    periodDays: int = Field(default=7, gt=0, le=365, description="Historical lookback window in days (default: 7)")

    @field_validator("materialId")
    @classmethod
    def validate_material_id(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("materialId must not be empty or whitespace.")
        return cleaned


class InventoryHistoryOutput(InventoryContract):
    materialId: str = Field(..., description="Material identifier")
    periodDays: int = Field(..., gt=0, description="Number of days in the consumption period")
    consumption: float = Field(..., ge=0, description="Total material consumed over the period")


class BurnRateInput(InventoryContract):
    consumption: float = Field(..., ge=0, description="Historical consumption quantity")
    periodDays: int = Field(..., description="Number of days over which consumption occurred")
    materialId: Optional[str] = Field(default=None, description="Material identifier")


class BurnRateOutput(InventoryContract):
    materialId: str = Field(..., description="Material identifier")
    burnRate: float = Field(..., ge=0, description="Average daily consumption burn rate")


class LowStockInput(InventoryContract):
    materialId: Optional[str] = Field(default=None, description="Material identifier")
    currentStock: float = Field(..., ge=0, description="Current stock level")
    minimumStock: float = Field(..., ge=0, description="Safety reorder threshold")
    burnRate: float = Field(..., ge=0, description="Daily consumption burn rate")
    daysRemaining: Optional[float] = Field(default=None, description="Calculated days of supply remaining")
    warningHorizonDays: float = Field(default=7.0, ge=0, le=365)
    supplierLeadTime: float = Field(default=0.0, ge=0, description="Supplier delivery lead time in days")


class LowStockOutput(InventoryContract):
    reason: str = ""
    zeroConsumption: bool = False
    materialId: str = Field(..., description="Material identifier")
    lowStock: bool = Field(..., description="Whether material is at or below safety replenishment threshold")
    daysRemaining: Optional[float] = Field(..., description="Estimated days before inventory exhaustion")
    severity: Literal["CRITICAL", "HIGH", "MEDIUM", "LOW", "NORMAL"] = Field(
        ..., description="Stockout risk severity classification"
    )


class DataExtractionResult(InventoryContract):
    """
    Final structured inventory analysis produced by the Data Extraction Agent.
    Strictly adheres to Student 1 specification:
    {
      "materialId": "RM001",
      "currentStock": 350,
      "burnRate": 80,
      "daysRemaining": 4.37,
      "lowStock": true,
      "requiredQuantity": 2000
    }
    """
    materialId: str = Field(..., description="Material SKU/identifier")
    currentStock: float = Field(..., description="Current warehouse stock")
    burnRate: float = Field(..., description="Daily burn rate")
    daysRemaining: Optional[float] = Field(..., description="Days of stock remaining before exhaustion")
    lowStock: bool = Field(..., description="Low stock replenishment trigger flag")
    requiredQuantity: float = Field(..., description="Recommended replenishment lot quantity")


class ToolErrorOutput(InventoryContract):
    materialId: str
    error: str
    safeFallback: bool = True

