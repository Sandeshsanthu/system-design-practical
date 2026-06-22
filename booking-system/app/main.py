# filename: app/main.py
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List
from sqlalchemy import text

from app.database import get_db, engine, Base
from models.models import Event, Seat, Booking, SeatStatus, BookingStatus
from app.schemas import (
    EventCreate, EventResponse,
    SeatCreate, SeatResponse,
    BookingCreate, BookingResponse
)
from app.lock_service import acquire_lock

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Booking System",
    version="1.0.0",
    description="Production-ready ticket booking system"
)


@app.get("/")
async def root():
    return {
        "message": "Booking System API",
        "version": "1.0.0",
        "status": "running"
    }


@app.get("/health")
async def health(db: Session = Depends(get_db)):
    """Health check endpoint"""
    try:
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    try:
        from app.lock_service import redis_client
        redis_client.ping()
        redis_status = "healthy"
    except Exception as e:
        redis_status = f"unhealthy: {str(e)}"

    return {
        "status": "healthy",
        "database": db_status,
        "redis": redis_status
    }


# ==================== EVENT ENDPOINTS ====================

@app.post("/events", response_model=EventResponse, status_code=201)
async def create_event(event: EventCreate, db: Session = Depends(get_db)):
    """Create a new event"""
    db_event = Event(**event.model_dump())
    db.add(db_event)
    db.commit()
    db.refresh(db_event)
    return db_event


@app.get("/events", response_model=List[EventResponse])
async def list_events(db: Session = Depends(get_db)):
    """List all events"""
    events = db.query(Event).order_by(Event.event_date).all()
    return events


@app.get("/events/{event_id}", response_model=EventResponse)
async def get_event(event_id: str, db: Session = Depends(get_db)):
    """Get event by ID"""
    event = db.query(Event).filter(Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


# ==================== SEAT ENDPOINTS ====================

@app.post("/events/{event_id}/seats", response_model=SeatResponse, status_code=201)
async def create_seat(
        event_id: str,
        seat: SeatCreate,
        db: Session = Depends(get_db)
):
    """Create a seat for an event"""
    event = db.query(Event).filter(Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    db_seat = Seat(
        event_id=event_id,
        seat_number=seat.seat_number,
        price=seat.price
    )
    db.add(db_seat)
    db.commit()
    db.refresh(db_seat)
    return db_seat


@app.get("/events/{event_id}/seats", response_model=List[SeatResponse])
async def list_seats(event_id: str, db: Session = Depends(get_db)):
    """List all seats for an event"""
    seats = db.query(Seat).filter(Seat.event_id == event_id).order_by(Seat.seat_number).all()
    return seats


@app.get("/seats/{seat_id}", response_model=SeatResponse)
async def get_seat(seat_id: str, db: Session = Depends(get_db)):
    """Get seat by ID"""
    seat = db.query(Seat).filter(Seat.seat_id == seat_id).first()
    if not seat:
        raise HTTPException(status_code=404, detail="Seat not found")
    return seat


# ==================== BOOKING ENDPOINTS ====================

@app.post("/bookings", response_model=BookingResponse, status_code=201)
async def create_booking(booking: BookingCreate, db: Session = Depends(get_db)):
    """
    Book a seat with double-booking prevention using:
    1. Distributed lock (Redis)
    2. Row-level lock (PostgreSQL)
    3. Optimistic concurrency control (version number)
    """
    lock_key = f"seat:{booking.event_id}:{booking.seat_id}"

    try:
        # Acquire distributed lock to prevent concurrent access
        with acquire_lock(lock_key, timeout=10):

            # Get seat with row-level lock
            seat = db.query(Seat).filter(
                and_(
                    Seat.seat_id == booking.seat_id,
                    Seat.event_id == booking.event_id
                )
            ).with_for_update().first()

            if not seat:
                raise HTTPException(status_code=404, detail="Seat not found")

            # Check seat availability
            if seat.status != SeatStatus.AVAILABLE:
                raise HTTPException(
                    status_code=409,
                    detail=f"Seat is already {seat.status.value}"
                )

            # Update seat with optimistic locking
            current_version = seat.version
            update_count = db.query(Seat).filter(
                and_(
                    Seat.seat_id == seat.seat_id,
                    Seat.version == current_version
                )
            ).update({
                "status": SeatStatus.BOOKED,
                "booked_by": booking.user_id,
                "version": Seat.version + 1
            }, synchronize_session=False)

            if update_count == 0:
                db.rollback()
                raise HTTPException(
                    status_code=409,
                    detail="Booking conflict detected. Please try again."
                )

            # Create booking record
            db_booking = Booking(
                user_id=booking.user_id,
                event_id=booking.event_id,
                seat_id=booking.seat_id,
                total_amount=seat.price,
                status=BookingStatus.CONFIRMED
            )

            db.add(db_booking)
            db.commit()
            db.refresh(db_booking)

            return db_booking

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Booking failed: {str(e)}")


@app.get("/bookings/{booking_id}", response_model=BookingResponse)
async def get_booking(booking_id: str, db: Session = Depends(get_db)):
    """Get booking by ID"""
    booking = db.query(Booking).filter(Booking.booking_id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    return booking


@app.get("/users/{user_id}/bookings", response_model=List[BookingResponse])
async def list_user_bookings(user_id: str, db: Session = Depends(get_db)):
    """List all bookings for a user"""
    bookings = db.query(Booking).filter(
        Booking.user_id == user_id
    ).order_by(Booking.created_at.desc()).all()
    return bookings


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
