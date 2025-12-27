from sqlalchemy import Column, Integer, ForeignKey, Numeric, String, JSON
from sqlalchemy.orm import relationship

from app.db.base import BaseModel

class OrderItem(BaseModel):
    __table_args__ = {'extend_existing': True}
    __tablename__ = "order_items"
    
    
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    
    product_name = Column(String(200), nullable=False)
    product_sku = Column(String(50))
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    subtotal = Column(Numeric(10, 2), nullable=False)
    
    # Digital product delivery
    download_url = Column(String(500))
    download_expires_at = Column(String(50))
    
    # Metadata
    metadata_json = Column(JSON, default=dict)
    
    # Relationships
    order = relationship("Order", back_populates="items")
    product = relationship("Product", back_populates="order_items")