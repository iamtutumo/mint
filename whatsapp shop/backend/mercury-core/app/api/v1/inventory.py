from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from ...db.session import get_db
from ...core.auth import get_current_user
from ...models.user import User
from ...services.inventory import InventoryService

router = APIRouter()

class MovementResponse(BaseModel):
    id: int
    product_id: int
    movement_type: str
    quantity: int
    reference: Optional[str]
    notes: Optional[str]
    unit_cost: Optional[float]
    performed_by: Optional[str]
    created_at: Optional[str]

    class Config:
        orm_mode = True

class AdjustRequest(BaseModel):
    product_id: int
    adjustment: int
    notes: str

class PurchaseRequest(BaseModel):
    product_id: int
    quantity: int
    unit_cost: float
    reference: Optional[str] = None

class SaleRequest(BaseModel):
    product_id: int
    quantity: int
    reference: Optional[str] = None

@router.get("/inventory/products/{product_id}/stock")
def get_product_stock(product_id: int, db=Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        qty = InventoryService.get_current_stock(db, product_id)
        return {"product_id": product_id, "stock_quantity": int(qty)}
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

@router.get("/inventory/movements/", response_model=List[MovementResponse])
def list_movements(product_id: int, skip: int = 0, limit: int = 50, db=Depends(get_db), current_user: User = Depends(get_current_user)):
    movements = InventoryService.get_product_movements(db, product_id, skip=skip, limit=limit)
    return movements

@router.post("/inventory/movements/adjust", response_model=MovementResponse)
def adjust_inventory(req: AdjustRequest, db=Depends(get_db), current_user: User = Depends(get_current_user)):
    # require superuser
    if not current_user.is_superuser:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
    movement = InventoryService.adjust_inventory(db, req.product_id, req.adjustment, performed_by=str(current_user.id), notes=req.notes)
    return movement

@router.post("/inventory/movements/purchase", response_model=MovementResponse, status_code=status.HTTP_201_CREATED)
def record_purchase(req: PurchaseRequest, db=Depends(get_db), current_user: User = Depends(get_current_user)):
    movement = InventoryService.record_purchase(db, req.product_id, req.quantity, req.unit_cost, performed_by=str(current_user.id), reference=req.reference)
    return movement

@router.post("/inventory/movements/sale", response_model=MovementResponse, status_code=status.HTTP_201_CREATED)
def record_sale(req: SaleRequest, db=Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        movement = InventoryService.record_sale(db, req.product_id, req.quantity, performed_by=str(current_user.id), reference=req.reference)
        return movement
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
