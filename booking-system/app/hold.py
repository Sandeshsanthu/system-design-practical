#tis is hold se
# filename: app/hold_service.py

import json
import uuid
from datetime import datetime, timedelta
from typing import Optional

from app.config import settings
from app.lock_service import redis_client


class HoldService:
    DEFAULT_TTL_SECONDS = settings.hold_ttl_seconds

    @staticmethod
    def hold_key(event_id: str, seat_id: str) -> str:
        return f"hold:{event_id}:{seat_id}"

    @staticmethod
    def token_key(hold_token: str) -> str:
        return f"holdtoken:{hold_token}"

    @staticmethod
    def create_hold(
        user_id: str,
        event_id: str,
        seat_id: str,
        ttl_seconds: int = DEFAULT_TTL_SECONDS,
    ) -> tuple[bool, dict]:
        hold_key = HoldService.hold_key(event_id, seat_id)
        existing = HoldService.get_hold(event_id, seat_id)
        if existing:
            return False, existing

        hold_token = str(uuid.uuid4())
        expires_at = datetime.utcnow() + timedelta(seconds=ttl_seconds)
        payload = {
            "hold_token": hold_token,
            "user_id": str(user_id),
            "event_id": str(event_id),
            "seat_id": str(seat_id),
            "status": "held",
            "expires_at": expires_at.isoformat(),
            "ttl_seconds": ttl_seconds,
        }

        created = redis_client.set(
            hold_key,
            json.dumps(payload),
            nx=True,
            ex=ttl_seconds,
        )

        if not created:
            current = HoldService.get_hold(event_id, seat_id)
            return False, current or payload

        redis_client.set(
            HoldService.token_key(hold_token),
            json.dumps(payload),
            ex=ttl_seconds,
        )
        return True, payload

    @staticmethod
    def get_hold(event_id: str, seat_id: str) -> Optional[dict]:
        raw = redis_client.get(HoldService.hold_key(event_id, seat_id))
        return json.loads(raw) if raw else None

    @staticmethod
    def get_hold_by_token(hold_token: str) -> Optional[dict]:
        raw = redis_client.get(HoldService.token_key(hold_token))
        return json.loads(raw) if raw else None

    @staticmethod
    def validate_hold(
        hold_token: str,
        user_id: str,
        event_id: str,
        seat_id: str,
    ) -> Optional[dict]:
        hold = HoldService.get_hold_by_token(hold_token)
        if not hold:
            return None

        if (
            str(hold["user_id"]) != str(user_id)
            or str(hold["event_id"]) != str(event_id)
            or str(hold["seat_id"]) != str(seat_id)
        ):
            return None

        active_hold = HoldService.get_hold(event_id, seat_id)
        if not active_hold:
            return None

        if str(active_hold["hold_token"]) != str(hold_token):
            return None

        return active_hold

    @staticmethod
    def release_hold(hold_token: str) -> Optional[dict]:
        hold = HoldService.get_hold_by_token(hold_token)
        if not hold:
            return None

        redis_client.delete(HoldService.hold_key(hold["event_id"], hold["seat_id"]))
        redis_client.delete(HoldService.token_key(hold_token))
        return hold

    @staticmethod
    def extend_hold(hold_token: str, extra_seconds: int = 180) -> Optional[dict]:
        hold = HoldService.get_hold_by_token(hold_token)
        if not hold:
            return None

        remaining_ttl = redis_client.ttl(
            HoldService.hold_key(hold["event_id"], hold["seat_id"])
        )
        if remaining_ttl is None or remaining_ttl < 0:
            remaining_ttl = 0

        new_ttl = remaining_ttl + extra_seconds
        hold["ttl_seconds"] = new_ttl
        hold["expires_at"] = (
            datetime.utcnow() + timedelta(seconds=new_ttl)
        ).isoformat()

        redis_client.set(
            HoldService.hold_key(hold["event_id"], hold["seat_id"]),
            json.dumps(hold),
            ex=new_ttl,
        )
        redis_client.set(
            HoldService.token_key(hold_token),
            json.dumps(hold),
            ex=new_ttl,
        )
        return hold
