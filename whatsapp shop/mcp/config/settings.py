from pydantic_settings import BaseSettings
from typing import List, Dict, Any
import os

class Settings(BaseSettings):
    # MCP Core Settings
    MCP_HOST: str = "0.0.0.0"
    MCP_PORT: int = 8001
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://mercury:mercury_password@db:5432/mercury_commerce")
    
    # Redis for task queue
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis:6379/0")
    
    # MinIO Configuration
    MINIO_ENDPOINT: str = os.getenv("MINIO_ENDPOINT", "minio:9000")
    MINIO_ACCESS_KEY: str = os.getenv("MINIO_ACCESS_KEY", "mercury_access")
    MINIO_SECRET_KEY: str = os.getenv("MINIO_SECRET_KEY", "mercury_secret")
    MINIO_SECURE: bool = False
    
    # Qdrant Configuration
    QDRANT_URL: str = os.getenv("QDRANT_URL", "http://qdrant:6333")
    
    # Ollama Configuration
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
    
    # WhatsApp Configuration
    WHATSAPP_WEBHOOK_SECRET: str = os.getenv("WHATSAPP_WEBHOOK_SECRET", "")
    
    # Agent Configuration
    AGENT_TIMEOUT: int = 30  # seconds
    MAX_CONCURRENT_TASKS: int = 10
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
