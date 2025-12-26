from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, validator
from datetime import datetime
from enum import Enum

router = APIRouter(prefix="/orders", tags=["orders"])

# Enums
class OrderStatus(str, Enum):
    DRAFT = "draft"
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"

class PaymentStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"

# Pydantic models
class OrderItemBase(BaseModel):
    product_id: int
    quantity: int = Field(..., gt=0, description="Quantity must be greater than zero")
    unit_price: float = Field(..., gt=0, description="Price must be greater than zero")
    discount: float = Field(0.0, ge=0, description="Discount must be zero or positive")
    tax_rate: float = Field(0.0, ge=0, le=100, description="Tax rate must be between 0 and 100")

class OrderBase(BaseModel):
    customer_id: int
    status: OrderStatus = OrderStatus.PENDING
    payment_status: PaymentStatus = PaymentStatus.PENDING
    shipping_address: Dict[str, Any]
    billing_address: Optional[Dict[str, Any]] = None
    customer_note: Optional[str] = None
    discount_code: Optional[str] = None
    discount_amount: float = 0.0
    shipping_method: str
    shipping_cost: float = 0.0
    tax_amount: float = 0.0
    total_amount: float = 0.0
    currency: str = "USD"

class OrderCreate(OrderBase):
    items: List[OrderItemBase]

class OrderUpdate(BaseModel):
    status: Optional[OrderStatus] = None
    payment_status: Optional[PaymentStatus] = None
    tracking_number: Optional[str] = None
    shipping_carrier: Optional[str] = None
    customer_note: Optional[str] = None

class OrderResponse(OrderBase):
    id: int
    order_number: str
    created_at: datetime
    updated_at: datetime
    items: List[OrderItemBase]
    tracking_number: Optional[str] = None
    shipping_carrier: Optional[str] = None

    class Config:
        orm_mode = True

# Mock database
orders_db = {}
order_id_counter = 1
order_number_counter = 1000

# Helper functions
def generate_order_number() -> str:
    global order_number_counter
    order_number = f"ORD-{order_number_counter}"
    order_number_counter += 1
    return order_number

# API Endpoints
@router.post("/", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(order: OrderCreate):
    global order_id_counter
    
    # In a real app, this would be a database transaction
    order_dict = order.dict()
    order_dict["id"] = order_id_counter
    order_dict["order_number"] = generate_order_number()
    order_dict["created_at"] = datetime.utcnow()
    order_dict["updated_at"] = datetime.utcnow()
    
    # Calculate totals (in a real app, this would be more sophisticated)
    subtotal = sum(item["unit_price"] * item["quantity"] for item in order_dict["items"])
    order_dict["total_amount"] = subtotal + order_dict["shipping_cost"] + order_dict["tax_amount"] - order_dict["discount_amount"]
    
    orders_db[order_id_counter] = order_dict
    order_id_counter += 1
    
    return order_dict

@router.get("/", response_model=List[OrderResponse])
async def list_orders(
    skip: int = 0,
    limit: int = 50,
    status: Optional[OrderStatus] = None,
    customer_id: Optional[int] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None
):
    # In a real app, this would be a database query with filters
    filtered_orders = list(orders_db.values())
    
    if status:
        filtered_orders = [o for o in filtered_orders if o["status"] == status]
    if customer_id:
        filtered_orders = [o for o in filtered_orders if o["customer_id"] == customer_id]
    if start_date:
        filtered_orders = [o for o in filtered_orders if o["created_at"] >= start_date]
    if end_date:
        filtered_orders = [o for o in filtered_orders if o["created_at"] <= end_date]
    
    return filtered_orders[skip : skip + limit]

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: int):
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    return orders_db[order_id]

@router.put("/{order_id}", response_model=OrderResponse)
async def update_order(order_id: int, order_update: OrderUpdate):
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # In a real app, this would be a database operation with proper validation
    order = orders_db[order_id]
    update_data = order_update.dict(exclude_unset=True)
    
    # Update only the fields that were provided
    for field, value in update_data.items():
        if value is not None:
            order[field] = value
    
    order["updated_at"] = datetime.utcnow()
    
    return order

@router.post("/{order_id}/cancel", response_model=OrderResponse)
async def cancel_order(order_id: int):
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    
    order = orders_db[order_id]
    
    # Check if order can be cancelled
    if order["status"] in [OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.REFUNDED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel order with status {order['status']}"
        )
    
    # Update order status
    order["status"] = OrderStatus.CANCELLED
    order["updated_at"] = datetime.utcnow()
    
    return order

@router.get("/customer/{customer_id}", response_model=List[OrderResponse])
async def get_customer_orders(
    customer_id: int,
    skip: int = 0,
    limit: int = 50
):
    # In a real app, this would be a database query
    customer_orders = [o for o in orders_db.values() if o["customer_id"] == customer_id]
    return customer_orders[skip : skip + limit]
