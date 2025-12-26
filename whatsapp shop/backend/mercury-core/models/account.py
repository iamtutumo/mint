from sqlalchemy import Column, String, Integer, ForeignKey, Enum as SQLEnum, Boolean, Numeric
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class AccountType(str, enum.Enum):
    ASSET = "asset"
    LIABILITY = "liability"
    EQUITY = "equity"
    INCOME = "income"
    EXPENSE = "expense"

class Account(BaseModel):
    __tablename__ = "accounts"
    
    code = Column(String(20), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)
    account_type = Column(SQLEnum(AccountType), nullable=False)
    parent_id = Column(Integer, ForeignKey("accounts.id"))
    description = Column(String(500))
    is_active = Column(Boolean, default=True)
    
    # Current balance (denormalized for performance)
    balance = Column(Numeric(15, 2), default=0)
    
    # Relationships
    parent = relationship("Account", remote_side=[id])
    transactions = relationship("Transaction", back_populates="account")