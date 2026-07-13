# filename: merchant_service/main.py

import os
import logging
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, EmailStr, Field

logger = logging.getLogger("merchant-service")

PAYMENT_ENGINE_URL = os.getenv("PAYMENT_ENGINE_URL", "http://payment-service:8003").rstrip("/")


class CardInfo(BaseModel):
    number: str = Field(..., min_length=13, max_length=19)
    exp_month: int = Field(..., ge=1, le=12)
    exp_year: int = Field(..., ge=2024)
    cvc: str = Field(..., min_length=3, max_length=4)


class CustomerInfo(BaseModel):
    email: EmailStr
    name: str
    phone: Optional[str] = None


class PaymentIntentIn(BaseModel):
    amount: int = Field(..., gt=0)
    currency: str = Field(default="usd", pattern="^[a-z]{3}$")
    customer: CustomerInfo
    card: CardInfo
    order_id: Optional[str] = None
    description: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    capture: bool = False


class PaymentIdIn(BaseModel):
    payment_id: str
    amount: Optional[int] = None


class RefundIn(BaseModel):
    payment_id: str
    amount: Optional[int] = None
    reason: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class VoidIn(BaseModel):
    payment_id: str
    reason: Optional[str] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Merchant Service and opening global HTTPX client pool...")
    logger.info(f"PAYMENT_ENGINE_URL={PAYMENT_ENGINE_URL}")
    app.state.http_client = httpx.AsyncClient(timeout=10.0)
    yield
    logger.info("Shutting down Merchant Service and destroying client pool...")
    await app.state.http_client.aclose()


app = FastAPI(title="merchant-service", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/payment_intents")
async def create_payment_intent(
    payload: PaymentIntentIn,
    x_merchant_id: str = Header(...),
    idempotency_key: Optional[str] = Header(None, alias="idempotency-key")  # 💡 Extract the key from gateway
):
    payment_data = {
        "amount": payload.amount,
        "currency": payload.currency,
        "customer": payload.customer.model_dump(),
        "card": payload.card.model_dump(),
        "order_id": payload.order_id,
        "description": payload.description,
        "metadata": payload.metadata,
        "capture": payload.capture,
        "merchant_id": x_merchant_id,
    }

    # 💡 Construct internal network headers with standardized lowcase styling
    internal_headers = {
        "x-merchant-id": x_merchant_id
    }
    if idempotency_key:
        internal_headers["idempotency-key"] = idempotency_key  # 💡 Explicitly forward the validation key down the line

    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payment_intents",
            json=payment_data,
            headers=internal_headers  # 💡 Attach the proxy header block
        )
        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Payment Engine rejected: {response.text}",
            )
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Core Payment Engine unreachable: {str(e)}",
        )


@app.post("/captures")
async def capture(payload: PaymentIdIn, x_merchant_id: str = Header(...)):
    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payload.payment_id}/capture",
            json={"merchant_id": x_merchant_id, "amount": payload.amount},
            headers={"x-merchant-id": x_merchant_id}
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Core Payment Engine connection error: {str(e)}",
        )


@app.post("/refunds")
async def refund(payload: RefundIn, x_merchant_id: str = Header(...)):
    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payload.payment_id}/refund",
            json={
                "merchant_id": x_merchant_id,
                "amount": payload.amount,
                "reason": payload.reason,
                "metadata": payload.metadata,
            },
            headers={"x-merchant-id": x_merchant_id}
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Core Payment Engine connection error: {str(e)}",
        )


@app.post("/voids")
async def void(payload: VoidIn, x_merchant_id: str = Header(...)):
    try:
        response = await app.state.http_client.post(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payload.payment_id}/void",
            json={
                "merchant_id": x_merchant_id,
                "reason": payload.reason,
            },
            headers={"x-merchant-id": x_merchant_id}
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Core Payment Engine connection error: {str(e)}",
        )


@app.get("/payments/{payment_id}")
async def get_payment(payment_id: str, x_merchant_id: str = Header(...)):
    try:
        response = await app.state.http_client.get(
            f"{PAYMENT_ENGINE_URL}/api/v1/payments/{payment_id}",
            params={"merchant_id": x_merchant_id},
            headers={"x-merchant-id": x_merchant_id}
        )
        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail="Payment lookup mismatch",
            )
        return response.json()
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Payment Engine connectivity dropped: {str(e)}",
        )
