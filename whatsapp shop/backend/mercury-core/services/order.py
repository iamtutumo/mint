from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
import uuid

from app.models.order import Order, OrderStatus, OrderSource
from app.models.order_item import OrderItem
from app.models.state_transition import OrderStateTransition
from app.models.product import Product
from app.fsm.order_states import can_transition
from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

class OrderService:
    
    @staticmethod
    def create_order(
        db: Session,
        customer_id: int,
        items: list,
        source: OrderSource = OrderSource.WEB,
        delivery_address: Optional[str] = None
    ) -> Order:
        """Create new order"""
        
        # Generate order number
        order_number = f"ORD-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        
        # Calculate totals
        subtotal = 0
        order_items = []
        
        for item in items:
            product = db.query(Product).filter(Product.id == item["product_id"]).first()
            if not product:
                raise ValueError(f"Product {item['product_id']} not found")
            
            quantity = item["quantity"]
            unit_price = product.selling_price
            item_subtotal = unit_price * quantity
            subtotal += item_subtotal
            
            order_item = OrderItem(
                product_id=product.id,
                product_name=product.name,
                product_sku=product.sku,
                quantity=quantity,
                unit_price=unit_price,
                subtotal=item_subtotal
            )
            order_items.append(order_item)
        
        # Create order
        expires_at = datetime.utcnow() + timedelta(hours=settings.ORDER_EXPIRY_HOURS)
        
        order = Order(
            order_number=order_number,
            customer_id=customer_id,
            status=OrderStatus.PENDING_PAYMENT,
            source=source,
            subtotal=subtotal,
            total_amount=subtotal,
            delivery_address=delivery_address,
            expires_at=expires_at
        )
        
        db.add(order)
        db.flush()
        
        for order_item in order_items:
            order_item.order_id = order.id
            db.add(order_item)
        
        db.commit()
        db.refresh(order)
        
        logger.info(f"Order created: {order_number}")
        return order
    
    @staticmethod
    def transition_order_state(
        db: Session,
        order_id: int,
        new_state: OrderStatus,
        performed_by: str,
        reason: Optional[str] = None
    ) -> Order:
        """Transition order to new state"""
        
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise ValueError("Order not found")
        
        # Check if transition is valid
        if not can_transition(order.status, new_state):
            raise ValueError(f"Invalid transition from {order.status} to {new_state}")
        
        old_state = order.status
        order.status = new_state
        
        # Record transition
        transition = OrderStateTransition(
            order_id=order.id,
            from_state=old_state,
            to_state=new_state,
            reason=reason,
            performed_by=performed_by
        )
        db.add(transition)
        
        # Update timestamps
        if new_state == OrderStatus.CONFIRMED:
            order.payment_confirmed_at = datetime.utcnow()
        elif new_state == OrderStatus.DISPATCHED:
            order.dispatched_at = datetime.utcnow()
        elif new_state == OrderStatus.COMPLETED:
            order.completed_at = datetime.utcnow()
        
        db.commit()
        db.refresh(order)
        
        logger.info(f"Order {order.order_number} transitioned: {old_state} -> {new_state}")
        return order
    
    @staticmethod
    def get_order_by_number(db: Session, order_number: str) -> Optional[Order]:
        """Get order by order number"""
        return db.query(Order).filter(Order.order_number == order_number).first()
    
    @staticmethod
    def get_customer_orders(db: Session, customer_id: int, skip: int = 0, limit: int = 100):
        """Get orders for a customer"""
        return db.query(Order).filter(Order.customer_id == customer_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def expire_old_orders(db: Session) -> int:
        """Expire orders that have passed their expiry time"""
        expired_orders = db.query(Order).filter(
            Order.status.in_([OrderStatus.PENDING_PAYMENT, OrderStatus.PAYMENT_SUBMITTED]),
            Order.expires_at < datetime.utcnow()
        ).all()
        
        count = 0
        for order in expired_orders:
            OrderService.transition_order_state(
                db, order.id, OrderStatus.EXPIRED, "system", "Order expired"
            )
            count += 1
        
        logger.info(f"Expired {count} orders")
        return count