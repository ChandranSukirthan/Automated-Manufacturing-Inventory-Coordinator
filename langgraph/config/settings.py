"""Environment-backed settings for the LangGraph workspace."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
	backend_base_url: str = "http://localhost:5070/api"
	backend_timeout_seconds: float = 30.0
	backend_access_token: str = ""

	model_config = SettingsConfigDict(env_file=".env", extra="ignore")
