from tools.quality import (
    analyze_defect_context,
    check_related_inventory,
    recommend_quarantine,
)
from agents.validation_safety import validate_safety


class FakeBackendClient:
    def __init__(self) -> None:
        self.requested_batches: list[str] = []
        self.batches: dict[str, dict] = {}

    def get_batch(self, batch_id: str) -> dict:
        self.requested_batches.append(batch_id)
        return self.batches.get(batch_id, {
            "id": batch_id,
            "productType": "BoxPouch",
            "inventoryRolls": [
                {"id": "ROLL001", "batchId": batch_id, "status": "Available"},
                {"id": "ROLL002", "batchId": batch_id, "status": "Available"},
            ],
        })


def test_analyze_defect_context_high_severity_requires_quarantine() -> None:
    result = analyze_defect_context(
        {
            "batchId": "BATCH001",
            "productType": "BoxPouch",
            "severity": "High",
            "description": "Material defect detected",
        }
    )

    assert result == {
        "batchId": "BATCH001",
        "severity": "High",
        "quarantineRequired": True,
    }


def test_analyze_defect_context_low_severity_does_not_require_quarantine() -> None:
    result = analyze_defect_context(
        {
            "batchId": "BATCH001",
            "productType": "BoxPouch",
            "severity": "LOW",
            "description": "Minor cosmetic issue",
        }
    )

    assert result["quarantineRequired"] is False


def test_check_related_inventory_reads_rolls_from_backend() -> None:
    client = FakeBackendClient()

    result = check_related_inventory({"batchId": "BATCH001"}, client)

    assert result == {
        "batchId": "BATCH001",
        "affectedInventory": ["ROLL001", "ROLL002"],
    }
    assert client.requested_batches == ["BATCH001"]


def test_recommend_quarantine_returns_golden_case_without_mutation() -> None:
    client = FakeBackendClient()
    defect = {
        "batchId": "BATCH001",
        "productType": "BoxPouch",
        "severity": "High",
        "description": "Material defect detected",
    }

    result = recommend_quarantine(defect, client)

    assert result == {
        "batchId": "BATCH001",
        "quarantineRequired": True,
        "affectedInventory": ["ROLL001", "ROLL002"],
        "riskLevel": "HIGH",
    }
    assert client.requested_batches == ["BATCH001"]


def test_validation_safety_rejects_already_quarantined_inventory() -> None:
    client = FakeBackendClient()
    client.batches["BATCH001"] = {
        "id": "BATCH001",
        "inventoryRolls": [
            {"id": "ROLL001", "batchId": "BATCH001", "status": "Quarantined"},
            {"id": "ROLL002", "batchId": "BATCH001", "status": "Available"},
        ],
    }

    result = validate_safety(
        {
            "batchId": "BATCH001",
            "productType": "BoxPouch",
            "severity": "High",
            "description": "Material defect detected",
        },
        client,
    )

    assert result == {
        "valid": False,
        "riskLevel": "HIGH",
        "reason": "Associated inventory is quarantined",
    }


def test_validation_safety_rejects_invalid_purchase_order_before_mutation() -> None:
    client = FakeBackendClient()

    result = validate_safety(
        {
            "batchId": "BATCH001",
            "productType": "BoxPouch",
            "severity": "High",
            "description": "Material defect detected",
        },
        client,
        purchase_order={"supplier": "Supplier A", "quantity": 12, "budget": 1500},
        business_rules={"maxQuantity": 10, "maxBudget": 2000},
    )

    assert result == {
        "valid": False,
        "riskLevel": "HIGH",
        "reason": "Quantity exceeds the business rule limit",
    }


def test_validation_safety_returns_recommendation_without_mutation_api() -> None:
    client = FakeBackendClient()
    defect = {
        "batchId": "BATCH001",
        "productType": "BoxPouch",
        "severity": "High",
        "description": "Material defect detected",
    }

    result = validate_safety(
        defect,
        client,
        purchase_order={"supplier": "Supplier A", "quantity": 2, "budget": 1500},
        business_rules={"allowedSuppliers": ["Supplier A"], "maxBudget": 2000},
    )

    assert result["valid"] is True
    assert result["recommendation"]["affectedInventory"] == ["ROLL001", "ROLL002"]
    assert result["recommendation"]["riskLevel"] == "HIGH"
    assert not hasattr(client, "quarantine")
    assert not hasattr(client, "update_inventory_status")