from sqlalchemy import Column, String, Integer, ForeignKey, Enum as SQLEnum, Numeric, Text, DateTime, JSON
from sqlalchemy.orm import relationship
import enum
from datetime import datetime

from app.db.base import BaseModel

class OrderStatus(str, enum.Enum):
    DRAFT = "draft"
    PENDING_PAYMENT = "pending_payment"
    PAYMENT_SUBMITTED = "payment_submitted"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    DISPATCHED = "dispatched"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"

class OrderSource(str, enum.Enum):
    WEB = "web"
    WHATSAPP = "whatsapp"
    MANUAL = "manual"

class Order(BaseModel):
    __tablename__ = "orders"
    __table_args__ = {'extend_existing': True}
    
    
    order_number = Column(String(50), unique=True, index=True, nullable=False)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Status
    status = Column(SQLEnum(OrderStatus), default=OrderStatus.DRAFT, nullable=False, index=True)
    source = Column(SQLEnum(OrderSource), default=OrderSource.WEB)
    
    # Amounts
    subtotal = Column(Numeric(10, 2), nullable=False)
    tax_amount = Column(Numeric(10, 2), default=0)
    discount_amount = Column(Numeric(10, 2), default=0)
    total_amount = Column(Numeric(10, 2), nullable=False)
    
    # Payment
    payment_method = Column(String(50))
    payment_reference = Column(String(100))
    payment_confirmed_at = Column(DateTime)
    
    # Delivery
    delivery_address = Column(Text)
    delivery_notes = Column(Text)
    dispatched_at = Column(DateTime)
    completed_at = Column(DateTime)
    
    # Expiry
    expires_at = Column(DateTime)
    
    # Metadata
    notes = Column(Text)
    metadata_json = Column(JSON, default=dict)
    
    # Relationships
    # customer = relationship("models.user.User", back_populates="orders")  # Commented out to avoid dependency issue
    # items = relationship("models.order_item.OrderItem", back_populates="order", cascade="all, delete-orphan")  # Commented out to avoid dependency issue
    # payments = relationship("models.payment.Payment", back_populates="order")  # Commented out to avoid dependency issue
    # state_transitions = relationship("models.state_transition.OrderStateTransition", back_populates="order")  # Commented out to avoid dependency issue