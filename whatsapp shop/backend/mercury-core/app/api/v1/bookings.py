from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ...core.auth import get_current_user
from ...services.calendar import CalendarService, CalendarEvent
from ...models.booking import Booking, BookingStatus
from ...models.user import User
from ...db.session import get_db

router = APIRouter()

# Initialize calendar service with paths from environment variables
import os
CALENDAR_CREDENTIALS_PATH = os.getenv("GOOGLE_CALENDAR_CREDENTIALS_PATH", "google_credentials.json")
CALENDAR_TOKEN_PATH = os.getenv("GOOGLE_CALENDAR_TOKEN_PATH", "token.json")

calendar_service = CalendarService()

class BookingCreate(BaseModel):
    service_id: int
    customer_name: str
    customer_phone: str
    customer_email: str
    start_time: datetime
    end_time: datetime
    notes: Optional[str] = None

class BookingResponse(BaseModel):
    id: int
    service_id: int
    customer_name: str
    customer_phone: str
    customer_email: str
    start_time: datetime
    end_time: datetime
    status: str
    calendar_event_id: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class AvailableSlot(BaseModel):
    start: datetime
    end: datetime

@router.post("/bookings/", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    booking: BookingCreate,
    db=Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Create a new service booking
    """
    # Check if the time slot is available
    available_slots = await calendar_service.get_available_slots(
        time_min=booking.start_time - timedelta(minutes=30),
        time_max=booking.end_time + timedelta(minutes=30),
        slot_duration_minutes=int((booking.end_time - booking.start_time).total_seconds() / 60)
    )
    
    # Check if the requested slot is available
    slot_available = any(
        slot['start'] <= booking.start_time and slot['end'] >= booking.end_time
        for slot in available_slots
    )
    
    if not slot_available:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The requested time slot is not available"
        )
    
    # Create calendar event
    calendar_event = CalendarEvent(
        summary=f"Service Booking - {booking.customer_name}",
        description=f"Customer: {booking.customer_name}\nPhone: {booking.customer_phone}\nEmail: {booking.customer_email}\nNotes: {booking.notes or 'None'}",
        start_time=booking.start_time,
        end_time=booking.end_time,
        attendees=[{"email": booking.customer_email}]
    )
    
    try:
        # Create calendar event
        event = await calendar_service.create_event(calendar_event)
        
        # Create booking record
        db_booking = Booking(
            service_id=booking.service_id,
            customer_name=booking.customer_name,
            customer_phone=booking.customer_phone,
            customer_email=booking.customer_email,
            start_time=booking.start_time,
            end_time=booking.end_time,
            status=BookingStatus.CONFIRMED,
            calendar_event_id=event.get('id'),
            notes=booking.notes,
            created_by=current_user.id
        )
        
        db.add(db_booking)
        db.commit()
        db.refresh(db_booking)
        
        return db_booking
        
    except Exception as e:
        # If booking creation fails, delete the calendar event
        if 'event' in locals():
            await calendar_service.cancel_event(event['id'])
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create booking: {str(e)}"
        )

@router.get("/bookings/available-slots/", response_model=List[AvailableSlot])
async def get_available_slots(
    start_time: Optional[datetime] = None,
    end_time: Optional[datetime] = None,
    duration_minutes: int = 60,
    current_user: User = Depends(get_current_user)
):
    """
    Get available time slots for service booking
    """
    if not start_time:
        start_time = datetime.utcnow()
    if not end_time:
        end_time = start_time + timedelta(days=14)  # Default to 2 weeks ahead
    
    try:
        slots = await calendar_service.get_available_slots(
            time_min=start_time,
            time_max=end_time,
            slot_duration_minutes=duration_minutes
        )
        return slots
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch available slots: {str(e)}"
        )

@router.get("/bookings/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: int,
    db=Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get booking details by ID
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if the user has permission to view this booking
    if booking.created_by != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this booking"
        )
    
    return booking

@router.put("/bookings/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: int,
    db=Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Cancel a booking
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if the user has permission to cancel this booking
    if booking.created_by != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to cancel this booking"
        )
    
    # Cancel the calendar event
    if booking.calendar_event_id:
        try:
            await calendar_service.cancel_event(booking.calendar_event_id)
        except Exception as e:
            # Log the error but continue with the cancellation
            print(f"Failed to cancel calendar event: {str(e)}")
    
    # Update booking status
    booking.status = BookingStatus.CANCELLED
    booking.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(booking)
    
    return booking
