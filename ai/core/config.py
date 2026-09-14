from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_ENV_FILE = Path(__file__).resolve().parents[2] / "backend" / ".env"


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "inventory_coordinator"
    db_user: str = "postgres"
    db_password: str = ""
    openai_api_key: str = ""
    fastapi_port: int = 8000

    model_config = SettingsConfigDict(env_file=BACKEND_ENV_FILE, extra="ignore")

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
