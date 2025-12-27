from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.session import get_db
from models.transaction import Transaction, TransactionType
from schemas.transaction import Transaction as TransactionSchema
from services.transaction import TransactionService
from models.transaction import Transaction, TransactionType
from schemas.transaction import Transaction as TransactionSchema
from services.transaction import TransactionService

router = APIRouter(prefix="/transactions", tags=["transactions"])

@router.get("/", response_model=List[TransactionSchema])
async def list_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    account_id: Optional[str] = None,
    journal_entry_id: Optional[str] = None,
    transaction_type: Optional[TransactionType] = None,
    source_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db)
):
    """List transactions with optional filters"""
    try:
        transactions = TransactionService.get_transactions(
            db=db,
            skip=skip,
            limit=limit,
            account_id=account_id,
            journal_entry_id=journal_entry_id,
            transaction_type=transaction_type,
            source_type=source_type,
            start_date=start_date,
            end_date=end_date
        )
        return [TransactionSchema.from_orm(transaction) for transaction in transactions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list transactions: {str(e)}")

@router.get("/{transaction_id}", response_model=TransactionSchema)
async def get_transaction(
    transaction_id: str,
    db: Session = Depends(get_db)
):
    """Get a transaction by ID"""
    transaction = TransactionService.get_transaction(db, transaction_id)
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return TransactionSchema.from_orm(transaction)

@router.get("/journal/{journal_entry_id}", response_model=List[TransactionSchema])
async def get_transactions_by_journal_entry(
    journal_entry_id: str,
    db: Session = Depends(get_db)
):
    """Get all transactions for a journal entry"""
    try:
        transactions = TransactionService.get_transactions_by_journal_entry(db, journal_entry_id)
        return [TransactionSchema.from_orm(transaction) for transaction in transactions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get transactions for journal entry: {str(e)}")

@router.get("/account/{account_id}", response_model=List[TransactionSchema])
async def get_transactions_by_account(
    account_id: str,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """Get transactions for an account within date range"""
    try:
        transactions = TransactionService.get_transactions_by_account(
            db, account_id, start_date, end_date, skip, limit
        )
        return [TransactionSchema.from_orm(transaction) for transaction in transactions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get transactions for account: {str(e)}")

@router.get("/account/{account_id}/statement")
async def get_account_statement(
    account_id: str,
    start_date: datetime,
    end_date: datetime,
    db: Session = Depends(get_db)
):
    """Generate account statement"""
    try:
        statement = TransactionService.get_account_statement(db, account_id, start_date, end_date)
        return statement
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate account statement: {str(e)}")

@router.get("/summary/stats")
async def get_transaction_summary(db: Session = Depends(get_db)):
    """Get transaction summary statistics"""
    try:
        summary = TransactionService.get_transaction_summary(db)
        return summary
    except Exception as e:        raise HTTPException(status_code=500, detail=f"Failed to get transaction summary: {str(e)}")