from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field, HttpUrl, validator
from datetime import datetime

class PaymentStatus(str, Enum):
    PENDING = "pending"
    AUTHORIZED = "authorized"
    PAID = "paid"
    PARTIALLY_REFUNDED = "partially_refunded"
    REFUNDED = "refunded"
    VOIDED = "voided"
    FAILED = "failed"

class PaymentMethod(str, Enum):
    CASH = "cash"
    CREDIT_CARD = "credit_card"
    DEBIT_CARD = "debit_card"
    BANK_TRANSFER = "bank_transfer"
    PAYPAL = "paypal"
    STRIPE = "stripe"
    MOBILE_MONEY = "mobile_money"
    OTHER = "other"

class PaymentBase(BaseModel):
    order_id: str
    amount: float = Field(..., gt=0)
    currency: str = Field("USD", min_length=3, max_length=3)
    payment_method: PaymentMethod
    transaction_id: Optional[str] = None
    status: PaymentStatus = PaymentStatus.PENDING
    payment_date: Optional[datetime] = None
    payment_details: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class PaymentCreate(PaymentBase):
    pass

class PaymentUpdate(BaseModel):
    status: Optional[PaymentStatus] = None
    transaction_id: Optional[str] = None
    payment_date: Optional[datetime] = None
    payment_details: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class Payment(PaymentBase):
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class PaymentRefund(BaseModel):
    amount: float = Field(..., gt=0)
    reason: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class PaymentMethodCreate(BaseModel):
    name: str
    description: Optional[str] = None
    is_active: bool = True
    requires_online_processing: bool = False
    metadata: Optional[Dict[str, Any]] = None

class PaymentMethodUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None
    metadata: Optional[Dict[str, Any]] = None

class PaymentMethodSchema(PaymentMethodCreate):
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
