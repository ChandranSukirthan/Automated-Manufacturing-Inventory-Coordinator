"""Shared, fail-closed interpretation of procurement validation checks."""
from math import isfinite

NON_QUALITY_CHECKS = (
    "supplierValidation", "budgetCheck", "poMathematicalCheck", "materialValidation",
    "quantityCheck", "moqCheck", "packSizeCheck", "supplierVerification",
    "availabilityCheck", "bestChoiceCheck",
)
PASS_VALUES = {"PASS", "PASSED"}


def finite_number(value, name, *, minimum=0, positive=False):
    if isinstance(value, bool):
        raise ValueError(f"{name} must be a finite number")
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError) as error:
        raise ValueError(f"{name} must be a finite number") from error
    if not isfinite(number) or number < minimum or (positive and number <= 0):
        raise ValueError(f"{name} must be finite and {'positive' if positive else 'non-negative'}")
    return number


def failed_checks(results):
    failed = [key for key in NON_QUALITY_CHECKS
              if str(results.get(key, "UNKNOWN")).upper() not in PASS_VALUES]
    if results.get("qualitySafetyStatus") not in ("CLEAR", "PASSED"):
        failed.append("qualitySafetyStatus")
    return failed
