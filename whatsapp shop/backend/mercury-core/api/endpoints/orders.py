from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ...models.order import Order, OrderStatus
from ...schemas.order import (
    OrderCreate, 
    OrderResponse, 
    OrderUpdate, 
    OrderStatusUpdate,
    OrderListResponse
)
from ...services.order_service import OrderService, get_order_service
from ...core.security import get_current_user
from ...db.session import get_db
from ...utils.logger import logger

router = APIRouter()

def convert_to_response(order: Order) -> OrderResponse:
    """Convert database model to response schema"""
    return OrderResponse(
        id=order.id,
        customer_id=order.customer_id,
        status=order.status,
        subtotal=order.subtotal,
        tax_amount=order.tax_amount,
        discount_amount=order.discount_amount,
        total=order.total,
        currency=order.currency,
        notes=order.notes,
        created_at=order.created_at,
        updated_at=order.updated_at,
        items=[
            {
                "id": item.id,
                "product_id": item.product_id,
                "product_type": item.product_type,
                "name": item.name,
                "quantity": item.quantity,
                "unit_price": item.unit_price,
                "total_price": item.total_price,
                "tax_rate": item.tax_rate,
                "discount_amount": item.discount_amount
            } for item in order.items
        ]
    )

@router.post("/", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    order_data: OrderCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    order_service: OrderService = Depends(get_order_service)
):
    """
    Create a new order
    """
    try:
        order = order_service.create_order(order_data, current_user.id)
        return convert_to_response(order)
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Error creating order: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error creating order"
        )

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    order_service: OrderService = Depends(get_order_service)
):
    """
    Get order by ID
    """
    order = order_service.get_order(order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )
    
    # Authorization check - only the customer or admin can view the order
    if not current_user.is_admin and str(order.customer_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this order"
        )
    
    return convert_to_response(order)

@router.get("/", response_model=OrderListResponse)
async def list_orders(
    skip: int = 0,
    limit: int = 100,
    status: Optional[OrderStatus] = None,
    customer_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    order_service: OrderService = Depends(get_order_service)
):
    """
    List orders with optional filtering
    """
    # Non-admin users can only see their own orders
    if not current_user.is_admin:
        if customer_id and str(customer_id) != str(current_user.id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to view other users' orders"
            )
        customer_id = str(current_user.id)
    
    orders = order_service.get_orders(
        skip=skip,
        limit=limit,
        status=status,
        customer_id=customer_id
    )
    
    total = db.query(Order).count()
    
    return {
        "items": [convert_to_response(order) for order in orders],
        "total": total,
        "skip": skip,
        "limit": limit
    }

@router.patch("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(
    order_id: str,
    status_update: OrderStatusUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    order_service: OrderService = Depends(get_order_service)
):
    """
    Update order status
    """
    # Only admin or staff can update order status
    if not current_user.is_admin and not current_user.is_staff:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update order status"
        )
    
    try:
        order = order_service.update_order_status(
            order_id=order_id,
            status_update=status_update,
            user_id=current_user.id
        )
        return convert_to_response(order)
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Error updating order status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error updating order status"
        )

@router.patch("/{order_id}", response_model=OrderResponse)
async def update_order(
    order_id: str,
    order_data: OrderUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    order_service: OrderService = Depends(get_order_service)
):
    """
    Update order details
    """
    # Only admin or staff can update orders
    if not current_user.is_admin and not current_user.is_staff:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update orders"
        )
    
    try:
        # Implementation for updating order details would go here
        # This is a simplified example
        db_order = order_service.get_order(order_id)
        if not db_order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
            
        # Update order fields
        update_data = order_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_order, field, value)
            
        db_order.updated_by = current_user.id
        db.commit()
        db.refresh(db_order)
        
        return convert_to_response(db_order)
        
    except HTTPException as he:
        raise he
    except Exception as e:
        db.rollback()
        logger.error(f"Error updating order: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error updating order"
        )
