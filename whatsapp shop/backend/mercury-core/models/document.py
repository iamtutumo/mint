from sqlalchemy import Column, String, Integer, ForeignKey, Enum as SQLEnum, Boolean
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class DocumentType(str, enum.Enum):
    INVOICE = "invoice"
    RECEIPT = "receipt"
    PROPOSAL = "proposal"
    ORDER_CONFIRMATION = "order_confirmation"
    INVENTORY_REPORT = "inventory_report"
    FINANCIAL_REPORT = "financial_report"

class Document(BaseModel):
    __tablename__ = "documents"
    __table_args__ = {'extend_existing': True}
    
    
    document_number = Column(String(50), unique=True, index=True, nullable=False)
    document_type = Column(SQLEnum(DocumentType), nullable=False)
    
    # Storage
    file_path = Column(String(500), nullable=False)
    file_url = Column(String(500))
    
    # Security
    is_password_protected = Column(Boolean, default=False)
    password_hint = Column(String(100))
    
    # References
    order_id = Column(Integer, ForeignKey("orders.id"))
    customer_id = Column(Integer, ForeignKey("users.id"))
    
    # Relationships
    order = relationship("models.order.Order")
    customer = relationship("models.user.User")