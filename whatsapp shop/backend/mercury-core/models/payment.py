from sqlalchemy import Column, Integer, ForeignKey, Numeric, String, Enum as SQLEnum, DateTime, Text
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    SUBMITTED = "submitted"
    VERIFIED = "verified"
    REJECTED = "rejected"

class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    BANK_TRANSFER = "bank_transfer"
    MOBILE_MONEY = "mobile_money"
    CARD = "card"

class Payment(BaseModel):
    __table_args__ = {'extend_existing': True}
    __tablename__ = "payments"
    
    
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    payment_method = Column(SQLEnum(PaymentMethod), nullable=False)
    payment_reference = Column(String(100), unique=True, index=True)
    status = Column(SQLEnum(PaymentStatus), default=PaymentStatus.PENDING)
    
    verified_at = Column(DateTime)
    verified_by = Column(String(20))
    rejection_reason = Column(Text)
    
    notes = Column(Text)
    
    # Relationships
    order = relationship("Order", back_populates="payments")