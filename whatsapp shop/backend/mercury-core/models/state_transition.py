from sqlalchemy import Column, Integer, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel

class OrderStateTransition(BaseModel):
    __tablename__ = "order_state_transitions"
    
    
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    from_state = Column(String(50), nullable=False)
    to_state = Column(String(50), nullable=False)
    reason = Column(Text)
    performed_by = Column(String(20))
    
    # Relationships
    # order = relationship("models.order.Order", back_populates="state_transitions")  # Commented out to avoid dependency issue