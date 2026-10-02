"""Controlled LangGraph data-extraction agent for material replenishment.

The agent has exactly two allow-listed, read-only tools. It runs without an
external model so the assessed workflow remains demonstrable offline. A
tool-capable chat model can be injected later; invalid tool selections are
rejected before a tool is called.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, Annotated, Literal, Mapping, TypedDict

from langchain_core.messages import AIMessage, BaseMessage, ToolMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.tools import tool
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode
from pydantic import BaseModel, Field, ValidationError


SupportedProduct = Literal["BoxPouch", "TeaBag", "Can", "Bottle"]


class DataExtractionRequest(BaseModel):
    """Validated plan data accepted by the Data Extraction Agent."""

    product_type: SupportedProduct
    batch_id: str = Field(
        ..., min_length=3, max_length=40, pattern=r"^[A-Z0-9][A-Z0-9-]*$"
    )
    material_sku: str = Field(
        ...,
        min_length=5,
        max_length=40,
        pattern=r"^[A-Z]{2,10}-[A-Z0-9]{2,20}(?:-[A-Z0-9]{1,10})?$",
    )


class ProductionDatabaseQuery(BaseModel):
    """Input contract for the production-history and schedule tool."""

    product_type: SupportedProduct
    batch_id: str = Field(
        ..., min_length=3, max_length=40, pattern=r"^[A-Z0-9][A-Z0-9-]*$"
    )


class InventoryLevelsQuery(BaseModel):
    """Input contract for the read-only inventory tool."""

    material_sku: str = Field(
        ...,
        min_length=5,
        max_length=40,
        pattern=r"^[A-Z]{2,10}-[A-Z0-9]{2,20}(?:-[A-Z0-9]{1,10})?$",
    )


# Kept out of returned/persisted state: audit records contain only tool inputs,
# outputs, outcomes, and errors - not raw prompts or hidden reasoning.
DATA_EXTRACTION_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "You are the Data Extraction Agent for an automated manufacturing "
            "inventory coordinator. Collect evidence for the flagged production "
            "batch only. Call query_production_db to read historical material "
            "consumption and upcoming schedules, then call get_inventory_levels "
            "to read current stock. Use no other tools. Do not create orders or "
            "write data. Return only structured JSON facts. If a tool result is "
            "invalid or unavailable, report a safe failure.",
        ),
        (
            "human",
            "Research {product_type} batch {batch_id} using raw material "
            "{material_sku}.",
        ),
    ]
)


# Temporary read-only mock records. Replace these with parameterised database
# queries when the ASP.NET Core API exposes production history and schedules.
_PRODUCT_MOCKS: dict[str, dict[str, Any]] = {
    "BoxPouch": {
        "sku": "BP-FILM-001",
        "unit": "meters",
        "inventory": (4800.0, 300.0, 3000.0),
        "history": [("BP-2026-091", 2500.0, 10.0), ("BP-2026-092", 2750.0, 11.0)],
        "schedule": [("BP-2026-101", 5000, 2400.0), ("BP-2026-102", 6500, 3120.0)],
    },
    "TeaBag": {
        "sku": "TB-PAPER-001",
        "unit": "meters",
        "inventory": (1900.0, 100.0, 1000.0),
        "history": [("TB-2026-041", 1200.0, 8.0), ("TB-2026-042", 1350.0, 9.0)],
        "schedule": [("TB-2026-051", 7000, 1050.0)],
    },
    "Can": {
        "sku": "CAN-ALLOY-001",
        "unit": "sheets",
        "inventory": (2100.0, 50.0, 1800.0),
        "history": [("CAN-2026-031", 1800.0, 12.0), ("CAN-2026-032", 1950.0, 13.0)],
        "schedule": [("CAN-2026-041", 9000, 2250.0)],
    },
    "Bottle": {
        "sku": "BOT-RESIN-001",
        "unit": "kg",
        "inventory": (1900.0, 150.0, 1400.0),
        "history": [("BOT-2026-061", 1600.0, 10.0), ("BOT-2026-062", 1760.0, 11.0)],
        "schedule": [("BOT-2026-071", 8000, 2000.0)],
    },
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@tool("query_production_db", args_schema=ProductionDatabaseQuery)
def query_production_db(product_type: str, batch_id: str) -> dict[str, Any]:
    """Read historical material consumption and upcoming production schedules."""

    # Validate again inside the implementation: future direct calls cannot
    # bypass the input contract supplied by the LangChain tool wrapper.
    query = ProductionDatabaseQuery.model_validate(
        {"product_type": product_type, "batch_id": batch_id}
    )
    mock = _PRODUCT_MOCKS[query.product_type]
    sku = mock["sku"]
    return {
        "status": "OK",
        "source": "mock_production_database",
        "query": query.model_dump(),
        "historical_material_consumption": [
            {
                "batch_id": completed_batch,
                "material_sku": sku,
                "quantity_consumed": consumed,
                "run_hours": hours,
            }
            for completed_batch, consumed, hours in mock["history"]
        ],
        "upcoming_production_schedule": [
            {
                "batch_id": scheduled_batch,
                "planned_output_units": output_units,
                "material_required_quantity": material_required,
                "material_sku": sku,
            }
            for scheduled_batch, output_units, material_required in mock["schedule"]
        ],
        "queried_at": _utc_now(),
    }


@tool("get_inventory_levels", args_schema=InventoryLevelsQuery)
def get_inventory_levels(material_sku: str) -> dict[str, Any]:
    """Read current, reserved, and reorder quantities for one material."""

    query = InventoryLevelsQuery.model_validate({"material_sku": material_sku})
    matching = next(
        (mock for mock in _PRODUCT_MOCKS.values() if mock["sku"] == query.material_sku),
        None,
    )
    if matching is None:
        return {
            "status": "NOT_FOUND",
            "source": "mock_inventory_database",
            "material_sku": query.material_sku,
            "error": "No inventory record exists for this material SKU.",
            "queried_at": _utc_now(),
        }

    available, reserved, threshold = matching["inventory"]
    return {
        "status": "OK",
        "source": "mock_inventory_database",
        "material_sku": query.material_sku,
        "available_quantity": available,
        "reserved_quantity": reserved,
        "allocatable_quantity": available - reserved,
        "reorder_threshold": threshold,
        "unit": matching["unit"],
        "queried_at": _utc_now(),
    }


ALLOWED_TOOLS = [query_production_db, get_inventory_levels]


class DataExtractionState(TypedDict, total=False):
    """Transient state for this subgraph; only ``extraction_result`` is saved."""

    request: dict[str, Any]
    messages: Annotated[list[BaseMessage], add_messages]
    errors: list[str]
    extraction_result: dict[str, Any]


def build_prompt_messages(request: DataExtractionRequest) -> list[BaseMessage]:
    """Render the role prompt without persisting it as workflow audit data."""

    return DATA_EXTRACTION_PROMPT.format_messages(**request.model_dump())


def _required_tool_calls(request: DataExtractionRequest) -> AIMessage:
    """Offline policy which guarantees both approved read-only tools are used."""

    return AIMessage(
        content="Collecting validated production and inventory evidence.",
        tool_calls=[
            {
                "name": "query_production_db",
                "args": {
                    "product_type": request.product_type,
                    "batch_id": request.batch_id,
                },
                "id": "call-production-db",
            },
            {
                "name": "get_inventory_levels",
                "args": {"material_sku": request.material_sku},
                "id": "call-inventory-levels",
            },
        ],
    )


def _validate_model_tool_calls(
    tool_calls: list[dict[str, Any]], request: DataExtractionRequest
) -> None:
    """Reject model output that requests an unapproved or altered action."""

    expected_args = {
        "query_production_db": {
            "product_type": request.product_type,
            "batch_id": request.batch_id,
        },
        "get_inventory_levels": {"material_sku": request.material_sku},
    }
    actual = {call.get("name"): call.get("args") for call in tool_calls}
    if len(tool_calls) != 2 or set(actual) != set(expected_args):
        raise ValueError("Agent must call exactly the two allow-listed data tools.")
    if any(actual[name] != expected for name, expected in expected_args.items()):
        raise ValueError("Agent tool arguments did not match the validated request.")


def _prepare_tool_calls(state: DataExtractionState, llm: Any | None) -> dict[str, Any]:
    try:
        raw_request = state.get("request", {})
        if not isinstance(raw_request, Mapping):
            raise ValueError("The data-extraction request must be a JSON object.")
        request = DataExtractionRequest.model_validate(dict(raw_request))
        prompt_messages = build_prompt_messages(request)
        if llm is None:
            response = _required_tool_calls(request)
        else:
            response = llm.bind_tools(ALLOWED_TOOLS).invoke(prompt_messages)
            if not isinstance(response, AIMessage):
                raise ValueError("The configured model did not return an AI message.")
            _validate_model_tool_calls(response.tool_calls, request)
        return {"request": request.model_dump(), "messages": [response], "errors": []}
    except (ValidationError, ValueError, TypeError) as error:
        return {"errors": [f"Data-extraction input rejected: {error}"]}
    except Exception as error:
        # Do not leak stack traces, credentials, or provider diagnostics.
        return {"errors": [f"Data-extraction agent unavailable: {type(error).__name__}"]}


def _route_after_agent(state: DataExtractionState) -> str:
    return "safe_failure" if state.get("errors") else "tools"


def _tool_payloads(
    messages: list[BaseMessage],
) -> tuple[dict[str, Any], dict[str, Any], list[dict[str, str]]]:
    production: dict[str, Any] | None = None
    inventory: dict[str, Any] | None = None
    tool_log: list[dict[str, str]] = []
    for message in messages:
        if not isinstance(message, ToolMessage):
            continue
        try:
            payload = json.loads(str(message.content))
        except json.JSONDecodeError as error:
            raise ValueError(f"{message.name} returned invalid JSON: {error.msg}") from error
        tool_log.append(
            {
                "tool_name": message.name,
                "call_id": message.tool_call_id,
                "status": str(payload.get("status", "ERROR")),
            }
        )
        if message.name == "query_production_db":
            production = payload
        elif message.name == "get_inventory_levels":
            inventory = payload

    if production is None or inventory is None:
        raise ValueError("Both required tool results were not returned.")
    if production.get("status") != "OK":
        raise ValueError("Production data is unavailable.")
    if inventory.get("status") != "OK":
        raise ValueError(inventory.get("error", "Inventory data is unavailable."))
    return production, inventory, tool_log


def _safe_result(request: Any, errors: list[str]) -> dict[str, Any]:
    return {
        "status": "FAILED",
        "request": request if isinstance(request, dict) else {},
        "past_burn_rate": None,
        "current_inventory": None,
        "upcoming_production_schedule": [],
        "material_requirement": None,
        "tool_call_log": [],
        "errors": errors,
    }


def _assemble_result(state: DataExtractionState) -> dict[str, Any]:
    try:
        production, inventory, tool_log = _tool_payloads(state.get("messages", []))
        history = production["historical_material_consumption"]
        scheduled_runs = production["upcoming_production_schedule"]
        total_quantity = sum(float(item["quantity_consumed"]) for item in history)
        total_hours = sum(float(item["run_hours"]) for item in history)
        if total_hours <= 0:
            raise ValueError("Historical run hours must be greater than zero.")
        required = sum(float(item["material_required_quantity"]) for item in scheduled_runs)
        allocatable = float(inventory["allocatable_quantity"])
        shortfall = max(0.0, required - allocatable)

        return {
            "extraction_result": {
                "status": "COMPLETED",
                "request": state["request"],
                "past_burn_rate": {
                    "average_quantity_per_hour": round(total_quantity / total_hours, 2),
                    "total_quantity_consumed": total_quantity,
                    "total_run_hours": total_hours,
                    "sample_count": len(history),
                    "unit": inventory["unit"],
                },
                "current_inventory": inventory,
                "upcoming_production_schedule": scheduled_runs,
                "material_requirement": {
                    "upcoming_required_quantity": required,
                    "allocatable_quantity": allocatable,
                    "shortfall_quantity": shortfall,
                    "recommendation": (
                        "REPLENISHMENT_REQUIRED" if shortfall > 0 else "STOCK_SUFFICIENT"
                    ),
                    "unit": inventory["unit"],
                },
                "tool_call_log": tool_log,
                "errors": [],
            },
            "errors": [],
        }
    except (KeyError, TypeError, ValueError) as error:
        errors = [f"Data-extraction safe failure: {error}"]
        return {"extraction_result": _safe_result(state.get("request", {}), errors), "errors": errors}


def _safe_failure_node(state: DataExtractionState) -> dict[str, Any]:
    errors = state.get("errors", ["Data-extraction request failed validation."])
    return {"extraction_result": _safe_result(state.get("request", {}), errors)}


def create_data_extraction_graph(llm: Any | None = None):
    """Create the LangGraph flow: agent -> ToolNode -> JSON assembler.

    With ``llm=None`` (the default) it uses the same controlled policy offline.
    A supplied LangChain tool-calling model receives the prompt above but is
    still constrained to the two required tools and their validated arguments.
    """

    workflow = StateGraph(DataExtractionState)
    workflow.add_node("agent", lambda state: _prepare_tool_calls(state, llm))
    workflow.add_node("tools", ToolNode(ALLOWED_TOOLS, handle_tool_errors=True))
    workflow.add_node("assemble_result", _assemble_result)
    workflow.add_node("safe_failure", _safe_failure_node)
    workflow.add_edge(START, "agent")
    workflow.add_conditional_edges(
        "agent",
        _route_after_agent,
        {"tools": "tools", "safe_failure": "safe_failure"},
    )
    workflow.add_edge("tools", "assemble_result")
    workflow.add_edge("assemble_result", END)
    workflow.add_edge("safe_failure", END)
    return workflow.compile()


DATA_EXTRACTION_GRAPH = create_data_extraction_graph()


def run_data_extraction_agent(payload: Mapping[str, Any]) -> dict[str, Any]:
    """Run the agent and return its structured JSON-compatible output only."""

    final_state = DATA_EXTRACTION_GRAPH.invoke(
        {"request": dict(payload), "messages": [], "errors": []}
    )
    return final_state["extraction_result"]


def run_data_extraction_agent_json(payload: Mapping[str, Any]) -> str:
    """Convenience wrapper for callers that explicitly need a JSON string."""

    return json.dumps(run_data_extraction_agent(payload), sort_keys=True)
