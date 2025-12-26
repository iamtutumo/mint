from fastapi import APIRouter

from api.v1 import products, orders

api_router = APIRouter()

api_router.include_router(products.router, tags=["products"])
api_router.include_router(orders.router, tags=["orders"])







