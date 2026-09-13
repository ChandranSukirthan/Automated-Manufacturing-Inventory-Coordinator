"""Validation/Safety agent boundary owned by Student 3."""

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
	"BackendClient",
]
