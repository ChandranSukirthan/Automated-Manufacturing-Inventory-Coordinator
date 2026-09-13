"""Environment-backed settings for the LangGraph workspace."""

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Settings:
	backend_base_url: str = os.getenv(
		"BACKEND_BASE_URL", "http://localhost:5070/api"
	)
	backend_timeout_seconds: float = float(
		os.getenv("BACKEND_TIMEOUT_SECONDS", "30")
	)
	backend_access_token: str = os.getenv("BACKEND_ACCESS_TOKEN", "")
