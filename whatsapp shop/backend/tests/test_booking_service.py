import asyncio
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base
from app.models.product import Product, ProductType
from app.models.user import User
from app.services.booking_service import BookingService
from app.models.booking import BookingStatus


def setup_in_memory_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    return SessionLocal()


def test_create_booking():
    db = setup_in_memory_db()

    # create a user and a product
    user = User(phone_number="+1234567890", name="Test User")
    product = Product(name="Test Service", product_type=ProductType.SERVICE, selling_price=10.0, requires_booking=True)

    db.add(user)
    db.add(product)
    db.commit()
    db.refresh(user)
    db.refresh(product)

    data = {
        "customer_id": user.id,
        "service_id": product.id,
        "start_time": datetime.utcnow(),
        "end_time": datetime.utcnow() + timedelta(hours=1),
        "notes": "Please be on time",
    }

    booking = BookingService.create_booking(db, data)

    assert booking is not None
    assert booking.status == BookingStatus.PENDING
    assert booking.product_id == product.id
    assert booking.customer_id == user.id


async def test_confirm_and_cancel_booking():
    db = setup_in_memory_db()

    # create a user and a product
    user = User(phone_number="+1234567890", name="Async User")
    product = Product(name="Async Service", product_type=ProductType.SERVICE, selling_price=20.0, requires_booking=True)

    db.add(user)
    db.add(product)
    db.commit()
    db.refresh(user)
    db.refresh(product)

    data = {
        "customer_id": user.id,
        "service_id": product.id,
        "start_time": datetime.utcnow(),
        "end_time": datetime.utcnow() + timedelta(hours=2),
        "notes": "Async booking",
    }

    booking = BookingService.create_booking(db, data)

    # Confirm booking (CalendarService should be in dry-run mode in tests)
    booking = await BookingService.confirm_booking(db, booking, user_id=str(user.id))

    assert booking.status == BookingStatus.CONFIRMED
    assert booking.calendar_event_id is not None

    # Cancel booking
    booking = await BookingService.cancel_booking(db, booking)
    assert booking.status == BookingStatus.CANCELLED


if __name__ == "__main__":
    # Allow running tests directly
    test_create_booking()
    asyncio.run(test_confirm_and_cancel_booking())
