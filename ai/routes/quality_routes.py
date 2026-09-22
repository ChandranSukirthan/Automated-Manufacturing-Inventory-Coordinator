from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from psycopg import OperationalError

from ai.agents.quality_agent import run_quality_validation
from ai.core.state import AgentState


router = APIRouter(prefix="/quality", tags=["quality"])


class DefectInput(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    batch_id: str | None = Field(None, alias="batchId")
    sku_code: str | None = Field(None, alias="skuCode")
    product_type: str = Field(alias="productType")
    severity: str
    description: str
    affected_inventory: list[str] = Field(default_factory=list, alias="affectedInventory")


@router.post("/recommendation")
def quality_recommendation(defect: DefectInput) -> dict:
    state: AgentState = {
        "quality_data": {"defect": defect.model_dump(by_alias=True)},
        "tool_results": {},
    }
    try:
        result = run_quality_validation(state)
    except (ValueError, ConnectionError, OperationalError) as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return result["quality_data"]["validation"]
