from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
from typing import Optional, List
import uuid

from app.models.account import Account, AccountType
from app.models.transaction import Transaction, TransactionType
from app.core.logging import setup_logging

logger = setup_logging()

class AccountingService:
    
    @staticmethod
    def create_journal_entry(
        db: Session,
        entries: List[dict],
        description: str,
        reference: Optional[str] = None,
        performed_by: Optional[str] = None,
        source_type: Optional[str] = None,
        source_id: Optional[int] = None
    ) -> str:
        """Create double-entry journal entry"""
        
        journal_entry_id = f"JE-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        
        total_debit = 0
        total_credit = 0
        
        for entry in entries:
            account = db.query(Account).filter(Account.id == entry["account_id"]).first()
            if not account:
                raise ValueError(f"Account {entry['account_id']} not found")
            
            transaction = Transaction(
                journal_entry_id=journal_entry_id,
                account_id=entry["account_id"],
                transaction_type=entry["type"],
                amount=entry["amount"],
                description=description,
                reference=reference,
                performed_by=performed_by,
                source_type=source_type,
                source_id=source_id
            )
            
            db.add(transaction)
            
            # Update account balance
            if entry["type"] == TransactionType.DEBIT:
                total_debit += entry["amount"]
                if account.account_type in [AccountType.ASSET, AccountType.EXPENSE]:
                    account.balance += entry["amount"]
                else:
                    account.balance -= entry["amount"]
            else:  # CREDIT
                total_credit += entry["amount"]
                if account.account_type in [AccountType.LIABILITY, AccountType.EQUITY, AccountType.INCOME]:
                    account.balance += entry["amount"]
                else:
                    account.balance -= entry["amount"]
        
        # Verify double-entry
        if abs(total_debit - total_credit) > 0.01:
            raise ValueError(f"Unbalanced entry: Debit {total_debit} != Credit {total_credit}")
        
        db.commit()
        
        logger.info(f"Journal entry created: {journal_entry_id}")
        return journal_entry_id
    
    @staticmethod
    def record_sale(
        db: Session,
        amount: float,
        account_id: int,
        order_id: int,
        performed_by: str
    ) -> str:
        """Record a sale"""
        
        # Get revenue account
        revenue_account = db.query(Account).filter(
            Account.account_type == AccountType.INCOME,
            Account.code.like("4%")
        ).first()
        
        if not revenue_account:
            raise ValueError("Revenue account not found")
        
        entries = [
            {"account_id": account_id, "type": TransactionType.DEBIT, "amount": amount},
            {"account_id": revenue_account.id, "type": TransactionType.CREDIT, "amount": amount}
        ]
        
        return AccountingService.create_journal_entry(
            db, entries, f"Sale recorded", reference=f"ORDER-{order_id}",
            performed_by=performed_by, source_type="order", source_id=order_id
        )
    
    @staticmethod
    def record_expense(
        db: Session,
        amount: float,
        expense_account_id: int,
        payment_account_id: int,
        description: str,
        performed_by: str
    ) -> str:
        """Record an expense"""
        
        entries = [
            {"account_id": expense_account_id, "type": TransactionType.DEBIT, "amount": amount},
            {"account_id": payment_account_id, "type": TransactionType.CREDIT, "amount": amount}
        ]
        
        return AccountingService.create_journal_entry(
            db, entries, description, performed_by=performed_by,
            source_type="expense"
        )
    
    @staticmethod
    def transfer_funds(
        db: Session,
        from_account_id: int,
        to_account_id: int,
        amount: float,
        performed_by: str,
        notes: Optional[str] = None
    ) -> str:
        """Transfer between accounts"""
        
        description = notes or f"Transfer {amount}"
        
        entries = [
            {"account_id": to_account_id, "type": TransactionType.DEBIT, "amount": amount},
            {"account_id": from_account_id, "type": TransactionType.CREDIT, "amount": amount}
        ]
        
        return AccountingService.create_journal_entry(
            db, entries, description, performed_by=performed_by,
            source_type="transfer"
        )
    
    @staticmethod
    def get_account_balance(db: Session, account_id: int) -> float:
        """Get current account balance"""
        account = db.query(Account).filter(Account.id == account_id).first()
        if not account:
            raise ValueError("Account not found")
        return float(account.balance)
    
    @staticmethod
    def get_trial_balance(db: Session, as_of_date: Optional[datetime] = None):
        """Generate trial balance"""
        query = db.query(Account).filter(Account.is_active == True)
        accounts = query.all()
        
        trial_balance = []
        total_debit = 0
        total_credit = 0
        
        for account in accounts:
            balance = float(account.balance)
            if balance > 0:
                if account.account_type in [AccountType.ASSET, AccountType.EXPENSE]:
                    trial_balance.append({
                        "account": account.name,
                        "code": account.code,
                        "debit": balance,
                        "credit": 0
                    })
                    total_debit += balance
                else:
                    trial_balance.append({
                        "account": account.name,
                        "code": account.code,
                        "debit": 0,
                        "credit": balance
                    })
                    total_credit += balance
        
        return {
            "accounts": trial_balance,
            "total_debit": total_debit,
            "total_credit": total_credit,
            "balanced": abs(total_debit - total_credit) < 0.01
        }