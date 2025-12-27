from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from typing import List, Optional, Dict, Any
from datetime import datetime

from app.models.transaction import Transaction, TransactionType
from app.models.account import Account
from app.schemas.transaction import TransactionCreate, TransactionUpdate, Transaction as TransactionSchema
from app.services.accounting import AccountingService
from app.core.logging import setup_logging

logger = setup_logging()

class TransactionService:
    @staticmethod
    def get_transaction(db: Session, transaction_id: str) -> Optional[Transaction]:
        """Get a transaction by ID"""
        return db.query(Transaction).filter(Transaction.id == transaction_id).first()

    @staticmethod
    def get_transactions_by_journal_entry(db: Session, journal_entry_id: str) -> List[Transaction]:
        """Get all transactions for a journal entry"""
        return db.query(Transaction).filter(Transaction.journal_entry_id == journal_entry_id).all()

    @staticmethod
    def get_transactions_by_account(
        db: Session,
        account_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Transaction]:
        """Get transactions for an account within date range"""
        query = db.query(Transaction).filter(Transaction.account_id == account_id)

        if start_date:
            query = query.filter(Transaction.transaction_date >= start_date)
        if end_date:
            query = query.filter(Transaction.transaction_date <= end_date)

        return query.order_by(Transaction.transaction_date.desc()).offset(skip).limit(limit).all()

    @staticmethod
    def create_journal_entry_transaction(
        db: Session,
        journal_entry_id: str,
        account_id: str,
        transaction_type: TransactionType,
        amount: float,
        description: str,
        reference: Optional[str] = None,
        source_type: Optional[str] = None,
        source_id: Optional[int] = None,
        performed_by: Optional[str] = None
    ) -> Transaction:
        """Create a single transaction within a journal entry"""
        transaction = Transaction(
            journal_entry_id=journal_entry_id,
            account_id=account_id,
            transaction_type=transaction_type,
            amount=amount,
            description=description,
            reference=reference,
            source_type=source_type,
            source_id=source_id,
            performed_by=performed_by
        )

        db.add(transaction)
        return transaction

    @staticmethod
    def get_transactions(
        db: Session,
        skip: int = 0,
        limit: int = 100,
        account_id: Optional[str] = None,
        journal_entry_id: Optional[str] = None,
        transaction_type: Optional[TransactionType] = None,
        source_type: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> List[Transaction]:
        """Get transactions with optional filters"""
        query = db.query(Transaction)

        if account_id:
            query = query.filter(Transaction.account_id == account_id)
        if journal_entry_id:
            query = query.filter(Transaction.journal_entry_id == journal_entry_id)
        if transaction_type:
            query = query.filter(Transaction.transaction_type == transaction_type)
        if source_type:
            query = query.filter(Transaction.source_type == source_type)
        if start_date:
            query = query.filter(Transaction.transaction_date >= start_date)
        if end_date:
            query = query.filter(Transaction.transaction_date <= end_date)

        return query.order_by(Transaction.transaction_date.desc()).offset(skip).limit(limit).all()

    @staticmethod
    def get_account_statement(
        db: Session,
        account_id: str,
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Generate account statement"""
        account = db.query(Account).filter(Account.id == account_id).first()
        if not account:
            raise ValueError(f"Account {account_id} not found")

        # Get opening balance (transactions before start_date)
        opening_debit = db.query(func.sum(Transaction.amount)).filter(
            and_(
                Transaction.account_id == account_id,
                Transaction.transaction_type == TransactionType.DEBIT,
                Transaction.transaction_date < start_date
            )
        ).scalar() or 0

        opening_credit = db.query(func.sum(Transaction.amount)).filter(
            and_(
                Transaction.account_id == account_id,
                Transaction.transaction_type == TransactionType.CREDIT,
                Transaction.transaction_date < start_date
            )
        ).scalar() or 0

        opening_balance = opening_debit - opening_credit

        # Get transactions in period
        transactions = TransactionService.get_transactions_by_account(
            db, account_id, start_date, end_date
        )

        # Calculate running balances
        running_balance = opening_balance
        transaction_list = []

        for transaction in transactions:
            if transaction.transaction_type == TransactionType.DEBIT:
                running_balance += transaction.amount
            else:
                running_balance -= transaction.amount

            transaction_list.append({
                'id': transaction.id,
                'date': transaction.transaction_date,
                'type': transaction.transaction_type.value,
                'amount': float(transaction.amount),
                'description': transaction.description,
                'reference': transaction.reference,
                'running_balance': running_balance
            })

        closing_balance = running_balance

        return {
            'account_id': account_id,
            'account_name': account.name,
            'account_code': account.code,
            'start_date': start_date,
            'end_date': end_date,
            'opening_balance': opening_balance,
            'closing_balance': closing_balance,
            'transactions': transaction_list
        }

    @staticmethod
    def get_transaction_summary(db: Session) -> Dict[str, Any]:
        """Get transaction summary statistics"""
        stats = db.query(
            func.count(Transaction.id).label('total_transactions'),
            func.sum(Transaction.amount).label('total_amount'),
            func.avg(Transaction.amount).label('avg_amount'),
            func.min(Transaction.transaction_date).label('earliest_date'),
            func.max(Transaction.transaction_date).label('latest_date')
        ).first()

        type_counts = db.query(
            Transaction.transaction_type,
            func.count(Transaction.id).label('count'),
            func.sum(Transaction.amount).label('total')
        ).group_by(Transaction.transaction_type).all()

        return {
            'total_transactions': stats.total_transactions or 0,
            'total_amount': float(stats.total_amount or 0),
            'avg_amount': float(stats.avg_amount or 0),
            'date_range': {
                'earliest': stats.earliest_date,
                'latest': stats.latest_date
            },
            'by_type': [
                {
                    'type': t_type.value,
                    'count': count,
                    'total_amount': float(total or 0)
                }
                for t_type, count, total in type_counts
            ]
}
