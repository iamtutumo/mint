from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid

from app.models.payment import Payment
from app.models.order import Order
from app.schemas.payment import PaymentCreate, PaymentUpdate
from app.core.logging import setup_logging

logger = setup_logging()

class PaymentService:
    @staticmethod
    def get_payment(db: Session, payment_id: str) -> Optional[Payment]:
        """Get a payment by ID"""
        return db.query(Payment).filter(Payment.id == payment_id).first()

    @staticmethod
    def get_payments_by_order(db: Session, order_id: int) -> List[Payment]:
        """Get all payments for an order"""
        return db.query(Payment).filter(Payment.order_id == order_id).all()

    @staticmethod
    def create_payment(db: Session, payment_data: PaymentCreate) -> Payment:
        """Create a new payment"""
        # Verify order exists
        order = db.query(Order).filter(Order.id == payment_data.order_id).first()
        if not order:
            raise ValueError(f"Order {payment_data.order_id} not found")

        # Generate payment reference
        payment_reference = f"PAY-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"

        payment = Payment(
            order_id=payment_data.order_id,
            amount=payment_data.amount,
            payment_method=payment_data.payment_method,
            payment_reference=payment_reference,
            status=payment_data.status,
            notes=payment_data.notes
        )

        db.add(payment)
        db.commit()
        db.refresh(payment)

        logger.info(f"Created payment {payment.id} for order {payment_data.order_id}")
        return payment

    @staticmethod
    def update_payment(db: Session, payment_id: str, payment_data: PaymentUpdate) -> Payment:
        """Update a payment"""
        payment = db.query(Payment).filter(Payment.id == payment_id).first()
        if not payment:
            raise ValueError(f"Payment {payment_id} not found")

        update_data = payment_data.dict(exclude_unset=True)

        # Handle status changes
        if 'status' in update_data:
            old_status = payment.status
            new_status = update_data['status']

            if new_status == "verified" and old_status != "verified":
                payment.verified_at = datetime.utcnow()
                # TODO: Set verified_by from current user
            elif new_status == "rejected":
                payment.rejection_reason = update_data.get('rejection_reason')

        for field, value in update_data.items():
            if hasattr(payment, field):
                setattr(payment, field, value)

        db.commit()
        db.refresh(payment)

        logger.info(f"Updated payment {payment_id} status: {old_status} -> {payment.status}")
        return payment

    @staticmethod
    def delete_payment(db: Session, payment_id: str) -> bool:
        """Delete a payment"""
        payment = db.query(Payment).filter(Payment.id == payment_id).first()
        if not payment:
            return False

        # Only allow deletion of pending payments
        if payment.status != "pending":
            raise ValueError("Cannot delete a payment that is not pending")

        db.delete(payment)
        db.commit()

        logger.info(f"Deleted payment {payment_id}")
        return True

    @staticmethod
    def get_payments(
        db: Session,
        skip: int = 0,
        limit: int = 100,
        order_id: Optional[int] = None,
        status: Optional[str] = None,
        payment_method: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> List[Payment]:
        """Get payments with optional filters"""
        query = db.query(Payment)

        if order_id:
            query = query.filter(Payment.order_id == order_id)
        if status:
            query = query.filter(Payment.status == status)
        if payment_method:
            query = query.filter(Payment.payment_method == payment_method)
        if start_date:
            query = query.filter(Payment.created_at >= start_date)
        if end_date:
            query = query.filter(Payment.created_at <= end_date)

        return query.offset(skip).limit(limit).all()

    @staticmethod
    def get_payment_stats(db: Session) -> Dict[str, Any]:
        """Get payment statistics"""
        from sqlalchemy import func

        stats = db.query(
            func.count(Payment.id).label('total_payments'),
            func.sum(Payment.amount).label('total_amount'),
            func.avg(Payment.amount).label('avg_amount')
        ).first()

        status_counts = db.query(
            Payment.status,
            func.count(Payment.id).label('count')
        ).group_by(Payment.status).all()

        return {
            'total_payments': stats.total_payments or 0,
            'total_amount': float(stats.total_amount or 0),
            'avg_amount': float(stats.avg_amount or 0),
            'status_breakdown': {status.value: count for status, count in status_counts}
}
