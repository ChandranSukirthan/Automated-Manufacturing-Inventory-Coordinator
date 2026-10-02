"""Backward-compatible imports for the Data Extraction Agent.

Use ``agents.data_extraction_agent`` for new code. This module remains so
existing commands that import ``data_extraction_agent`` continue to work.
"""

from agents.data_extraction_agent import (
    ALLOWED_TOOLS,
    DATA_EXTRACTION_GRAPH,
    DATA_EXTRACTION_PROMPT,
    get_inventory_levels,
    query_production_db,
    run_data_extraction_agent,
    run_data_extraction_agent_json,
)

__all__ = [
    "ALLOWED_TOOLS",
    "DATA_EXTRACTION_GRAPH",
    "DATA_EXTRACTION_PROMPT",
    "get_inventory_levels",
    "query_production_db",
    "run_data_extraction_agent",
    "run_data_extraction_agent_json",
]


if __name__ == "__main__":
    print(
        run_data_extraction_agent_json(
            {
                "product_type": "BoxPouch",
                "batch_id": "BP-2026-101",
                "material_sku": "BP-FILM-001",
            }
        )
    )
