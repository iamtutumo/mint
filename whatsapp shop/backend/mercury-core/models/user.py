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
    __table_args__ = {'extend_existing': True}
    
    
    phone_number = Column(String(20), unique=True, index=True, nullable=False)
    name = Column(String(100))
    email = Column(String(100))
    hashed_password = Column(String(256), nullable=True)
    role = Column(SQLEnum(UserRole), default=UserRole.CUSTOMER)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    whatsapp_verified = Column(Boolean, default=False)
    
    # Relationships
    # orders = relationship("models.order.Order", back_populates="customer")  # Commented out to avoid dependency issue
    # bookings = relationship("models.booking.Booking", back_populates="customer")  # Commented out to avoid dependency issue
    # surveys = relationship("models.survey.Survey", back_populates="customer")  # Commented out to avoid dependency issue


# Pydantic models used by auth endpoints
from pydantic import BaseModel
from typing import Optional

class UserCreate(BaseModel):
    email: str
    password: str
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    is_superuser: Optional[bool] = False

class UserInDB(BaseModel):
    id: int
    email: Optional[str] = None
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    is_active: bool = True
    is_superuser: bool = False
    hashed_password: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    email: Optional[str] = None
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    is_active: bool = True
    is_superuser: bool = False

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
