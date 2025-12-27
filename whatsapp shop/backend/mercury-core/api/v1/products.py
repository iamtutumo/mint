from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.session import get_db
from models.product import Product, ProductType
from schemas.product import ProductCreate, ProductUpdate, Product as ProductSchema
from services.product import ProductService

router = APIRouter(prefix="/products", tags=["products"])

@router.post("/", response_model=ProductSchema, status_code=status.HTTP_201_CREATED)
async def create_product(
    product: ProductCreate,
    db: Session = Depends(get_db)
):
    """Create a new product"""
    try:
        db_product = ProductService.create_product(
            db=db,
            name=product.name,
            product_type=product.product_type,
            selling_price=product.price,
            description=product.description,
            category=product.category,
            sku=product.sku,
            stock_quantity=0  # default
        )
        return ProductSchema.from_orm(db_product)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create product: {str(e)}")

@router.get("/", response_model=List[ProductSchema])
async def list_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    category: Optional[str] = None,
    product_type: Optional[ProductType] = None,
    db: Session = Depends(get_db)
):
    """List products with optional filters"""
    try:
        products = ProductService.list_products(
            db=db,
            category=category,
            product_type=product_type,
            skip=skip,
            limit=limit
        )
        return [ProductSchema.from_orm(product) for product in products]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list products: {str(e)}")

@router.get("/{product_id}", response_model=ProductSchema)
async def get_product(product_id: int, db: Session = Depends(get_db)):
    """Get product by ID"""
    try:
        product = ProductService.get_product(db, product_id)
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        return ProductSchema.from_orm(product)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get product: {str(e)}")

@router.put("/{product_id}", response_model=ProductSchema)
async def update_product(product_id: int, product: ProductUpdate, db: Session = Depends(get_db)):
    """Update product"""
    try:
        update_data = product.dict(exclude_unset=True)
        if 'price' in update_data:
            update_data['selling_price'] = update_data.pop('price')
        db_product = ProductService.update_product(db, product_id, **update_data)
        if not db_product:
            raise HTTPException(status_code=404, detail="Product not found")
        return ProductSchema.from_orm(db_product)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update product: {str(e)}")

@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(product_id: int, db: Session = Depends(get_db)):
    """Deactivate product"""
    try:
        success = ProductService.deactivate_product(db, product_id)
        if not success:
            raise HTTPException(status_code=404, detail="Product not found")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete product: {str(e)}")
