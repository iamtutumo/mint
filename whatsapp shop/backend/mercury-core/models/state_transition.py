from sqlalchemy import Column, Integer, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel

class OrderStateTransition(BaseModel):
    __table_args__ = {'extend_existing': True}
    __tablename__ = "order_state_transitions"
    
    
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    from_state = Column(String(50), nullable=False)
    to_state = Column(String(50), nullable=False)
    reason = Column(Text)
    performed_by = Column(String(20))
    
    # Relationships
    order = relationship("Order", back_populates="state_transitions")