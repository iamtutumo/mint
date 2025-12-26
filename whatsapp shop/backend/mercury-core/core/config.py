from pydantic_settings import BaseSettings
from typing import List
import secrets

class Settings(BaseSettings):
    # App
    PROJECT_NAME: str = "Mercury Commerce"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = secrets.token_urlsafe(32)
    OWNER_PHONE_NUMBERS: List[str] = []
    SUPERUSER_PASSWORD: str = ""
    
    # Database
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "mercury"
    POSTGRES_PASSWORD: str = ""
    POSTGRES_DB: str = "mercury_commerce"
    POSTGRES_PORT: int = 5432
    
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
    # MinIO
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = ""
    MINIO_SECRET_KEY: str = ""
    MINIO_BUCKET_DOCUMENTS: str = "documents"
    MINIO_BUCKET_DIGITAL_PRODUCTS: str = "digital-products"
    MINIO_BUCKET_REPORTS: str = "reports"
    MINIO_SECURE: bool = False
    
    # Qdrant
    QDRANT_HOST: str = "localhost"
    QDRANT_PORT: int = 6333
    QDRANT_API_KEY: str = ""
    QDRANT_COLLECTION_PRODUCTS: str = "products"
    QDRANT_COLLECTION_FAQS: str = "faqs"
    
    # Ollama
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.1:8b"
    OLLAMA_EMBEDDING_MODEL: str = "nomic-embed-text"
    
    # Evolution API
    EVOLUTION_API_URL: str = "http://localhost:8080"
    EVOLUTION_API_KEY: str = ""
    EVOLUTION_INSTANCE: str = "mercury-bot"
    
    # Google Calendar
    GOOGLE_CALENDAR_CREDENTIALS_FILE: str = ""
    GOOGLE_CALENDAR_ID: str = ""
    
    # n8n
    N8N_WEBHOOK_URL: str = "http://localhost:5678/webhook"
    
    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8000"]
    
    # Orders
    ORDER_EXPIRY_HOURS: int = 24
    
    # PDF
    PDF_PASSWORD_PROTECTION: bool = True
    PDF_DEFAULT_PASSWORD: str = ""
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()