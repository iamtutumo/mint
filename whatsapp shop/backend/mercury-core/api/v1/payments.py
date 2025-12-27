from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.session import get_db
from models.payment import Payment, PaymentStatus, PaymentMethod
from schemas.payment import PaymentCreate, PaymentUpdate, Payment as PaymentSchema
from services.payment import PaymentService

router = APIRouter(prefix="/payments", tags=["payments"])

@router.post("/", response_model=PaymentSchema, status_code=status.HTTP_201_CREATED)
async def create_payment(
    payment: PaymentCreate,
    db: Session = Depends(get_db)
):
    """Create a new payment"""
    try:
        db_payment = PaymentService.create_payment(db, payment)
        return PaymentSchema.from_orm(db_payment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create payment: {str(e)}")

@router.get("/", response_model=List[PaymentSchema])
async def list_payments(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    order_id: Optional[int] = None,
    status: Optional[str] = None,
    payment_method: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db)
):
    """List payments with optional filters"""
    try:
        payments = PaymentService.get_payments(
            db=db,
            skip=skip,
            limit=limit,
            order_id=order_id,
            status=status,
            payment_method=payment_method,
            start_date=start_date,
            end_date=end_date
        )
        return [PaymentSchema.from_orm(payment) for payment in payments]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list payments: {str(e)}")

@router.get("/{payment_id}", response_model=PaymentSchema)
async def get_payment(
    payment_id: str,
    db: Session = Depends(get_db)
):
    """Get a payment by ID"""
    payment = PaymentService.get_payment(db, payment_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return PaymentSchema.from_orm(payment)

@router.put("/{payment_id}", response_model=PaymentSchema)
async def update_payment(
    payment_id: str,
    payment_update: PaymentUpdate,
    db: Session = Depends(get_db)
):
    """Update a payment"""
    try:
        db_payment = PaymentService.update_payment(db, payment_id, payment_update)
        return PaymentSchema.from_orm(db_payment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update payment: {str(e)}")

@router.delete("/{payment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_payment(
    payment_id: str,
    db: Session = Depends(get_db)
):
    """Delete a payment (only if pending)"""
    try:
        success = PaymentService.delete_payment(db, payment_id)
        if not success:
            raise HTTPException(status_code=404, detail="Payment not found")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete payment: {str(e)}")

@router.get("/stats/summary")
async def get_payment_stats(db: Session = Depends(get_db)):
    """Get payment statistics"""
    try:
        stats = PaymentService.get_payment_stats(db)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get payment stats: {str(e)}")

@router.get("/order/{order_id}", response_model=List[PaymentSchema])
async def get_payments_by_order(
    order_id: int,
    db: Session = Depends(get_db)
):
    """Get all payments for an order"""
    try:
        payments = PaymentService.get_payments_by_order(db, order_id)
        return [PaymentSchema.from_orm(payment) for payment in payments]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get payments for order: {str(e)}")
