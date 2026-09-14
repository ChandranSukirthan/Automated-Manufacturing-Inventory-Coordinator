from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from .inventory_schemas import DataExtractionResult, LowStockOutput


class WorkflowTriggerRequest(BaseModel):
    materialId: str = Field(default="RM001", description="Target material to evaluate")
    batchName: Optional[str] = Field(default=None, description="Optional manufacturing batch reference")
    workflowId: Optional[str] = Field(default=None, description="Optional correlation workflow ID")


class WorkflowSummary(BaseModel):
    workflowId: str
    materialId: str
    currentAgent: str
    status: str
    startedAt: str
    completedAt: Optional[str] = None
    requiresApproval: bool = False
    approvalStatus: str = "PENDING"
    inventoryResult: Optional[DataExtractionResult] = None
    lowStockResult: Optional[LowStockOutput] = None
    toolExecutionSummary: List[Dict[str, Any]] = Field(default_factory=list)
    errors: List[str] = Field(default_factory=list)
