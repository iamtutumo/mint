from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from sqlalchemy.orm import Session

from app.db.session import get_db
from models.order import Order
from schemas.order import OrderCreate, OrderResponse, OrderUpdate, OrderStatusUpdate
from app.services.order_service import OrderService
from app.core.auth import get_current_user

router = APIRouter(prefix="/orders", tags=["orders"])

@router.post("/", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    order: OrderCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Create a new order"""
    try:
        order_service = OrderService(db)
        db_order = order_service.create_order(order, current_user.id)
        return OrderResponse.from_orm(db_order)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create order: {str(e)}")

@router.get("/", response_model=List[OrderResponse])
async def list_orders(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    status: Optional[str] = None,
    customer_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """List orders with optional filters"""
    try:
        order_service = OrderService(db)
        orders = order_service.get_orders(skip=skip, limit=limit, status=status, customer_id=customer_id)
        return [OrderResponse.from_orm(order) for order in orders]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list orders: {str(e)}")

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: str, db: Session = Depends(get_db)):
    """Get order by ID"""
    try:
        order_service = OrderService(db)
        order = order_service.get_order(order_id)
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        return OrderResponse.from_orm(order)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get order: {str(e)}")

@router.put("/{order_id}", response_model=OrderResponse)
async def update_order(order_id: str, order_update: OrderUpdate, db: Session = Depends(get_db)):
    """Update order"""
    try:
        order_service = OrderService(db)
        # Assuming update method exists
        db_order = order_service.update_order(order_id, order_update)
        if not db_order:
            raise HTTPException(status_code=404, detail="Order not found")
        return OrderResponse.from_orm(db_order)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update order: {str(e)}")

@router.put("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(order_id: str, status_update: OrderStatusUpdate, db: Session = Depends(get_db)):
    """Update order status"""
    try:
        order_service = OrderService(db)
        db_order = order_service.update_order_status(order_id, status_update.status)
        if not db_order:
            raise HTTPException(status_code=404, detail="Order not found")
        return OrderResponse.from_orm(db_order)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update order status: {str(e)}")
