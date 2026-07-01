# filename: app/config.py

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(alias="DATABASE_URL")
    redis_url: str = Field(alias="REDIS_URL")
    payment_gateway_base_url: str = Field(alias="PAYMENT_GATEWAY_BASE_URL")
    payment_gateway_api_key: str = Field(alias="PAYMENT_GATEWAY_API_KEY")
    debug: bool = Field(default=False, alias="DEBUG")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    hold_ttl_seconds: int = Field(default=300, alias="HOLD_TTL_SECONDS")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
