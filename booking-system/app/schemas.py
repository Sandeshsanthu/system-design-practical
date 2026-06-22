# filename: app/schemas.py

from pydantic import BaseModel, UUID4, ConfigDict
from datetime import datetime
from decimal import Decimal
from typing import Optional


class EventCreate(BaseModel):
    event_name: str
    event_date: datetime
    venue: str
    total_seats: int


class EventResponse(BaseModel):
    event_id: UUID4
    event_name: str
    event_date: datetime
    venue: str
    total_seats: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SeatCreate(BaseModel):
    seat_number: str
    price: Decimal


class SeatResponse(BaseModel):
    seat_id: UUID4
    event_id: UUID4
    seat_number: str
    price: Decimal
    status: str
    reserved_until: Optional[datetime] = None
    booked_by: Optional[UUID4] = None

    model_config = ConfigDict(from_attributes=True)


class BookingCreate(BaseModel):
    user_id: UUID4
    event_id: UUID4
    seat_id: UUID4


class BookingResponse(BaseModel):
    booking_id: UUID4
    user_id: UUID4
    event_id: UUID4
    seat_id: UUID4
    status: str
    total_amount: Decimal
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
