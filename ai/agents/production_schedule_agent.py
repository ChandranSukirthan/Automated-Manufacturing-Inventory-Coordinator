"""LLM-bound, read-only production schedule workflow.

The function is intentionally small: it binds the only approved tool, checks
the model-selected tool name, then invokes it with validated arguments.  It
does not create orders or alter stock.
"""

from typing import Any, Dict

from langchain_core.messages import HumanMessage

from ai.tools.production_tools import (
    PRODUCTION_SCHEDULE_TOOLS,
    get_production_schedule,
)


def bind_production_schedule_tools(llm: Any) -> Any:
    """Bind the approved production schedule tool to a compatible chat LLM."""

    return llm.bind_tools(PRODUCTION_SCHEDULE_TOOLS)


def run_production_schedule_workflow(
    llm: Any,
    shift_name: str = "Next shift",
) -> Dict[str, Any]:
    """Ask an LLM to select the schedule tool and execute its validated call."""

    tool_enabled_llm = bind_production_schedule_tools(llm)
    response = tool_enabled_llm.invoke(
        [
            HumanMessage(
                content=(
                    "Use get_production_schedule to retrieve the required "
                    f"materials for {shift_name}."
                )
            )
        ]
    )
    tool_calls = getattr(response, "tool_calls", []) or []
    schedule_call = next(
        (call for call in tool_calls if call.get("name") == get_production_schedule.name),
        None,
    )
    if schedule_call is None:
        raise ValueError("The LLM did not select the approved get_production_schedule tool.")

    arguments = dict(schedule_call.get("args") or {})
    arguments.setdefault("shiftName", shift_name)
    return get_production_schedule.invoke(arguments)
