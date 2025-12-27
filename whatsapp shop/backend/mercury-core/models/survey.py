from sqlalchemy import Column, Integer, ForeignKey, String, Text, JSON
from sqlalchemy.orm import relationship

from app.db.base import BaseModel

class Survey(BaseModel):
    __table_args__ = {'extend_existing': True}
    __tablename__ = "surveys"
    
    
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    rating = Column(Integer)  # 1-5
    feedback = Column(Text)
    responses = Column(JSON, default=dict)
    
    # Relationships
    order = relationship("Order")
    customer = relationship("User", back_populates="surveys")