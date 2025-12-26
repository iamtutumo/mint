from sqlalchemy.orm import Session
from typing import Optional, List
import uuid

from app.models.product import Product, ProductType
from app.core.logging import setup_logging

logger = setup_logging()

class ProductService:
    
    @staticmethod
    def create_product(
        db: Session,
        name: str,
        product_type: ProductType,
        selling_price: float,
        description: Optional[str] = None,
        category: Optional[str] = None,
        cost_price: Optional[float] = None,
        stock_quantity: int = 0,
        sku: Optional[str] = None
    ) -> Product:
        """Create new product"""
        
        if not sku:
            sku = f"SKU-{uuid.uuid4().hex[:8].upper()}"
        
        product = Product(
            name=name,
            description=description,
            sku=sku,
            category=category,
            product_type=product_type,
            cost_price=cost_price or 0,
            selling_price=selling_price,
            stock_quantity=stock_quantity if product_type == ProductType.PHYSICAL else 0,
            is_active=True
        )
        
        db.add(product)
        db.commit()
        db.refresh(product)
        
        logger.info(f"Product created: {name} ({sku})")
        return product
    
    @staticmethod
    def get_product(db: Session, product_id: int) -> Optional[Product]:
        """Get product by ID"""
        return db.query(Product).filter(Product.id == product_id).first()
    
    @staticmethod
    def get_product_by_sku(db: Session, sku: str) -> Optional[Product]:
        """Get product by SKU"""
        return db.query(Product).filter(Product.sku == sku).first()
    
    @staticmethod
    def list_products(
        db: Session,
        category: Optional[str] = None,
        product_type: Optional[ProductType] = None,
        active_only: bool = True,
        skip: int = 0,
        limit: int = 100
    ) -> List[Product]:
        """List products with filters"""
        
        query = db.query(Product)
        
        if active_only:
            query = query.filter(Product.is_active == True)
        
        if category:
            query = query.filter(Product.category == category)
        
        if product_type:
            query = query.filter(Product.product_type == product_type)
        
        return query.offset(skip).limit(limit).all()
    
    @staticmethod
    def update_product(
        db: Session,
        product_id: int,
        **kwargs
    ) -> Optional[Product]:
        """Update product"""
        
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            return None
        
        for key, value in kwargs.items():
            if hasattr(product, key) and value is not None:
                setattr(product, key, value)
        
        db.commit()
        db.refresh(product)
        
        logger.info(f"Product updated: {product.name}")
        return product
    
    @staticmethod
    def deactivate_product(db: Session, product_id: int) -> bool:
        """Deactivate product"""
        
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            return False
        
        product.is_active = False
        db.commit()
        
        logger.info(f"Product deactivated: {product.name}")
        return True
    
    @staticmethod
    def get_low_stock_products(db: Session, threshold: Optional[int] = None) -> List[Product]:
        """Get products below reorder level"""
        
        query = db.query(Product).filter(
            Product.product_type == ProductType.PHYSICAL,
            Product.is_active == True
        )
        
        if threshold:
            query = query.filter(Product.stock_quantity <= threshold)
        else:
            query = query.filter(Product.stock_quantity <= Product.reorder_level)
        
        return query.all()