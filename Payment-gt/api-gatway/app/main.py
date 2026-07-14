# filename: api-gatway/app/main.py
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, HTTPException, Request, Response
from redis.asyncio import Redis
from app.config import settings
from app.db import create_pool, get_api_key, init_db
from app.rate_limit import enforce
from app.security import JwksCache, bearer_token, client_ip, require_scope

MERCHANT = {
    ("POST", "payment_intents"): "payment_intents:create",
    ("POST", "captures"): "captures:create",
    ("POST", "refunds"): "refunds:create",
    ("GET", "payments"): "payments:read",
    ("GET", "balance"): "balance:read",
    ("POST", "voids"): "voids:create"
}
CUSTOMER = {
    ("POST", "payment_sessions"): "payment_session:create",
    ("GET", "payment_sessions"): "payment_session:read_own",
    ("POST", "payment_methods/tokenize"): "payment_method:tokenize",
    ("POST", "payment_intents/confirm"): "payment_intent:confirm_own",
    ("GET", "config"): "public_config:read",
}

def scope_for(method: str, path: str, rules: dict) -> str | None:
    p = path.strip("/")
    return next((s for (m, x), s in rules.items() if m == method and (p == x or p.startswith(f"{x}/"))), None)

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.redis = Redis.from_url(settings.redis_url, decode_responses=True)
    app.state.db = await create_pool(settings.database_url)
    app.state.http = httpx.AsyncClient(timeout=20)
    app.state.jwks = JwksCache()
    await init_db(app.state.db, settings.key_hash_pepper, settings.seed_api_keys_json)
    yield
    await app.state.http.aclose()
    await app.state.redis.aclose()
    await app.state.db.close()

app = FastAPI(title="payment-api-gateway", lifespan=lifespan)

@app.middleware("http")
async def cors(request: Request, call_next):
    if not request.url.path.startswith("/v1/customer/"):
        return await call_next(request)
    origin = request.headers.get("origin")
    if request.method == "OPTIONS":
        if not origin or origin not in settings.allowed_origins:
            return Response(status_code=403, content="Origin not allowed")
        return Response(status_code=204, headers={
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Access-Control-Allow-Headers": "Authorization,Content-Type,X-Publishable-Key,Idempotency-Key",
            "Access-Control-Allow-Credentials": "true",
            "Vary": "Origin",
        })
    r = await call_next(request)
    if origin and origin in settings.allowed_origins:
        r.headers["Access-Control-Allow-Origin"] = origin
        r.headers["Access-Control-Allow-Credentials"] = "true"
        r.headers["Vary"] = "Origin"
    return r

@app.get("/health")
async def health():
    return {"status": "ok"}

async def proxy(req: Request, base: str, path: str, extra: dict):
    body = await req.body()
    headers = {k: v for k, v in req.headers.items() if k.lower() not in {"host", "authorization", "x-publishable-key"}}
    headers.update(extra)
    try:
        up = await req.app.state.http.request(
            req.method,
            f"{base.rstrip('/')}/{path.lstrip('/')}",
            params=req.query_params,
            content=body,
            headers=headers
        )
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"Upstream error: {e}") from e
    return Response(content=up.content, status_code=up.status_code, media_type=up.headers.get("content-type"))

@app.api_route("/v1/merchant/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def merchant(path: str, request: Request):
    token = bearer_token(request.headers.get("authorization"))
    record = await get_api_key(app.state.db, settings.key_hash_pepper, token)
    if not record or not record["active"] or record["key_type"] not in {"secret", "restricted"}:
        raise HTTPException(status_code=401, detail="Invalid merchant API key")
    scope = scope_for(request.method, path, MERCHANT)
    if scope:
        require_scope(record, scope)
    await enforce(app.state.redis, f"merchant:{record['merchant_id']}:{record['key_id']}", settings.merchant_rate_limit_per_min)
    return await proxy(request, settings.merchant_service_url, path, {
        "x-merchant-id": record["merchant_id"],
        "x-key-id": record["key_id"],
        "x-key-type": record["key_type"]
    })

@app.api_route("/v1/customer/{path:path}", methods=["GET", "POST"])
async def customer(path: str, request: Request):
    pk = request.headers.get("x-publishable-key")
    if not pk:
        raise HTTPException(status_code=401, detail="Missing publishable key")

    record = await get_api_key(app.state.db, settings.key_hash_pepper, pk)
    if not record or not record["active"] or record["key_type"] != "publishable":
        raise HTTPException(status_code=401, detail="Invalid publishable key")

    origin = request.headers.get("origin")
    if origin:
        if origin not in settings.allowed_origins or (record["allowed_origins"] and origin not in record["allowed_origins"]):
            raise HTTPException(status_code=403, detail="Origin not allowed")

    claims = await app.state.jwks.validate_jwt(bearer_token(request.headers.get("authorization")))
    scope = scope_for(request.method, path, CUSTOMER)
    if scope:
        require_scope(claims, scope)

    limit = settings.public_confirm_rate_limit_per_min if path.strip("/") == "payment_intents/confirm" else settings.public_rate_limit_per_min
    await enforce(app.state.redis, f"customer-ip:{record['key_id']}:{client_ip(request)}", limit)
    await enforce(app.state.redis, f"customer-user:{record['key_id']}:{claims.get('sub')}", limit)

    return await proxy(request, settings.customer_service_url, path, {
        "x-merchant-id": record["merchant_id"],
        "x-key-id": record["key_id"],
        "x-key-type": record["key_type"],
        "x-user-id": str(claims.get("sub", "")),
        "x-user-email": str(claims.get("email", "")),
        "x-user-roles": ",".join(claims.get("roles", [])) if isinstance(claims.get("roles"), list) else ""
    })
