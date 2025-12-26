"""
Application lifecycle event handlers for startup and shutdown procedures.
"""
from typing import Callable, List
from fastapi import FastAPI
from contextlib import asynccontextmanager
import logging

from .logging import setup_logging
from .config import settings

logger = setup_logging()

# List to store shutdown callbacks
shutdown_callbacks: List[Callable] = []

def register_shutdown_event(callback: Callable) -> None:
    """Register a callback to be called during application shutdown.
    
    Args:
        callback: A callable that takes no arguments
    """
    shutdown_callbacks.append(callback)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events.
    
    This context manager is used to manage the application's lifecycle events.
    It's designed to be used with FastAPI's lifespan parameter.
    
    Args:
        app: The FastAPI application instance
    """
    # Application startup
    logger.info("Starting application...")
    logger.info(f"Environment: {settings.ENV}")
    
    try:
        # Initialize database connection pool
        from ..db.session import engine, Base
        logger.info("Creating database tables if they don't exist...")
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            
        # Initialize MinIO buckets if needed
        if hasattr(settings, 'MINIO_ACCESS_KEY') and settings.MINIO_ACCESS_KEY:
            from ..services.minio import ensure_buckets_exist
            await ensure_buckets_exist()
            logger.info("MinIO buckets verified/created")
            
        # Add any other startup initialization here
        
        logger.info("Application startup complete")
        
        # The application is now running
        yield
        
    except Exception as e:
        logger.critical(f"Application startup failed: {str(e)}", exc_info=True)
        raise
        
    finally:
        # Application shutdown
        logger.info("Application shutting down...")
        
        # Execute all registered shutdown callbacks
        for callback in shutdown_callbacks:
            try:
                if hasattr(callback, '__await__'):
                    await callback()
                else:
                    callback()
            except Exception as e:
                logger.error(f"Error in shutdown callback: {str(e)}", exc_info=True)
        
        # Close database connections
        if 'engine' in locals():
            await engine.dispose()
            logger.info("Database connections closed")
            
        logger.info("Application shutdown complete")
