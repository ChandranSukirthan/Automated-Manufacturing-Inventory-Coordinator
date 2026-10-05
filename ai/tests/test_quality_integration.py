from __future__ import annotations

import ast
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ai.agents.quality_agent import MANDATORY_AGENTS, run_quality_validation
from ai.main import app
from ai.tools.quality_tools import (
    analyze_defect_context,
    check_related_inventory,
    recommend_quarantine,
)


HIGH_DEFECT = {
    "batchId": "BATCH001",
    "productType": "BoxPouch",
    "severity": "High",
    "description": "Material defect detected",
}


class FakeCursor:
    def __init__(self, connection: "FakeConnection") -> None:
        self.connection = connection
        self.query = ""

    def __enter__(self) -> "FakeCursor":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def execute(self, query: str, params: tuple[str, ...]) -> None:
        self.query = query
        self.connection.queries.append((query, params))

    def fetchone(self) -> tuple[int] | None:
        if '"Batches"' in self.query:
            return (1,) if self.connection.batch_exists else None
        if '"DefectReports"' in self.query:
            return (1,) if self.connection.previous_severe_defect else None
        if '"Status"' in self.query:
            return (1,) if self.connection.quarantined_inventory else None
        return None

    def fetchall(self) -> list[tuple[str]]:
        return [(inventory_id,) for inventory_id in self.connection.inventory]


class FakeConnection:
    def __init__(
        self,
        *,
        batch_exists: bool = True,
        inventory: list[str] | None = None,
        quarantined_inventory: bool = False,
        previous_severe_defect: bool = False,
    ) -> None:
        self.batch_exists = batch_exists
        self.inventory = inventory or []
        self.quarantined_inventory = quarantined_inventory
        self.previous_severe_defect = previous_severe_defect
        self.queries: list[tuple[str, tuple[str, ...]]] = []

    def cursor(self) -> FakeCursor:
        return FakeCursor(self)


def test_recommend_quarantine_golden_case_is_read_only() -> None:
    connection = FakeConnection(inventory=["ROLL001", "ROLL002"])

    result = recommend_quarantine(HIGH_DEFECT, connection)

    assert result == {
        "batchId": "BATCH001",
        "quarantineRequired": True,
        "affectedInventory": ["ROLL001", "ROLL002"],
        "riskLevel": "HIGH",
    }
    assert all(
        not any(operation in query.upper() for operation in ("INSERT", "UPDATE", "DELETE"))
        for query, _ in connection.queries
    )


def test_high_and_critical_defects_require_quarantine() -> None:
    assert analyze_defect_context(HIGH_DEFECT)["quarantineRequired"] is True
    assert analyze_defect_context({**HIGH_DEFECT, "severity": "Critical"})[
        "quarantineRequired"
    ] is True


def test_low_normal_defect_does_not_require_quarantine() -> None:
    result = analyze_defect_context(
        {**HIGH_DEFECT, "severity": "Low", "description": "Minor cosmetic issue"}
    )

    assert result["quarantineRequired"] is False


@pytest.mark.parametrize(
    ("field", "value"),
    [("productType", "UnknownProduct"), ("severity", "Extreme")],
)
def test_invalid_defect_values_raise_validation_error(field: str, value: str) -> None:
    with pytest.raises(ValueError):
        analyze_defect_context({**HIGH_DEFECT, field: value})


def test_unknown_batch_is_a_safe_validation_error() -> None:
    with pytest.raises(ValueError, match="Batch was not found"):
        check_related_inventory("UNKNOWN", FakeConnection(batch_exists=False))


def test_existing_batch_without_inventory_returns_empty_list() -> None:
    assert check_related_inventory("BATCH001", FakeConnection()) == {
        "batchId": "BATCH001",
        "affectedInventory": [],
    }


def test_validation_safety_rejects_already_quarantined_inventory() -> None:
    result = run_quality_validation(
        {"quality_data": {"defect": HIGH_DEFECT}, "tool_results": {}},
        FakeConnection(quarantined_inventory=True),
    )

    assert {key: result["quality_data"]["validation"][key] for key in ("valid", "riskLevel", "reason")} == {
        "valid": False,
        "riskLevel": "HIGH",
        "reason": "Associated inventory is quarantined",
    }
    assert result["requires_approval"] is False


def test_backend_state_overrides_safe_ai_recommendation() -> None:
    low_defect = {**HIGH_DEFECT, "severity": "Low", "description": "Minor cosmetic issue"}
    recommendation = recommend_quarantine(
        low_defect,
        related_inventory={"affectedInventory": ["ROLL001", "ROLL002"]},
    )
    assert recommendation["quarantineRequired"] is False

    result = run_quality_validation(
        {"quality_data": {"defect": low_defect}, "tool_results": {}},
        FakeConnection(quarantined_inventory=True),
    )

    assert {key: result["quality_data"]["validation"][key] for key in ("valid", "riskLevel", "reason")} == {
        "valid": False,
        "riskLevel": "HIGH",
        "reason": "Associated inventory is quarantined",
    }


