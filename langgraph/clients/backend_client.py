"""Read-only HTTP client for the existing ASP.NET Core API."""

from __future__ import annotations

from typing import Any
from urllib.parse import quote

import httpx

from config.settings import Settings


class BackendClient:
	"""Calls existing API endpoints without direct database access."""

	def __init__(self, settings: Settings | None = None) -> None:
		self.settings = settings or Settings()

	def get_batch(self, batch_id: str) -> dict[str, Any]:
		"""Return a batch and its inventory rolls from the ASP.NET API."""
		headers = {}
		if self.settings.backend_access_token:
			headers["Authorization"] = f"Bearer {self.settings.backend_access_token}"

		response = httpx.get(
			f"{self.settings.backend_base_url}/batches/{quote(batch_id, safe='')}",
			headers=headers,
			timeout=self.settings.backend_timeout_seconds,
		)
		response.raise_for_status()
		return response.json()
