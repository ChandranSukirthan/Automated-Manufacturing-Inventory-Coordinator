from graphs.manufacturing_graph import MANDATORY_AGENTS


def test_exactly_four_mandatory_agents_are_declared() -> None:
    assert MANDATORY_AGENTS == (
        "Planner",
        "Data Extraction",
        "Purchasing",
        "Validation/Safety",
    )
