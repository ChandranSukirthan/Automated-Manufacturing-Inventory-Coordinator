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
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.0-flash"
    fastapi_port: int = 8000

    model_config = SettingsConfigDict(env_file=BACKEND_ENV_FILE, extra="ignore")

    @property
    def DB_HOST(self) -> str:
        return self.db_host

    @property
    def DB_PORT(self) -> int:
        return self.db_port

    @property
    def DB_NAME(self) -> str:
        return self.db_name

    @property
    def DB_USER(self) -> str:
        return self.db_user

    @property
    def DB_PASSWORD(self) -> str:
        return self.db_password

    @property
    def OPENAI_API_KEY(self) -> str:
        return self.openai_api_key

    @property
    def GEMINI_API_KEY(self) -> str:
        return self.gemini_api_key

    @property
    def GEMINI_MODEL(self) -> str:
        return self.gemini_model

    @property
    def FASTAPI_PORT(self) -> int:
        return self.fastapi_port

    @property
    def FASTAPI_HOST(self) -> str:
        return "0.0.0.0"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