def test_validation_safety_rejects_invalid_purchase_order() -> None:
    result = run_quality_validation(
        {
            "quality_data": {"defect": HIGH_DEFECT},
            "purchasing_data": {
                "purchase_order": {
                    "supplier": "Supplier A",
                    "quantity": 12,
                    "budget": 1500,
                },
                "business_rules": {"maxQuantity": 10, "maxBudget": 2000},
            },
            "tool_results": {},
        },
        FakeConnection(),
    )

    assert {key: result["quality_data"]["validation"][key] for key in ("valid", "riskLevel", "reason")} == {
        "valid": False,
        "riskLevel": "HIGH",
        "reason": "Quantity exceeds the business rule limit",
    }


def test_quality_route_returns_recommendation_without_mutation(monkeypatch: pytest.MonkeyPatch) -> None:
    import ai.routes.quality_routes as quality_routes

    def fake_validation(state: dict) -> dict:
        return {
            **state,
            "quality_data": {
                **state["quality_data"],
                "validation": {
                    "batchId": "BATCH001",
                    "quarantineRequired": True,
                    "affectedInventory": ["ROLL001", "ROLL002"],
                    "riskLevel": "HIGH",
                },
            },
        }

    from ai.security import require_actor
    app.dependency_overrides[require_actor] = lambda: {"role": "QualityInspector"}
    monkeypatch.setattr(quality_routes, "run_quality_validation", fake_validation)
    response = TestClient(app).post("/quality/recommendation", json=HIGH_DEFECT)

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["affectedInventory"] == ["ROLL001", "ROLL002"]


def test_quality_route_accepts_defect_without_product_type(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import ai.routes.quality_routes as quality_routes

    def fake_validation(state: dict) -> dict:
        return {
            **state,
            "quality_data": {
                **state["quality_data"],
                "validation": {
                    "batchId": "BATCH001",
                    "quarantineRequired": False,
                    "affectedInventory": ["ROLL001"],
                    "riskLevel": "LOW",
                },
            },
        }

    from ai.security import require_actor
    app.dependency_overrides[require_actor] = lambda: {"role": "QualityInspector"}
    monkeypatch.setattr(quality_routes, "run_quality_validation", fake_validation)
    response = TestClient(app).post(
        "/quality/recommendation",
        json={
            "skuCode": "RM001",
            "severity": "LOW",
            "description": "Minor cosmetic issue",
            "affectedInventory": ["ROLL001"],
        },
    )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["riskLevel"] == "LOW"


def test_exactly_four_mandatory_agents_and_three_quality_tools() -> None:
    assert MANDATORY_AGENTS == (
        "Planner",
        "Data Extraction",
        "Purchasing",
        "Validation/Safety",
    )
    source = Path(__file__).parents[1].joinpath("tools", "quality_tools.py").read_text()
    tree = ast.parse(source)
    public_functions = [
        node.name
        for node in tree.body
        if isinstance(node, ast.FunctionDef) and not node.name.startswith("_")
    ]
    assert public_functions == [
        "analyze_defect_context",
        "check_related_inventory",
        "recommend_quarantine",
    ]


@pytest.mark.parametrize("value", [float("nan"), float("inf"), float("-inf"), True])
def test_individual_purchase_order_rejects_nonfinite_numbers(value):
    from ai.agents.quality_agent import _validate_purchase_order
    assert _validate_purchase_order({"supplier": "Supplier A", "quantity": value, "budget": 100}, {}) == "Quantity must be greater than zero"


def test_individual_history_is_checked_with_one_owned_connection(monkeypatch):
    import psycopg
    connection = FakeConnection(previous_severe_defect=True)
    class Owned:
        def __enter__(self): return connection
        def __exit__(self, *_): return False
    calls = []
    monkeypatch.setattr(psycopg, "connect", lambda *a, **kw: calls.append(1) or Owned())
    result = run_quality_validation({"quality_data": {"defect": {**HIGH_DEFECT, "severity": "Medium", "description": "Cosmetic issue"}}})
    assessment = result["quality_data"]["validation"]
    assert assessment["quarantineRequired"] is True
    assert assessment["valid"] is assessment["isValid"] is False
    assert assessment["requiredAction"] == "QA_REVIEW"
    assert len(calls) == 1


def test_canonical_draft_order_is_validated():
    result = run_quality_validation({"quality_data": {"defect": {**HIGH_DEFECT, "severity": "Low"}},
        "draft_po": {"supplierId": "SUP-A", "quantity": float("nan"), "budgetLimit": 100}}, FakeConnection())
    assert result["quality_data"]["validation"]["isValid"] is False
    assert result["quality_data"]["validation"]["reason"] == "Quantity must be greater than zero"
