from enum import Enum
from typing import List, Optional, Union
from pydantic import BaseModel, Field, HttpUrl
from datetime import datetime

class ProductType(str, Enum):
    PHYSICAL = "physical"
    DIGITAL = "digital"
    SERVICE = "service"

class ProductBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    price: float = Field(..., gt=0, description="Price in the smallest currency unit (e.g., cents)")
    currency: str = Field("USD", min_length=3, max_length=3)
    product_type: ProductType
    sku: Optional[str] = Field(None, max_length=50)
    barcode: Optional[str] = Field(None, max_length=50)
    is_active: bool = True
    metadata: Optional[dict] = None

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    price: Optional[float] = Field(None, gt=0)
    currency: Optional[str] = Field(None, min_length=3, max_length=3)
    is_active: Optional[bool] = None
    metadata: Optional[dict] = None

class DigitalProductCreate(ProductBase):
    product_type: ProductType = ProductType.DIGITAL
    download_url: Optional[HttpUrl] = None
    file_path: Optional[str] = None
    access_expiry_days: Optional[int] = Field(
        None, 
        ge=1,
        description="Number of days the download link remains valid"
    )

class ServiceProductCreate(ProductBase):
    product_type: ProductType = ProductType.SERVICE
    duration_minutes: int = Field(..., gt=0)
    requires_confirmation: bool = True
    calendar_id: Optional[str] = Field(
        None,
        description="Google Calendar ID for service booking"
    )

class PhysicalProductCreate(ProductBase):
    product_type: ProductType = ProductType.PHYSICAL
    weight_kg: Optional[float] = Field(None, gt=0)
    height_cm: Optional[float] = Field(None, gt=0)
    width_cm: Optional[float] = Field(None, gt=0)
    depth_cm: Optional[float] = Field(None, gt=0)

class Product(ProductBase):
    id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class ProductList(BaseModel):
    items: List[Product]
    total: int
    page: int
    size: int
    pages: int
