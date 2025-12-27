from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from typing import List, Optional, Dict, Any
from datetime import datetime

from app.models.account import Account, AccountType
from app.models.transaction import Transaction
from app.schemas.account import AccountCreate, AccountUpdate, Account as AccountSchema, AccountBalance
from app.services.accounting import AccountingService
from app.core.logging import setup_logging

logger = setup_logging()

class AccountService:
    @staticmethod
    def get_account(db: Session, account_id: str) -> Optional[Account]:
        """Get an account by ID"""
        return db.query(Account).filter(Account.id == account_id).first()

    @staticmethod
    def get_account_by_code(db: Session, code: str) -> Optional[Account]:
        """Get an account by code"""
        return db.query(Account).filter(Account.code == code).first()

    @staticmethod
    def create_account(db: Session, account_data: AccountCreate) -> Account:
        """Create a new account"""
        # Check if code already exists
        existing = db.query(Account).filter(Account.code == account_data.code).first()
        if existing:
            raise ValueError(f"Account code {account_data.code} already exists")

        account = Account(
            code=account_data.code,
            name=account_data.name,
            account_type=account_data.account_type,
            description=account_data.description,
            is_active=account_data.is_active
        )

        db.add(account)
        db.commit()
        db.refresh(account)

        logger.info(f"Created account {account.id}: {account.name}")
        return account

    @staticmethod
    def update_account(db: Session, account_id: str, account_data: AccountUpdate) -> Account:
        """Update an account"""
        account = db.query(Account).filter(Account.id == account_id).first()
        if not account:
            raise ValueError(f"Account {account_id} not found")

        update_data = account_data.dict(exclude_unset=True)

        # Check code uniqueness if updating code
        if 'code' in update_data:
            existing = db.query(Account).filter(
                and_(Account.code == update_data['code'], Account.id != account_id)
            ).first()
            if existing:
                raise ValueError(f"Account code {update_data['code']} already exists")

        for field, value in update_data.items():
            if hasattr(account, field):
                setattr(account, field, value)

        db.commit()
        db.refresh(account)

        logger.info(f"Updated account {account_id}")
        return account

    @staticmethod
    def delete_account(db: Session, account_id: str) -> bool:
        """Delete an account (only if no transactions)"""
        account = db.query(Account).filter(Account.id == account_id).first()
        if not account:
            return False

        # Check if account has transactions
        transaction_count = db.query(func.count(Transaction.id)).filter(
            Transaction.account_id == account_id
        ).scalar()

        if transaction_count > 0:
            raise ValueError("Cannot delete account with existing transactions")

        db.delete(account)
        db.commit()

        logger.info(f"Deleted account {account_id}")
        return True

    @staticmethod
    def get_accounts(
        db: Session,
        skip: int = 0,
        limit: int = 100,
        account_type: Optional[AccountType] = None,
        is_active: Optional[bool] = None,
        search: Optional[str] = None
    ) -> List[Account]:
        """Get accounts with optional filters"""
        query = db.query(Account)

        if account_type:
            query = query.filter(Account.account_type == account_type)
        if is_active is not None:
            query = query.filter(Account.is_active == is_active)
        if search:
            query = query.filter(
                or_(
                    Account.name.ilike(f"%{search}%"),
                    Account.code.ilike(f"%{search}%")
                )
            )

        return query.offset(skip).limit(limit).all()

    @staticmethod
    def get_account_balance(db: Session, account_id: str) -> float:
        """Calculate current balance for an account"""
        account = db.query(Account).filter(Account.id == account_id).first()
        if not account:
            raise ValueError(f"Account {account_id} not found")

        # Sum all debit transactions minus credit transactions
        debit_sum = db.query(func.sum(Transaction.amount)).filter(
            and_(Transaction.account_id == account_id, Transaction.transaction_type == 'debit')
        ).scalar() or 0

        credit_sum = db.query(func.sum(Transaction.amount)).filter(
            and_(Transaction.account_id == account_id, Transaction.transaction_type == 'credit')
        ).scalar() or 0

        balance = debit_sum - credit_sum

        # Update denormalized balance
        account.balance = balance
        db.commit()

        return balance

    @staticmethod
    def get_all_account_balances(db: Session) -> List[AccountBalance]:
        """Get balances for all accounts"""
        accounts = db.query(Account).filter(Account.is_active == True).all()
        balances = []

        for account in accounts:
            balance = AccountService.get_account_balance(db, account.id)
            balances.append(AccountBalance(
                account_id=account.id,
                account_name=account.name,
                account_code=account.code,
                balance=balance,
                account_type=account.account_type
            ))

        return balances

    @staticmethod
    def get_trial_balance(db: Session) -> Dict[str, Any]:
        """Generate trial balance"""
        balances = AccountService.get_all_account_balances(db)

        total_debit = sum(b.balance for b in balances if b.balance > 0)
        total_credit = abs(sum(b.balance for b in balances if b.balance < 0))

        return {
            'accounts': [b.dict() for b in balances],
            'total_debit': total_debit,
            'total_credit': total_credit,
            'balanced': abs(total_debit - total_credit) < 0.01  # Allow for small rounding differences
}
