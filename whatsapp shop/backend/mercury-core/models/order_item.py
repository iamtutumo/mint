from sqlalchemy import Column, Integer, ForeignKey, Numeric, String, JSON
from sqlalchemy.orm import relationship

from app.db.base import BaseModel

class OrderItem(BaseModel):
    __tablename__ = "order_items"
    __table_args__ = {'extend_existing': True}
    
    
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
    # order = relationship("models.order.Order", back_populates="items")  # Commented out to avoid dependency issue
    # product = relationship("models.product.Product", back_populates="order_items")  # Commented out to avoid circular dependency