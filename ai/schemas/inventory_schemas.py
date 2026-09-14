from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal


class InventoryLevelsInput(BaseModel):
    materialId: str = Field(..., min_length=1, description="Material identifier or SKU code (e.g. 'RM001', 'RM-STEEL-001')")

    @field_validator("materialId")
    @classmethod
    def validate_material_id(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("materialId must not be empty or whitespace.")
        return cleaned


class InventoryLevelsOutput(BaseModel):
    materialId: str = Field(..., description="Unique material identifier")
    currentStock: float = Field(..., ge=0, description="Current stock on hand")
    minimumStock: float = Field(..., ge=0, description="Minimum safety stock threshold")
    maximumStock: float = Field(..., ge=0, description="Maximum warehouse storage capacity")


class InventoryHistoryInput(BaseModel):
    materialId: str = Field(..., min_length=1, description="Material identifier or SKU code")
    periodDays: int = Field(default=7, gt=0, le=365, description="Historical lookback window in days (default: 7)")

    @field_validator("materialId")
    @classmethod
    def validate_material_id(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("materialId must not be empty or whitespace.")
        return cleaned


class InventoryHistoryOutput(BaseModel):
    materialId: str = Field(..., description="Material identifier")
    periodDays: int = Field(..., gt=0, description="Number of days in the consumption period")
    consumption: float = Field(..., ge=0, description="Total material consumed over the period")


class BurnRateInput(BaseModel):
    consumption: float = Field(..., ge=0, description="Historical consumption quantity")
    periodDays: int = Field(..., description="Number of days over which consumption occurred")
    materialId: Optional[str] = Field(default="RM001", description="Material identifier")


class BurnRateOutput(BaseModel):
    materialId: str = Field(..., description="Material identifier")
    burnRate: float = Field(..., ge=0, description="Average daily consumption burn rate")


class LowStockInput(BaseModel):
    materialId: Optional[str] = Field(default="RM001", description="Material identifier")
    currentStock: float = Field(..., ge=0, description="Current stock level")
    minimumStock: float = Field(..., ge=0, description="Safety reorder threshold")
    burnRate: float = Field(..., ge=0, description="Daily consumption burn rate")
    daysRemaining: Optional[float] = Field(default=None, description="Calculated days of supply remaining")
    supplierLeadTime: float = Field(default=3.0, ge=0, description="Supplier delivery lead time in days")


class LowStockOutput(BaseModel):
    materialId: str = Field(..., description="Material identifier")
    lowStock: bool = Field(..., description="Whether material is at or below safety replenishment threshold")
    daysRemaining: float = Field(..., description="Estimated days before inventory exhaustion")
    severity: Literal["CRITICAL", "HIGH", "MEDIUM", "LOW", "NORMAL"] = Field(
        ..., description="Stockout risk severity classification"
    )


class DataExtractionResult(BaseModel):
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
    daysRemaining: float = Field(..., description="Days of stock remaining before exhaustion")
    lowStock: bool = Field(..., description="Low stock replenishment trigger flag")
    requiredQuantity: float = Field(..., description="Recommended replenishment lot quantity")


class ToolErrorOutput(BaseModel):
    materialId: str
    error: str
    safeFallback: bool = True
