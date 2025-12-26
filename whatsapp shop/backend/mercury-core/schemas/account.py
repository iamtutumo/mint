from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field
from datetime import datetime

class AccountType(str, Enum):
    ASSET = "asset"
    LIABILITY = "liability"
    EQUITY = "equity"
    REVENUE = "revenue"
    EXPENSE = "expense"

class AccountSubType(str, Enum):
    # Asset sub-types
    CASH = "cash"
    BANK = "bank"
    ACCOUNTS_RECEIVABLE = "accounts_receivable"
    INVENTORY = "inventory"
    FIXED_ASSET = "fixed_asset"
    
    # Liability sub-types
    ACCOUNTS_PAYABLE = "accounts_payable"
    CREDIT_CARD = "credit_card"
    LOAN = "loan"
    
    # Equity sub-types
    OWNERS_EQUITY = "owners_equity"
    RETAINED_EARNINGS = "retained_earnings"
    
    # Revenue sub-types
    SALES = "sales"
    INTEREST_INCOME = "interest_income"
    
    # Expense sub-types
    COST_OF_GOODS_SOLD = "cost_of_goods_sold"
    SALARY = "salary"
    RENT = "rent"
    UTILITIES = "utilities"
    TAXES = "taxes"
    INTEREST_EXPENSE = "interest_expense"
    DEPRECIATION = "depreciation"

class AccountBase(BaseModel):
    name: str = Field(..., max_length=100)
    code: str = Field(..., max_length=20)
    account_type: AccountType
    account_subtype: Optional[AccountSubType] = None
    parent_account_id: Optional[str] = None
    is_active: bool = True
    description: Optional[str] = None
    metadata: Optional[dict] = None

class AccountCreate(AccountBase):
    pass

class AccountUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    code: Optional[str] = Field(None, max_length=20)
    account_type: Optional[AccountType] = None
    account_subtype: Optional[AccountSubType] = None
    is_active: Optional[bool] = None
    description: Optional[str] = None
    metadata: Optional[dict] = None

class Account(AccountBase):
    id: str
    created_at: datetime
    updated_at: datetime
    balance: float = 0.0
    
    class Config:
        from_attributes = True

class AccountTree(Account):
    children: List['AccountTree'] = []

class AccountBalance(BaseModel):
    account_id: str
    account_name: str
    account_code: str
    balance: float
    account_type: AccountType
