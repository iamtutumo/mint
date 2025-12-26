from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime

from app.models.inventory import InventoryMovement, MovementType
from app.models.product import Product, ProductType
from app.core.logging import setup_logging

logger = setup_logging()

class InventoryService:
    
    @staticmethod
    def record_movement(
        db: Session,
        product_id: int,
        movement_type: MovementType,
        quantity: int,
        performed_by: str,
        reference: Optional[str] = None,
        notes: Optional[str] = None,
        unit_cost: Optional[float] = None
    ) -> InventoryMovement:
        """Record inventory movement"""
        
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise ValueError("Product not found")
        
        if product.product_type != ProductType.PHYSICAL:
            raise ValueError("Only physical products have inventory")
        
        # Create movement record
        movement = InventoryMovement(
            product_id=product_id,
            movement_type=movement_type,
            quantity=quantity,
            reference=reference,
            notes=notes,
            unit_cost=unit_cost,
            performed_by=performed_by
        )
        
        db.add(movement)
        
        # Update stock quantity
        if movement_type in [MovementType.PURCHASE, MovementType.RETURN]:
            product.stock_quantity += quantity
        elif movement_type in [MovementType.SALE, MovementType.DAMAGE]:
            if product.stock_quantity < quantity:
                raise ValueError("Insufficient stock")
            product.stock_quantity -= quantity
        elif movement_type == MovementType.ADJUSTMENT:
            # Adjustment can be positive or negative
            product.stock_quantity += quantity
        
        db.commit()
        db.refresh(movement)
        
        logger.info(f"Inventory movement recorded: {product.name} - {movement_type} - {quantity}")
        return movement
    
    @staticmethod
    def record_purchase(
        db: Session,
        product_id: int,
        quantity: int,
        unit_cost: float,
        performed_by: str,
        reference: Optional[str] = None
    ) -> InventoryMovement:
        """Record purchase (increases stock)"""
        return InventoryService.record_movement(
            db, product_id, MovementType.PURCHASE, quantity,
            performed_by, reference, unit_cost=unit_cost
        )
    
    @staticmethod
    def record_sale(
        db: Session,
        product_id: int,
        quantity: int,
        performed_by: str,
        reference: Optional[str] = None
    ) -> InventoryMovement:
        """Record sale (decreases stock)"""
        return InventoryService.record_movement(
            db, product_id, MovementType.SALE, quantity,
            performed_by, reference
        )
    
    @staticmethod
    def adjust_inventory(
        db: Session,
        product_id: int,
        adjustment: int,
        performed_by: str,
        notes: str
    ) -> InventoryMovement:
        """Manual inventory adjustment (requires superuser)"""
        return InventoryService.record_movement(
            db, product_id, MovementType.ADJUSTMENT, adjustment,
            performed_by, notes=notes
        )
    
    @staticmethod
    def get_product_movements(
        db: Session,
        product_id: int,
        skip: int = 0,
        limit: int = 100
    ):
        """Get movement history for product"""
        return db.query(InventoryMovement).filter(
            InventoryMovement.product_id == product_id
        ).order_by(InventoryMovement.created_at.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_current_stock(db: Session, product_id: int) -> int:
        """Get current stock level"""
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise ValueError("Product not found")
        return product.stock_quantity