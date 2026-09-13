from tools.quality import (
    analyze_defect_context,
    check_related_inventory,
    recommend_quarantine,
)


class FakeBackendClient:
    def __init__(self) -> None:
        self.requested_batches: list[str] = []

    def get_batch(self, batch_id: str) -> dict:
        self.requested_batches.append(batch_id)
        return {
            "id": batch_id,
            "productType": "BoxPouch",
            "inventoryRolls": [
                {"id": "ROLL001", "batchId": batch_id, "status": "Available"},
                {"id": "ROLL002", "batchId": batch_id, "status": "Available"},
            ],
        }


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