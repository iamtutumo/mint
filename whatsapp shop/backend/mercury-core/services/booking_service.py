from typing import List, Optional, Dict, Any
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.booking import Booking, BookingStatus
from app.models.product import Product
from app.core.logging import setup_logging
from app.services.calendar import CalendarService, CalendarEvent

logger = setup_logging()

class BookingService:
    @staticmethod
    def get_booking(db: Session, booking_id: int) -> Optional[Booking]:
        return db.query(Booking).filter(Booking.id == booking_id).first()

    @staticmethod
    def list_bookings(db: Session, skip: int = 0, limit: int = 50) -> List[Booking]:
        return db.query(Booking).offset(skip).limit(limit).all()

    @staticmethod
    def create_booking(db: Session, data: Dict[str, Any]) -> Booking:
        # Validate product exists
        service_id = data.get("service_id") or data.get("product_id")
        if not service_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product/service id is required")
        product = db.query(Product).filter(Product.id == service_id).first()
        if not product:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product/service not found")

        booking = Booking(
            booking_number=f"BK-{int(datetime.utcnow().timestamp())}",
            customer_id=data.get("customer_id"),
            product_id=product.id,
            scheduled_start=data.get("start_time"),
            scheduled_end=data.get("end_time"),
            customer_notes=data.get("notes"),
            requires_payment=data.get("requires_payment", "no"),
            amount=data.get("amount", 0),
            payment_status=data.get("payment_status", "pending"),
            status=BookingStatus.PENDING
        )

        db.add(booking)
        db.commit()
        db.refresh(booking)

        logger.info(f"Created booking {booking.booking_number} for product {product.id}")
        return booking

    @staticmethod
    async def confirm_booking(db: Session, booking: Booking, user_id: str) -> Booking:
        # Create calendar event via CalendarService
        cal = CalendarService()
        event = CalendarEvent(
            summary=f"Booking {booking.booking_number}",
            description=booking.customer_notes or "",
            start_time=booking.scheduled_start,
            end_time=booking.scheduled_end,
            timezone="UTC",
            attendees=[],
            metadata={"booking_id": booking.id}
        )
        result = await cal.create_event(event)

        # Save event id and update status
        booking.calendar_event_id = result.get("id") or result.get("eventId") or str(result)
        booking.status = BookingStatus.CONFIRMED
        booking.confirmed_at = datetime.utcnow()
        booking.confirmed_by = user_id

        db.commit()
        db.refresh(booking)
        logger.info(f"Confirmed booking {booking.booking_number} with calendar id {booking.calendar_event_id}")
        return booking

    @staticmethod
    async def cancel_booking(db: Session, booking: Booking) -> Booking:
        # Cancel calendar event if present
        if booking.calendar_event_id:
            cal = CalendarService()
            try:
                await cal.cancel_event(booking.calendar_event_id)
            except Exception:
                logger.warning(f"Failed to cancel calendar event {booking.calendar_event_id}")

        booking.status = BookingStatus.CANCELLED
        db.commit()
        db.refresh(booking)

        logger.info(f"Cancelled booking {booking.booking_number}")
        return booking
