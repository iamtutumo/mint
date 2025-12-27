from sqlalchemy import Column, String, Numeric, Integer, Boolean, Text, Enum as SQLEnum, JSON, Float, ForeignKey
from sqlalchemy.orm import relationship
import enum
import uuid

from app.db.base import BaseModel

class ProductType(str, enum.Enum):
    PHYSICAL = "physical"
    DIGITAL = "digital"
    SERVICE = "service"

class Product(BaseModel):
    __table_args__ = {'extend_existing': True}
    __tablename__ = "products"
    
    
    name = Column(String(200), nullable=False, index=True)
    description = Column(Text)
    sku = Column(String(50), unique=True, index=True)
    barcode = Column(String(50), unique=True, nullable=True)
    category = Column(String(100), index=True)
    product_type = Column(SQLEnum(ProductType), nullable=False)
    
    # Pricing
    cost_price = Column(Numeric(10, 2), default=0)
    selling_price = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="USD")
    
    # Stock and inventory
    stock_quantity = Column(Integer, default=0)
    reorder_level = Column(Integer, default=0)
    
    # Physical product specific
    weight_kg = Column(Float, nullable=True)
    height_cm = Column(Float, nullable=True)
    width_cm = Column(Float, nullable=True)
    depth_cm = Column(Float, nullable=True)
    
    # Digital product specific
    file_url = Column(String(500))
    download_limit = Column(Integer, nullable=True)
    download_url = Column(String(500), nullable=True)
    access_expiry_days = Column(Integer, nullable=True)
    
    # Service product specific
    duration_minutes = Column(Integer, nullable=True)
    requires_booking = Column(Boolean, default=False)
    requires_confirmation = Column(Boolean, default=True)
    calendar_id = Column(String(100), nullable=True)
    
    # General
    is_active = Column(Boolean, default=True)
    metadata_json = Column(JSON, default=dict)
    image_url = Column(String(500))
    
    # Relationships
    order_items = relationship("OrderItem", back_populates="product")
    inventory_movements = relationship("InventoryMovement", back_populates="product")
    
