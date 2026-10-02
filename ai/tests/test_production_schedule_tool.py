from langchain_core.messages import AIMessage

from ai.agents.production_schedule_agent import run_production_schedule_workflow
from ai.tools.production_tools import get_production_schedule


class MockScheduleLlm:
    """A deterministic stand-in proving the workflow binds and invokes a tool."""

    def __init__(self):
        self.bound_tools = []
        self.invocations = []

    def bind_tools(self, tools):
        self.bound_tools = list(tools)
        return self

    def invoke(self, messages):
        self.invocations.append(messages)
        return AIMessage(
            content="",
            tool_calls=[
                {
                    "name": "get_production_schedule",
                    "args": {"shiftName": "Night shift"},
                    "id": "call-schedule-1",
                }
            ],
        )


def test_schedule_workflow_binds_llm_and_invokes_allowlisted_tool():
    llm = MockScheduleLlm()

    result = run_production_schedule_workflow(llm, shift_name="Night shift")

    assert llm.bound_tools == [get_production_schedule]
    assert len(llm.invocations) == 1
    assert result["shiftName"] == "Night shift"
    assert result["status"] == "Scheduled"
    assert any(material["sku"] == "CR-001" for material in result["requiredMaterials"])
