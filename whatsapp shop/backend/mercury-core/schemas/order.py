from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from decimal import Decimal

from app.models.order import OrderStatus, OrderSource

class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)

class OrderCreate(BaseModel):
    customer_id: int
    items: List[OrderItemCreate]
    source: Optional[OrderSource] = OrderSource.WEB
    delivery_address: Optional[str] = None

class OrderItemResponse(BaseModel):
    id: int
    product_id: int
    product_name: str
    quantity: int
    unit_price: Decimal
    subtotal: Decimal
    
    class Config:
        from_attributes = True

class OrderResponse(BaseModel):
    id: int
    order_number: str
    customer_id: int
    status: OrderStatus
    source: OrderSource
    subtotal: Decimal
    total_amount: Decimal
    payment_reference: Optional[str]
    delivery_address: Optional[str]
    expires_at: Optional[datetime]
    created_at: datetime
    items: List[OrderItemResponse]
    
    class Config:
        from_attributes = True

class OrderStatusUpdate(BaseModel):
    new_status: OrderStatus
    reason: Optional[str] = None

class OrderUpdate(BaseModel):
    delivery_address: Optional[str] = None
    # Add other updatable fields as needed