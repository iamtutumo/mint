from sqlalchemy import Column, Integer, ForeignKey, String, DateTime, Enum as SQLEnum, Text, Numeric
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class BookingStatus(str, enum.Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    NO_SHOW = "no_show"

class Booking(BaseModel):
    __tablename__ = "bookings"
    
    booking_number = Column(String(50), unique=True, index=True, nullable=False)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    
    status = Column(SQLEnum(BookingStatus), default=BookingStatus.PENDING)
    
    # Schedule
    scheduled_start = Column(DateTime, nullable=False)
    scheduled_end = Column(DateTime, nullable=False)
    
    # Google Calendar
    calendar_event_id = Column(String(100), unique=True)
    
    # Payment
    requires_payment = Column(String(10), default="no")
    amount = Column(Numeric(10, 2), default=0)
    payment_status = Column(String(20), default="pending")
    
    # Details
    customer_notes = Column(Text)
    owner_notes = Column(Text)
    
    confirmed_at = Column(DateTime)
    confirmed_by = Column(String(20))
    
    # Relationships
    customer = relationship("User", back_populates="bookings")
    product = relationship("Product")