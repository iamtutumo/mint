from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.logging import setup_logging
from app.db.init import init_db
from api.api_router import api_router

# Import all models early to ensure they are registered with SQLAlchemy
# Models are now imported in db/init.py
# from models.product import Product
# from models.user import User
# from models.account import Account
# from models.document import Document
# from models.order import Order
# from models.survey import Survey
# from models.booking import Booking
# from models.inventory import InventoryMovement
# from models.transaction import Transaction
# from models.order_item import OrderItem
# from models.payment import Payment
# from models.state_transition import OrderStateTransition

logger = setup_logging()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Mercury Commerce Platform")
    await init_db()
    yield
    logger.info("Shutting down Mercury Commerce Platform")

app = FastAPI(
    title="Mercury Commerce Platform",
    description="WhatsApp-first AI Commerce & Operations Platform",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS_LIST,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "mercury-core",
        "version": "1.0.0"
    }

@app.get("/")
async def root():
    return {
        "message": "Mercury Commerce Platform API",
        "docs": "/docs"
    }