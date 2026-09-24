import json

import pytest

from agents.data_extraction_agent import (
    query_production_db,
    run_data_extraction_agent,
    run_data_extraction_agent_json,
)


VALID_BOXPOUCH_REQUEST = {
    "product_type": "BoxPouch",
    "batch_id": "BP-2026-101",
    "material_sku": "BP-FILM-001",
}


def test_data_extraction_returns_json_with_both_required_tool_calls():
    result = run_data_extraction_agent(VALID_BOXPOUCH_REQUEST)

    assert result["status"] == "COMPLETED"
    assert result["past_burn_rate"]["average_quantity_per_hour"] == 250.0
    assert result["material_requirement"]["shortfall_quantity"] == 1020.0
    assert result["material_requirement"]["recommendation"] == "REPLENISHMENT_REQUIRED"
    assert {entry["tool_name"] for entry in result["tool_call_log"]} == {
        "query_production_db",
        "get_inventory_levels",
    }
    json_result = json.loads(run_data_extraction_agent_json(VALID_BOXPOUCH_REQUEST))
    assert json_result["status"] == "COMPLETED"
    assert json_result["request"] == VALID_BOXPOUCH_REQUEST


def test_data_extraction_rejects_invalid_input_without_calling_tools():
    result = run_data_extraction_agent(
        {
            "product_type": "Bag",
            "batch_id": "not-valid",
            "material_sku": "BP-FILM-001",
        }
    )

    assert result["status"] == "FAILED"
    assert result["tool_call_log"] == []
    assert result["errors"]


def test_production_tool_rejects_unsupported_product_type():
    with pytest.raises(Exception):
        query_production_db.invoke({"product_type": "Bag", "batch_id": "BG-2026-001"})
