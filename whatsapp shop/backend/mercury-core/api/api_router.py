from fastapi import APIRouter

from app.api.v1 import (
    products,
    orders,
    bookings,
    inventory,
    payments,
    documents,
    accounts,
    transactions,
    reports,
    webhooks
)

api_router = APIRouter()

api_router.include_router(products.router, prefix="/products", tags=["products"])
api_router.include_router(orders.router, prefix="/orders", tags=["orders"])
api_router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
api_router.include_router(inventory.router, prefix="/inventory", tags=["inventory"])
api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
api_router.include_router(documents.router, prefix="/documents", tags=["documents"])
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"])
api_router.include_router(transactions.router, prefix="/transactions", tags=["transactions"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
api_router.include_router(webhooks.router, prefix="/webhooks", tags=["webhooks"])