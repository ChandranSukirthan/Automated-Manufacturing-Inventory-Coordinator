"""Validation/Safety agent boundary owned by Student 3."""

from __future__ import annotations

from typing import Any

from clients.backend_client import BackendClient
from tools.quality import (
	analyze_defect_context,
	check_related_inventory,
	recommend_quarantine,
)

__all__ = [
	"analyze_defect_context",
	"check_related_inventory",
	"recommend_quarantine",
	"validate_safety",
	"BackendClient",
]


def validate_safety(
	defect: dict[str, Any],
	client: BackendClient,
	purchase_order: dict[str, Any] | None = None,
	business_rules: dict[str, Any] | None = None,
) -> dict[str, Any]:
	"""Run the quality recommendation through deterministic safety checks.

	The function only reads the existing backend API. It returns a recommendation
	for a later ASP.NET Core validation step and never performs a mutation.
	"""
	context = analyze_defect_context(defect)
	inventory = check_related_inventory(context["batchId"], client)
	recommendation = recommend_quarantine(defect, client, inventory)
	batch = client.get_batch(context["batchId"])

	if _has_quarantined_inventory(batch):
		return {
			"valid": False,
			"riskLevel": "HIGH",
			"reason": "Associated inventory is quarantined",
		}

	reason = _validate_purchase_order(purchase_order, business_rules)
	if reason:
		return {
			"valid": False,
			"riskLevel": recommendation["riskLevel"],
			"reason": reason,
		}

	return {
		"valid": True,
		"riskLevel": recommendation["riskLevel"],
		"recommendation": recommendation,
	}


def _has_quarantined_inventory(batch: dict[str, Any]) -> bool:
	return any(
		str(roll.get("status", "")).strip().upper() == "QUARANTINED"
		for roll in batch.get("inventoryRolls", [])
	)


def _validate_purchase_order(
	purchase_order: dict[str, Any] | None,
	business_rules: dict[str, Any] | None,
) -> str | None:
	if purchase_order is None:
		return None

	supplier = str(purchase_order.get("supplier", "")).strip()
	if not supplier:
		return "Supplier is required"

	quantity = _number(purchase_order.get("quantity"))
	if quantity is None or quantity <= 0:
		return "Quantity must be greater than zero"

	budget = _number(purchase_order.get("budget"))
	if budget is None or budget < 0:
		return "Budget must be zero or greater"

	rules = business_rules or {}
	allowed_suppliers = rules.get("allowedSuppliers")
	if allowed_suppliers and supplier not in allowed_suppliers:
		return "Supplier is not allowed by business rules"

	max_quantity = _number(rules.get("maxQuantity"))
	if max_quantity is not None and quantity > max_quantity:
		return "Quantity exceeds the business rule limit"

	max_budget = _number(rules.get("maxBudget"))
	if max_budget is not None and budget > max_budget:
		return "Budget exceeds the business rule limit"

	return None


def _number(value: Any) -> float | None:
	try:
		return None if value is None or isinstance(value, bool) else float(value)
	except (TypeError, ValueError):
		return None
