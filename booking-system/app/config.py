# filename: app/config.py

from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import PostgresDsn, RedisDsn, Field


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "Booking System"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = Field(default="production", env="ENVIRONMENT")

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 4

    # Database
    DATABASE_URL: PostgresDsn
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 3600
    DB_ECHO: bool = False

    # Redis
    REDIS_URL: RedisDsn
    REDIS_MAX_CONNECTIONS: int = 50
    REDIS_SOCKET_TIMEOUT: int = 5
    REDIS_SOCKET_CONNECT_TIMEOUT: int = 5

    # RabbitMQ
    RABBITMQ_URL: str
    RABBITMQ_EXCHANGE: str = "booking_events"
    RABBITMQ_QUEUE: str = "bookings"

    # Locking
    LOCK_TIMEOUT_MS: int = 10000
    LOCK_RETRY_DELAY_MS: int = 100
    LOCK_MAX_RETRIES: int = 3

    # Reservation
    RESERVATION_TIMEOUT_SECONDS: int = 600

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 10

    # Monitoring
    ENABLE_METRICS: bool = True
    METRICS_PORT: int = 9090

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"

    # Security
    ALLOWED_HOSTS: list[str] = ["*"]
    CORS_ORIGINS: list[str] = ["*"]

    # Timeouts
    REQUEST_TIMEOUT: int = 30
    DB_QUERY_TIMEOUT: int = 10000

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
