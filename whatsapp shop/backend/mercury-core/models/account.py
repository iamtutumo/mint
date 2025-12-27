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
    __table_args__ = {'extend_existing': True}
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
    # Self-referential parent/children relationships are temporarily disabled
    # to avoid ambiguity with SQLAlchemy's remote_side detection. Re-enable
    # with an explicit primaryjoin/remote() annotation if needed.
    # transactions relationship temporarily disabled to avoid mapper resolution issues during startup
    # transactions = relationship("app.models.transaction.Transaction", back_populates="account")