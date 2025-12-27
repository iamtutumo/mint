from fastapi import APIRouter
from fastapi import Depends, HTTPException, status
from typing import List, Optional

# Import all endpoint routers
from . import products, orders, bookings, inventory, payments, documents, accounts, transactions, reports, webhooks

router = APIRouter(prefix="/v1", tags=["v1"])

# Include all API routers
router.include_router(products.router, prefix="/products", tags=["products"])
router.include_router(orders.router, prefix="/orders", tags=["orders"])
router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
router.include_router(inventory.router, prefix="/inventory", tags=["inventory"])
router.include_router(payments.router, prefix="/payments", tags=["payments"])
router.include_router(documents.router, prefix="/documents", tags=["documents"])
router.include_router(accounts.router, prefix="/accounts", tags=["accounts"])
router.include_router(transactions.router, prefix="/transactions", tags=["transactions"])
router.include_router(reports.router, prefix="/reports", tags=["reports"])
router.include_router(webhooks.router, prefix="/webhooks", tags=["webhooks"])
