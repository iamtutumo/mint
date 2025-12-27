from sqlalchemy import Column, String, Integer, ForeignKey, Enum as SQLEnum, Text, Numeric
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel

class MovementType(str, enum.Enum):
    INBOUND = "inbound"
    OUTBOUND = "outbound"
    ADJUSTMENT = "adjustment"
    RETURN = "return"
    DAMAGE = "damage"

class InventoryMovement(BaseModel):
    __tablename__ = "inventory_movements"
    
    
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    movement_type = Column(SQLEnum(MovementType), nullable=False)
    quantity = Column(Integer, nullable=False)
    reference = Column(String(100))
    notes = Column(Text)
    unit_cost = Column(Numeric(10, 2))
    performed_by = Column(String(20))
    
    # Relationships
    # product = relationship("models.product.Product", back_populates="inventory_movements")  # Commented out to avoid dependency issue