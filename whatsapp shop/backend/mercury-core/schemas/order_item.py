from enum import Enum
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, validator
from datetime import datetime

class OrderItemType(str, Enum):
    PRODUCT = "product"
    DISCOUNT = "discount"
    TAX = "tax"
    SHIPPING = "shipping"
    FEE = "fee"

class OrderItemStatus(str, Enum):
    PENDING = "pending"
    FULFILLED = "fulfilled"
    PARTIALLY_FULFILLED = "partially_fulfilled"
    CANCELLED = "cancelled"
    RETURNED = "returned"

class OrderItemBase(BaseModel):
    product_id: str
    product_type: str
    name: str
    sku: Optional[str] = None
    quantity: float = Field(..., gt=0)
    unit_price: float = Field(..., ge=0)
    tax_rate: float = Field(0.0, ge=0, le=100)
    discount_amount: float = Field(0.0, ge=0)
    metadata: Optional[Dict[str, Any]] = None

class OrderItemCreate(OrderItemBase):
    order_id: str

class OrderItemUpdate(BaseModel):
    quantity: Optional[float] = Field(None, gt=0)
    unit_price: Optional[float] = Field(None, ge=0)
    tax_rate: Optional[float] = Field(None, ge=0, le=100)
    discount_amount: Optional[float] = Field(None, ge=0)
    status: Optional[OrderItemStatus] = None
    metadata: Optional[Dict[str, Any]] = None

class OrderItem(OrderItemBase):
    id: str
    order_id: str
    status: OrderItemStatus = OrderItemStatus.PENDING
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class OrderItemList(BaseModel):
    items: List[OrderItem]
    total: int
