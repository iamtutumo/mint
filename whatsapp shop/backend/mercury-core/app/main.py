from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.logging import setup_logging
from app.db.init_db import init_db
from app.api.v1.router import api_router

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
    allow_origins=settings.ALLOWED_ORIGINS,
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