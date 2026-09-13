"""Defect severity analysis for the Validation/Safety Agent."""

from __future__ import annotations

from typing import Any


def analyze_defect_context(defect: dict[str, Any]) -> dict[str, Any]:
    """Assess whether a defect severity warrants quarantine consideration."""
    severity = _normalize_severity(defect.get("severity"))
    return {
        "batchId": _required_batch_id(defect.get("batchId")),
        "severity": defect.get("severity", ""),
        "quarantineRequired": severity in {"HIGH", "CRITICAL"},
    }


def _required_batch_id(value: Any) -> str:
    batch_id = str(value or "").strip()
    if not batch_id:
        raise ValueError("batchId is required")
    return batch_id


def _normalize_severity(value: Any) -> str:
    return str(value or "").strip().upper()