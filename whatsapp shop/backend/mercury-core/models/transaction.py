from sqlalchemy import Column, Integer, ForeignKey, String, Numeric, DateTime, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
import enum
from datetime import datetime

from app.db.base import BaseModel

class TransactionType(str, enum.Enum):
    DEBIT = "debit"
    CREDIT = "credit"

class Transaction(BaseModel):
    __tablename__ = "transactions"
    
    journal_entry_id = Column(String(50), index=True, nullable=False)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=False)
    
    transaction_type = Column(SQLEnum(TransactionType), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    
    transaction_date = Column(DateTime, default=datetime.utcnow)
    description = Column(Text)
    reference = Column(String(100))
    
    # Source tracking
    source_type = Column(String(50))  # order, expense, transfer, adjustment
    source_id = Column(Integer)
    
    performed_by = Column(String(20))
    
    # Relationships
    account = relationship("Account", back_populates="transactions")