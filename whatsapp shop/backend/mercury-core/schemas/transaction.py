from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, validator
from datetime import datetime

class TransactionType(str, Enum):
    INVOICE = "invoice"
    PAYMENT = "payment"
    EXPENSE = "expense"
    TRANSFER = "transfer"
    JOURNAL_ENTRY = "journal_entry"
    ADJUSTMENT = "adjustment"

class TransactionStatus(str, Enum):
    DRAFT = "draft"
    PENDING = "pending"
    POSTED = "posted"
    VOIDED = "voided"
    ARCHIVED = "archived"

class TransactionLineItem(BaseModel):
    account_id: str
    amount: float
    is_debit: bool
    description: Optional[str] = None
    reference_id: Optional[str] = None
    reference_type: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class TransactionBase(BaseModel):
    transaction_type: TransactionType
    transaction_date: datetime = Field(default_factory=datetime.utcnow)
    reference_number: Optional[str] = None
    memo: Optional[str] = None
    status: TransactionStatus = TransactionStatus.DRAFT
    currency: str = "USD"
    exchange_rate: float = 1.0
    metadata: Optional[Dict[str, Any]] = None

class TransactionCreate(TransactionBase):
    line_items: List[TransactionLineItem]

class TransactionUpdate(BaseModel):
    reference_number: Optional[str] = None
    memo: Optional[str] = None
    status: Optional[TransactionStatus] = None
    metadata: Optional[Dict[str, Any]] = None

class Transaction(TransactionBase):
    id: str
    created_at: datetime
    updated_at: datetime
    total_amount: float
    line_items: List[TransactionLineItem]
    
    class Config:
        from_attributes = True

class TransactionList(BaseModel):
    items: List[Transaction]
    total: int
    page: int
    size: int
    pages: int

class AccountTransaction(Transaction):
    account_name: str
    account_code: str
    account_type: str
    running_balance: float

class AccountStatement(BaseModel):
    account_id: str
    account_name: str
    account_code: str
    start_date: datetime
    end_date: datetime
    opening_balance: float
    closing_balance: float
    transactions: List[AccountTransaction]
