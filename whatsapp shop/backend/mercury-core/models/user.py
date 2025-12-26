from sqlalchemy import Column, String, Boolean, Enum as SQLEnum
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class UserRole(str, enum.Enum):
    OWNER = "owner"
    CUSTOMER = "customer"
    STAFF = "staff"

class User(BaseModel):
    __tablename__ = "users"
    
    phone_number = Column(String(20), unique=True, index=True, nullable=False)
    name = Column(String(100))
    email = Column(String(100))
    role = Column(SQLEnum(UserRole), default=UserRole.CUSTOMER)
    is_active = Column(Boolean, default=True)
    whatsapp_verified = Column(Boolean, default=False)
    
    # Relationships
    orders = relationship("Order", back_populates="customer")
    bookings = relationship("Booking", back_populates="customer")
    surveys = relationship("Survey", back_populates="customer")