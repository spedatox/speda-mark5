"""Application configuration settings."""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

# Get the backend directory (where .env is located)
BACKEND_DIR = Path(__file__).parent.parent


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "Speda"
    app_version: str = "0.1.0"
    debug: bool = False

    # Database
    database_url: str = "sqlite+aiosqlite:///./speda.db"

    # Authentication
    secret_key: str = "your-secret-key-change-in-production"
    access_token_expire_minutes: int = 60 * 24 * 7  # 1 week
    algorithm: str = "HS256"
    api_token: str = "speda-dev-token"  # Simple token for single user

    # LLM Configuration
    llm_provider: Literal["openai", "mock"] = "mock"
    openai_api_key: str = ""
    openai_model: str = "gpt-4-turbo-preview"
    openai_base_url: str | None = None

    # Memory settings
    max_context_messages: int = 20
    summary_threshold: int = 50

    # Google OAuth2 Configuration
    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/api/auth/google/callback"

    # Microsoft 365 OAuth2 Configuration
    microsoft_client_id: str = ""
    microsoft_client_secret: str = ""
    microsoft_redirect_uri: str = "http://localhost:8000/api/auth/microsoft/callback"

    # Weather API (OpenWeatherMap)
    weather_api_key: str = ""
    weather_default_city: str = "Istanbul,TR"

    # News API (NewsAPI.org)
    news_api_key: str = ""
    news_default_country: str = "tr"

    # IMAP/SMTP Mail Configuration
    mail_email: str = ""
    mail_password: str = ""  # Use app password for Gmail/Outlook
    mail_imap_server: str = ""
    mail_imap_port: int = 993
    mail_smtp_server: str = ""
    mail_smtp_port: int = 465


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
