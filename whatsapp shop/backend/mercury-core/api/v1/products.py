from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

router = APIRouter(prefix="/products", tags=["products"])

# Pydantic models for request/response
class ProductBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float = Field(..., gt=0, description="Price must be greater than zero")
    sku: Optional[str] = None
    barcode: Optional[str] = None
    category: Optional[str] = None
    is_active: bool = True
    inventory_quantity: int = 0
    reorder_level: Optional[int] = None

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = Field(None, gt=0)
    sku: Optional[str] = None
    barcode: Optional[str] = None
    category: Optional[str] = None
    is_active: Optional[bool] = None
    inventory_quantity: Optional[int] = None
    reorder_level: Optional[int] = None

class ProductResponse(ProductBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

# Mock database
products_db = {}
product_id_counter = 1

@router.post("/", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
async def create_product(product: ProductCreate):
    global product_id_counter
    
    # In a real app, this would be a database operation
    product_dict = product.dict()
    product_dict["id"] = product_id_counter
    product_dict["created_at"] = datetime.utcnow()
    product_dict["updated_at"] = datetime.utcnow()
    
    products_db[product_id_counter] = product_dict
    product_id_counter += 1
    
    return product_dict

@router.get("/", response_model=List[ProductResponse])
async def list_products(
    skip: int = 0,
    limit: int = 100,
    category: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    in_stock: Optional[bool] = None
):
    # In a real app, this would be a database query with filters
    filtered_products = list(products_db.values())
    
    if category:
        filtered_products = [p for p in filtered_products if p.get("category") == category]
    if min_price is not None:
        filtered_products = [p for p in filtered_products if p["price"] >= min_price]
    if max_price is not None:
        filtered_products = [p for p in filtered_products if p["price"] <= max_price]
    if in_stock is not None:
        if in_stock:
            filtered_products = [p for p in filtered_products if p["inventory_quantity"] > 0]
        else:
            filtered_products = [p for p in filtered_products if p["inventory_quantity"] <= 0]
    
    return filtered_products[skip : skip + limit]

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: int):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    return products_db[product_id]

@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(product_id: int, product: ProductUpdate):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # In a real app, this would be a database operation
    stored_product = products_db[product_id]
    update_data = product.dict(exclude_unset=True)
    
    # Update only the fields that were provided
    for field, value in update_data.items():
        if value is not None:
            stored_product[field] = value
    
    stored_product["updated_at"] = datetime.utcnow()
    
    return stored_product

@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(product_id: int):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # In a real app, this would be a database operation
    del products_db[product_id]
    
    return {"ok": True}
