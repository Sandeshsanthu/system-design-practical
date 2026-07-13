import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
import httpx

logger = logging.getLogger("merchant-service")

# Configurations - Explicitly matched to Docker network targets
PAYMENT_ENGINE_URL = os.getenv("PAYMENT_ENGINE_URL", "http://payment-service:8003").rstrip("/")

class PaymentIntentIn(BaseModel):
    amount: int
    currency: str
    order_id: str | None = None

class PaymentIdIn(BaseModel):
    payment_id: str
    amount: int | None = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Production-grade shared client connection pooling"""
    logger.info("Starting Merchant Service and opening global HTTPX client pool...")
    app.state.http_client = httpx.AsyncClient(timeout=10.0)
    yield
    logger.info("Shutting down Merchant Service and destroying client pool...")
    await app.state.http_client.aclose()

app = FastAPI(title="merchant-service", lifespan=lifespan)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/payment_intents")
async def create_payment_intent(payload: PaymentIntentIn, x_merchant_id: str = Header(...)):
    payment_data = {
        "amount": payload.amount,
        "currency": payload.currency,
        "order_id": payload.order_id,
        "merchant_id": x_merchant_id
    }
    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payment_intents",
            json=payment_data
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=f"Database Engine rejected: {response.text}")
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Core Payment Engine unreachable: {str(e)}")

@app.post("/captures")
async def capture(payload: PaymentIdIn, x_merchant_id: str = Header(...)):
    """Forward data directly to the persistence layer to apply capture row transitions"""
    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payload.payment_id}/capture",
            json={"merchant_id": x_merchant_id, "amount": payload.amount}
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Core Payment Engine connection error: {str(e)}")

@app.get("/payments/{payment_id}")
async def get_payment(payment_id: str, x_merchant_id: str = Header(...)):
    """Query data straight out of the active Postgres state instead of an empty local dict"""
    try:
        response = await app.state.http_client.get(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payment_id}",
            params={"merchant_id": x_merchant_id}
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail="Payment lookup mismatch")
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Payment Engine connectivity dropped: {str(e)}")
