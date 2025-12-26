from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from ..models.order import Order, OrderStatus
from ..models.order_item import OrderItem
from ..models.product import Product, ProductType
from ..models.inventory import InventoryTransaction, TransactionType
from ..schemas.order import OrderCreate, OrderUpdate, OrderStatusUpdate
from ..schemas.order_item import OrderItemCreate, OrderItemType
from ..core.security import get_current_user
from ..db.session import SessionLocal
from ..utils.logger import logger

class OrderService:
    def __init__(self, db: Session):
        self.db = db

    def get_order(self, order_id: str) -> Optional[Order]:
        """Retrieve an order by ID"""
        return self.db.query(Order).filter(Order.id == order_id).first()

    def get_orders(
        self, 
        skip: int = 0, 
        limit: int = 100,
        status: Optional[OrderStatus] = None,
        customer_id: Optional[str] = None
    ) -> List[Order]:
        """Retrieve a list of orders with optional filtering"""
        query = self.db.query(Order)
        
        if status:
            query = query.filter(Order.status == status)
        if customer_id:
            query = query.filter(Order.customer_id == customer_id)
            
        return query.offset(skip).limit(limit).all()

    def create_order(self, order_data: OrderCreate, user_id: str) -> Order:
        """Create a new order with order items"""
        db_order = Order(
            customer_id=order_data.customer_id,
            status=OrderStatus.DRAFT,
            subtotal=0,
            tax_amount=0,
            discount_amount=order_data.discount_amount or 0,
            total=0,
            currency=order_data.currency or "USD",
            notes=order_data.notes,
            created_by=user_id,
            updated_by=user_id
        )
        
        self.db.add(db_order)
        self.db.flush()  # Get the order ID for order items
        
        # Process order items
        subtotal = 0
        for item_data in order_data.items:
            product = self.db.query(Product).filter(Product.id == item_data.product_id).first()
            if not product:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Product not found: {item_data.product_id}"
                )
                
            # Calculate item total
            item_total = product.price * item_data.quantity
            subtotal += item_total
            
            # Create order item
            order_item = OrderItem(
                order_id=db_order.id,
                product_id=product.id,
                product_type=product.product_type,
                name=product.name,
                sku=product.sku,
                quantity=item_data.quantity,
                unit_price=product.price,
                total_price=item_total,
                tax_rate=item_data.tax_rate or 0,
                discount_amount=item_data.discount_amount or 0,
                created_by=user_id,
                updated_by=user_id
            )
            self.db.add(order_item)
            
            # Handle inventory for physical products
            if product.product_type == ProductType.PHYSICAL:
                self._update_inventory(
                    product_id=product.id,
                    quantity=-item_data.quantity,  # Negative for sales
                    reference_id=db_order.id,
                    reference_type="order",
                    notes=f"Order {db_order.id}",
                    user_id=user_id
                )
        
        # Calculate order totals
        tax_amount = subtotal * (order_data.tax_rate or 0) / 100
        total = subtotal + tax_amount - (order_data.discount_amount or 0)
        
        # Update order with calculated totals
        db_order.subtotal = subtotal
        db_order.tax_amount = tax_amount
        db_order.total = max(0, total)  # Ensure total is not negative
        db_order.status = OrderStatus.PENDING_PAYMENT
        
        self.db.commit()
        self.db.refresh(db_order)
        return db_order

    def update_order_status(
        self, 
        order_id: str, 
        status_update: OrderStatusUpdate,
        user_id: str
    ) -> Order:
        """Update order status with validation"""
        db_order = self.get_order(order_id)
        if not db_order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
            
        # Validate status transition
        valid_transitions = {
            OrderStatus.DRAFT: [OrderStatus.PENDING_PAYMENT, OrderStatus.CANCELLED],
            OrderStatus.PENDING_PAYMENT: [OrderStatus.PAID, OrderStatus.CANCELLED],
            OrderStatus.PAID: [OrderStatus.PROCESSING, OrderStatus.REFUNDED],
            OrderStatus.PROCESSING: [OrderStatus.SHIPPED, OrderStatus.COMPLETED],
            OrderStatus.SHIPPED: [OrderStatus.DELIVERED, OrderStatus.RETURNED],
            OrderStatus.DELIVERED: [OrderStatus.COMPLETED, OrderStatus.RETURNED],
            OrderStatus.CANCELLED: [],
            OrderStatus.REFUNDED: [],
            OrderStatus.RETURNED: [OrderStatus.REFUNDED]
        }
        
        current_status = db_order.status
        new_status = status_update.status
        
        if new_status not in valid_transitions.get(current_status, []):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status transition from {current_status} to {new_status}"
            )
        
        # Update order status
        db_order.status = new_status
        db_order.updated_by = user_id
        db_order.updated_at = datetime.utcnow()
        
        # Handle status-specific logic
        if new_status == OrderStatus.CANCELLED:
            self._handle_order_cancellation(db_order, user_id)
        elif new_status == OrderStatus.REFUNDED:
            self._handle_order_refund(db_order, user_id)
        
        self.db.commit()
        self.db.refresh(db_order)
        return db_order

    def _update_inventory(
        self,
        product_id: str,
        quantity: int,
        reference_id: str,
        reference_type: str,
        notes: str,
        user_id: str
    ) -> None:
        """Update inventory and create transaction record"""
        # Create inventory transaction
        transaction = InventoryTransaction(
            product_id=product_id,
            quantity=quantity,
            transaction_type=(
                TransactionType.INBOUND if quantity > 0 
                else TransactionType.OUTBOUND
            ),
            reference_id=reference_id,
            reference_type=reference_type,
            notes=notes,
            created_by=user_id,
            updated_by=user_id
        )
        self.db.add(transaction)
        
        # Update product stock
        product = self.db.query(Product).filter(Product.id == product_id).with_for_update().first()
        if product:
            product.stock_quantity = (product.stock_quantity or 0) + quantity
            if product.stock_quantity < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Insufficient stock for product {product_id}"
                )

    def _handle_order_cancellation(self, order: Order, user_id: str) -> None:
        """Handle order cancellation by restoring inventory"""
        if order.status != OrderStatus.CANCELLED:
            return
            
        for item in order.items:
            if item.product_type == ProductType.PHYSICAL:
                self._update_inventory(
                    product_id=item.product_id,
                    quantity=item.quantity,  # Positive to add back to inventory
                    reference_id=order.id,
                    reference_type="order_cancellation",
                    notes=f"Order {order.id} cancellation",
                    user_id=user_id
                )

    def _handle_order_refund(self, order: Order, user_id: str) -> None:
        """Handle order refund and update inventory if needed"""
        if order.status != OrderStatus.REFUNDED:
            return
            
        # For physical products, we might want to restock on refund
        for item in order.items:
            if item.product_type == ProductType.PHYSICAL:
                self._update_inventory(
                    product_id=item.product_id,
                    quantity=item.quantity,  # Positive to add back to inventory
                    reference_id=order.id,
                    reference_type="order_refund",
                    notes=f"Order {order.id} refund",
                    user_id=user_id
                )

# Dependency
def get_order_service(db: Session = Depends(SessionLocal)) -> OrderService:
    return OrderService(db)
