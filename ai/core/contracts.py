"""Shared value semantics for authoritative agent inputs (zero is a value)."""
def first_present(*values):
    return next((value for value in values if value is not None), None)
