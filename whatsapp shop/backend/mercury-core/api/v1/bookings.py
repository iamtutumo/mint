from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from app.schemas.booking import BookingCreate, BookingResponse, BookingList
from app.services.booking_service import BookingService
from app.db.session import get_db
from app.core.auth import get_current_user

router = APIRouter(prefix="/bookings", tags=["bookings"])

@router.post("/", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    booking_in: BookingCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    booking = BookingService.create_booking(db, booking_in.dict())
    return booking

@router.get("/", response_model=List[BookingResponse])
async def list_bookings(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    bookings = BookingService.list_bookings(db, skip=skip, limit=limit)
    return bookings

@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(booking_id: int, db: Session = Depends(get_db)):
    booking = BookingService.get_booking(db, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    return booking

@router.post("/{booking_id}/confirm", response_model=BookingResponse)
async def confirm_booking(booking_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    booking = BookingService.get_booking(db, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    booking = await BookingService.confirm_booking(db, booking, user_id=str(current_user.get("id")))
    return booking

@router.post("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(booking_id: int, db: Session = Depends(get_db)):
    booking = BookingService.get_booking(db, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    booking = await BookingService.cancel_booking(db, booking)
    return booking
