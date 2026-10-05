"""One deterministic policy shared by purchasing and independent validation.
Eligibility is checked separately; rank eligible quotes by landed order total,
delivery time, then stable identity. Never compare only the unit price when MOQ
and pack-size rounding produce different actual order quantities.
"""
from decimal import Decimal, InvalidOperation


def supplier_rank_key(candidate, report=None):
    report = report or candidate
    try:
        cost = Decimal(str(report.get("totalCost")))
        if not cost.is_finite() or cost < 0:
            cost = Decimal("Infinity")
    except (InvalidOperation, TypeError, ValueError):
        cost = Decimal("Infinity")
    lead = candidate.get("leadTimeDays")
    lead = float(lead) if lead is not None else float("inf")
    identity = str(candidate.get("supplierId") or candidate.get("supplierName") or "")
    approved = 0 if (candidate.get("supplierStatus") or report.get("supplierStatus")) == "APPROVED" else 1
    internal = 0 if candidate.get("origin") in ("Internal", "Internal ERP Database") else 1
    return (approved, internal, cost, lead, identity)
