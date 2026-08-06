import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text

from Payment.api.endpoints import router as payment_router
from Payment.config.database import DATABASE_URL, Base, SessionLocal, engine
from Payment.models import payment  # noqa: F401
from Payment.search import initialize_search, shutdown_search

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Payment Service Starting...")

    try:
        db_host = DATABASE_URL.split("@")[1] if "@" in DATABASE_URL else "local"
        logger.info("Target Database Host: %s", db_host)
    except Exception: # noqa: BLE001
        logger.info("Target Database Host: Configured via environment string")

    db = SessionLocal()

    try:
        db.execute(text("SELECT 1"))
        logger.info("Database connection verification successful")
    except Exception as exc:
        logger.critical(
            "Database connection failed during startup: %s",
            exc,
        )
        raise
    finally:
        db.close()

    Base.metadata.create_all(bind=engine)
    logger.info("Database tables ensured")

    # Initializes app.state.es. If your search.py uses graceful startup,
    # the service can continue even when Elasticsearch is temporarily down.
    await initialize_search(app)

    try:
        yield
    finally:
        await shutdown_search(app)
        logger.info("Payment Service Shutting down...")


app = FastAPI(
    title="Payment Processing Service",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health():
    elasticsearch_ready = getattr(app.state, "es", None) is not None

    return {
        "status": "ok",
        "elasticsearch": "ready" if elasticsearch_ready else "unavailable",
    }


app.include_router(payment_router, prefix="/api/v1")
