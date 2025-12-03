
#!/bin/bash

# =============================================
# AI Platform Superstack Setup Script
# Combines all microservices into a single deployment
# =============================================

# Exit on error and print commands
set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project root directory
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create required directories
create_directories() {
    echo -e "${YELLOW}Creating project structure...${NC}"
    
    # Main service directories
    mkdir -p "$ROOT_DIR/services/auth"
    mkdir -p "$ROOT_DIR/services/documents/{templates,output}"
    mkdir -p "$ROOT_DIR/services/ocr"
    mkdir -p "$ROOT_DIR/services/asr"
    mkdir -p "$ROOT_DIR/services/tts"
    mkdir -p "$ROOT_DIR/services/voice_streaming/recordings"
    mkdir -p "$ROOT_DIR/services/docgen/templates"
    mkdir -p "$ROOT_DIR/services/docsign/flows"
    mkdir -p "$ROOT_DIR/services/rules"
    mkdir -p "$ROOT_DIR/services/llm-engine/models"
    mkdir -p "$ROOT_DIR/services/elevenlabs-service"
    mkdir -p "$ROOT_DIR/services/gateway/conf.d"
    mkdir -p "$ROOT_DIR/services/pwa/dist"
    mkdir -p "$ROOT_DIR/services/stt"  # Add STT service directory

    # Create log directories
    mkdir -p "$ROOT_DIR/logs/caddy"
    mkdir -p "$ROOT_DIR/logs/auth"
    mkdir -p "$ROOT_DIR/logs/documents"
    mkdir -p "$ROOT_DIR/logs/ocr"
    mkdir -p "$ROOT_DIR/logs/asr"
    mkdir -p "$ROOT_DIR/logs/tts"
    mkdir -p "$ROOT_DIR/logs/voice_streaming"
    mkdir -p "$ROOT_DIR/logs/docgen"
    mkdir -p "$ROOT_DIR/logs/docsign"
    mkdir -p "$ROOT_DIR/logs/rules"
    mkdir -p "$ROOT_DIR/logs/llm-engine"
    mkdir -p "$ROOT_DIR/logs/elevenlabs-service"
    mkdir -p "$ROOT_DIR/logs/stt"

    # Create data directories for databases and storage
    mkdir -p "$ROOT_DIR/data/postgres"
    mkdir -p "$ROOT_DIR/data/redis"
    mkdir -p "$ROOT_DIR/data/minio"
    mkdir -p "$ROOT_DIR/data/weaviate"
    mkdir -p "$ROOT_DIR/data/ollama"

    echo -e "${GREEN}✓ Project structure created${NC}"
}

# Create environment files
create_env_files() {
    echo -e "${YELLOW}Creating environment files...${NC}"
    
    # Create .env file if it doesn't exist
    if [ ! -f "$ROOT_DIR/.env" ]; then
        echo -e "${YELLOW}Creating .env file...${NC}"
        cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env" 2>/dev/null || {
            # If .env.example doesn't exist, create a basic .env
            cat > "$ROOT_DIR/.env" << 'EOT'
# ============================================
# AI Platform Superstack - Environment Variables
# ============================================

# ===== Authentication =====
JWT_SECRET=$(openssl rand -hex 32)
MAGIC_LINK_EXPIRY=900
OTP_EXPIRY=300

# ===== Database & Cache =====
POSTGRES_USER=ai_user
POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 24)
POSTGRES_DB=ai_platform
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
REDIS_URL=redis://redis:6379

# ===== MinIO Storage =====
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=ChangeThisMinioPassword123!
MINIO_ACCESS_KEY=$(openssl rand -hex 16)
MINIO_SECRET_KEY=$(openssl rand -base64 32)
MINIO_BUCKET=documents

# ===== Email Configuration =====
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.email@example.com
SMTP_PASS=your_app_specific_password
SMTP_FROM=noreply@yourdomain.com
SMTP_SECURE=true

# ===== AI Services =====
OLLAMA_URL=http://ollama:11434
OLLAMA_MODEL=qwen:4b
STT_MODEL=base
STT_LANGUAGE=en
STT_DEVICE=cpu
TTS_PROVIDER=coqui
TTS_VOICE=tts_models/en/ljspeech/vits
TTS_MODEL=vits
LLM_PROVIDER=ollama
LLM_MODEL=qwen:4b
LLM_TEMPERATURE=0.7
LLM_MAX_TOKENS=2048

# ===== Service URLs =====
AUTH_SERVICE_URL=http://auth-service:8001
DOCUMENTS_SERVICE_URL=http://documents-service:8008
OCR_SERVICE_URL=http://ocr-service:8001
ASR_SERVICE_URL=http://asr-service:8002
TTS_SERVICE_URL=http://tts-service:8003
VOICE_SERVICE_URL=http://voice-service:8004
DOCGEN_SERVICE_URL=http://docgen-service:8005
DOCSIGN_SERVICE_URL=http://docsign-service:8006
RULES_SERVICE_URL=http://rules-service:8007
LLM_SERVICE_URL=http://llm-engine:8080
ELEVENLABS_SERVICE_URL=http://elevenlabs-service:3000

# ===== Environment =====
NODE_ENV=development
LOG_LEVEL=info
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
EOT
        }
        echo -e "${GREEN}✓ .env file created${NC}"
    else
        echo -e "${GREEN}✓ .env file already exists, using existing configuration${NC}"
    fi

    # Create .env.example if it doesn't exist
    if [ ! -f "$ROOT_DIR/.env.example" ]; then
        echo -e "${YELLOW}Creating .env.example file...${NC}"
        grep -v -E '^(#|$|POSTGRES_PASSWORD=|JWT_SECRET=|MINIO_ACCESS_KEY=|MINIO_SECRET_KEY=|SMTP_PASS=)' "$ROOT_DIR/.env" > "$ROOT_DIR/.env.example"
        echo -e "${GREEN}✓ .env.example file created${NC}"
    fi

    # Source the .env file
    if [ -f "$ROOT_DIR/.env" ]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
        echo -e "${GREEN}✓ Environment variables loaded${NC}"
    else
        echo -e "${RED}Error: Failed to load .env file${NC}"
        return 1
    fi
}

# Create docker-compose file
create_docker_compose() {
    echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
    cat > "$ROOT_DIR/docker-compose.yml" << 'EOT'
version: '3.9'
services:
  gateway:
    build: ./services/gateway
    container_name: gateway
    ports: ["80:80", "443:443"]
    volumes:
      - ./logs/caddy:/var/log/caddy
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - ACME_AGREE=true
      - CADDY_DOMAIN=localhost
      - CADDY_EMAIL=etu.moses@gmail.com
    depends_on:
      - auth-service
      - documents-service
      - ocr-service
      - asr-service
      - tts-service
      - voice-service
      - docgen-service
      - docsign-service
      - rules-service
      - pwa
      - llm-engine
      - elevenlabs-service
      - stt-service

  pwa:
    build: ./services/pwa
    container_name: pwa
    ports: ["3000:80"]
    volumes:
      - ./services/pwa/dist:/usr/share/nginx/html
      - ./logs/pwa:/var/log/nginx
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3

  auth-service:
    build: ./services/auth
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
      - MAGIC_LINK_EXPIRY=${MAGIC_LINK_EXPIRY}
      - OTP_EXPIRY=${OTP_EXPIRY}
    depends_on:
      - postgres
      - redis

  documents-service:
    build: ./services/documents
    ports:
      - "8008:8000"
    volumes:
      - ./services/documents/templates:/app/templates
      - ./services/documents/output:/app/output
    environment:
      - PYTHONUNBUFFERED=1
      - DOCUMENTS_MINIO_ENABLED=true
      - DOCUMENTS_MINIO_ENDPOINT=minio:9000
      - DOCUMENTS_MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - DOCUMENTS_MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - DOCUMENTS_MINIO_BUCKET=${MINIO_BUCKET}
    depends_on:
      - minio
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  minio:
    image: minio/minio:RELEASE.2023-10-07T15-07-38Z
    container_name: minio
    ports:
      - "9000:9000"  # API port
      - "9001:9001"  # Console port
    volumes:
      - ./data/minio:/data
      - ./logs/minio:/root/.minio/logs
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
      MINIO_DOMAIN: minio.local
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  ocr-service:
    build: ./services/ocr
    ports: ["8001:8000"]

  asr-service:
    build: ./services/asr
    ports: ["8002:8000"]

  tts-service:
    build: ./services/tts
    ports: ["8003:8000"]

  voice-service:
    build: ./services/voice_streaming
    ports: ["8004:8000"]
    environment:
      - OLLAMA_URL=http://ollama:11434
      - OLLAMA_MODEL=llama3

  docgen-service:
    build: ./services/docgen
    ports: ["8005:8000"]
    volumes:
      - ./services/docgen/templates:/app/templates

  docsign-service:
    build: ./services/docsign
    ports: ["8006:8000"]
    volumes:
      - ./services/docsign/flows:/app/flows

  llm-engine:
    build:
      context: ./services/llm-engine
    container_name: llm-engine
    ports:
      - "8009:8000"
    environment:
      - PYTHONUNBUFFERED=1
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - postgres
      - redis
      - ollama
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    volumes:
      - llm_models:/root/.ollama

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - llm_models:/root/.ollama
    restart: unless-stopped

  elevenlabs-service:
    build:
      context: ./services/elevenlabs-service
    container_name: elevenlabs-service
    ports:
      - "8010:8000"
    environment:
      - PYTHONUNBUFFERED=1
    depends_on:
      - stt-service
      - tts-service
      - llm-engine
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped

  docgen:
    build:
      context: ./services/docgen
    container_name: docgen
    ports:
      - "8005:8000"
    environment:
      - PYTHONUNBUFFERED=1
    depends_on:
      - postgres
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  rules-service:
    build: ./services/rules
    container_name: rules_engine_service
    ports: ["8007:8000"]
    environment:
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped

  scalar:
    image: scalar/scalar:latest
    container_name: scalar
    ports: ["8089:8080"]
    environment:
      - SCALAR_API_SPEC=/openapi.yaml
    volumes:
      - ./openapi.yaml:/openapi.yaml

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports: ["11434:11434"]
    volumes:
      - ollama_models:/root/.ollama

  weaviate:
    image: semitechnologies/weaviate:1.21.2
    container_name: weaviate
    ports: ["8081:8080"]
    environment:
      - QUERY_DEFAULTS_LIMIT=20
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=true
      - PERSISTENCE_DATA_PATH="/var/lib/weaviate"
      - DEFAULT_VECTORIZER_MODULE="none"
      - CLUSTER_HOSTNAME=node1
    volumes:
      - ./data/weaviate:/var/lib/weaviate
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/v1/.well-known/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=true

  evolution-api:
    image: evolutionapi/evolution-api:latest
    container_name: evolution-api
    ports: ["8080:8080"]
    environment:
      - WHATSAPP_API_KEY=${WHATSAPP_API_KEY}

  postgres:
    image: postgres:15-alpine
    container_name: postgres
    environment:
      - POSTGRES_USER=authuser
      - POSTGRES_PASSWORD=authpass123
      - POSTGRES_DB=authdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports: ["5432:5432"]

  redis:
    image: redis:alpine
    container_name: redis
    ports: ["6379:6379"]

  postgres_n8n:
    image: postgres:15-alpine
    container_name: postgres_n8n
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data_n8n:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    ports: ["5678:5678"]
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres_n8n
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    depends_on: [postgres_n8n]

  chatwoot:
    image: chatwoot/chatwoot:latest
    container_name: chatwoot
    ports: ["3000:3000"]
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on: [postgres, redis]

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports: ["9000:9000"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  # STT Service
  stt-service:
    build:
      context: ./services/stt
      dockerfile: Dockerfile
    container_name: stt-service
    ports: ["8011:8000"]
    environment:
      - PYTHONUNBUFFERED=1
      - MODEL_PATH=/app/models
    volumes:
      - stt_models:/root/.cache/whisper
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
  redis_data:
  ollama_models:
  minio_data:
  postgres_data_n8n:
  portainer_data:
  stt_models:
EOT
}

# Create service files
create_service_files() {
    echo -e "${YELLOW}Creating service files...${NC}"
    
    # OCR Service
    cat > "$ROOT_DIR/services/ocr/main.py" << 'EOT'
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import base64
import pytesseract
from PIL import Image
import io
import os

app = FastAPI(title="OCR Service")

@app.post("/ocr")
async def ocr(file: UploadFile = File(None), image_base64: str = None):
    try:
        if file:
            content = await file.read()
        elif image_base64:
            content = base64.b64decode(image_base64)
        else:
            raise HTTPException(status_code=400, detail="No input provided")

        image = Image.open(io.BytesIO(content))
        text = pytesseract.image_to_string(image)
        return {"text": text.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOT

    # Requirements for OCR
    cat > "$ROOT_DIR/services/ocr/requirements.txt" << 'EOT'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
pytesseract>=0.3.10
Pillow>=9.5.0
python-multipart>=0.0.6
EOT

    # STT Service
    mkdir -p "$ROOT_DIR/services/stt"
    cat > "$ROOT_DIR/services/stt/main.py" << 'EOT'
from fastapi import FastAPI, UploadFile, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
import torchaudio
import io
import os
import logging
from pathlib import Path
from typing import Optional
from pydantic import BaseModel
import numpy as np

app = FastAPI(title="Speech-to-Text Service")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Model and processor
model = None
processor = None

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool

class TranscriptionRequest(BaseModel):
    audio: UploadFile
    language: Optional[str] = "en"

@app.on_event("startup")
async def load_model():
    global model, processor
    try:
        model_path = os.getenv("MODEL_PATH", "/root/.cache/whisper")
        model_name = "openai/whisper-tiny"  # Using tiny model for CPU
        
        logger.info(f"Loading Whisper model: {model_name}")
        
        # Load model with CPU-specific settings
        model = WhisperForConditionalGeneration.from_pretrained(
            model_name,
            cache_dir=model_path,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=True,
        )
        
        processor = WhisperProcessor.from_pretrained(model_name, cache_dir=model_path)
        logger.info("Model and processor loaded successfully")
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise

@app.get("/health")
async def health_check():
    return {
        "status": "healthy" if model is not None else "model not loaded",
        "model_loaded": model is not None
    }

@app.post("/transcribe")
async def transcribe_audio(audio: UploadFile, language: str = "en"):
    if not model or not processor:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model not loaded"
        )
    
    try:
        # Read and process audio
        content = await audio.read()
        audio_data, sample_rate = torchaudio.load(io.BytesIO(content), format=audio.filename.split('.')[-1])
        
        # Convert to mono if stereo
        if len(audio_data.shape) > 1 and audio_data.shape[0] > 1:
            audio_data = torch.mean(audio_data, dim=0, keepdim=True)
        
        # Resample if needed
        if sample_rate != 16000:
            resampler = torchaudio.transforms.Resample(orig_freq=sample_rate, new_freq=16000)
            audio_data = resampler(audio_data)
        
        # Get input features
        input_features = processor(
            audio_data.squeeze().numpy(),
            sampling_rate=16000,
            return_tensors="pt"
        ).input_features
        
        # Generate token ids
        predicted_ids = model.generate(input_features)
        
        # Decode token ids to text
        transcription = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0]
        
        return {
            "transcription": transcription,
            "language": language,
            "model": "whisper-tiny"
        }
    
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error processing audio: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOT

    # Requirements for STT
    cat > "$ROOT_DIR/services/stt/requirements.txt" << 'EOT'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
torch>=2.0.0
torchaudio>=2.0.0
transformers>=4.28.0
soundfile>=0.12.1
numpy>=1.24.2
python-multipart>=0.0.6
python-dotenv>=1.0.0
EOT

    # Create rules service directory
    mkdir -p "$ROOT_DIR/services/rules"
    
    # Create rules service requirements
    cat > "$ROOT_DIR/services/rules/requirements.txt" << 'RULES_REQ'
fastapi>=0.104.1,<1.0.0
uvicorn[standard]>=0.24.0,<0.25.0
pydantic>=2.5.0,<3.0.0
python-multipart>=0.0.6,<1.0.0
rule-engine>=4.5.3,<5.0.0
RULES_REQ

    # Create rules service main file
    cat > "$ROOT_DIR/services/rules/main.py" << 'RULES_MAIN'
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any, Union
import rule_engine
import json
import logging
from datetime import datetime
from enum import Enum
import uuid
import re

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Rules Engine Service",
    description="Declarative business rules engine with CPU-optimized evaluation",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== Enums ====================

class RuleStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    TESTING = "testing"
    ARCHIVED = "archived"

class RulePriority(str, Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

class DecisionType(str, Enum):
    APPROVE = "approve"
    REJECT = "reject"
    REVIEW = "review"
    ESCALATE = "escalate"
    NOTIFY = "notify"

# ==================== Models ====================

class RuleCondition(BaseModel):
    """Single rule condition"""
    field: str
    operator: str
    value: Any

    @validator('operator')
    def validate_operator(cls, v):
        valid_operators = ['==', '!=', '>', '<', '>=', '<=', 'in', 'not in', 'contains', 'starts_with', 'ends_with']
        if v not in valid_operators:
            raise ValueError(f'Operator must be one of {valid_operators}')
        return v

class RuleAction(BaseModel):
    """Action to execute when rule matches"""
    type: str
    parameters: Dict[str, Any] = {}

class Rule(BaseModel):
    """Complete rule definition"""
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    category: str = "general"
    priority: RulePriority = RulePriority.MEDIUM
    status: RuleStatus = RuleStatus.ACTIVE
    when: str
    then: Dict[str, Any]
    defaults: Dict[str, Any] = {}
    version: int = 1
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    tags: List[str] = []

class RuleSet(BaseModel):
    """Collection of related rules"""
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    rules: List[Rule] = []
    priority_order: List[str] = []
    metadata: Dict[str, Any] = {}

class EvaluationRequest(BaseModel):
    """Request to evaluate rules"""
    rules: Optional[List[Rule]] = None
    rule_set_id: Optional[str] = None
    facts: Dict[str, Any]
    context: Dict[str, Any] = {}

    @validator('rules', 'rule_set_id')
    def check_rules_or_set(cls, v, values):
        if v is None and 'rule_set_id' not in values:
            raise ValueError('Either rules or rule_set_id must be provided')
        return v

class EvaluationResult(BaseModel):
    """Result of rule evaluation"""
    matched: bool
    rule_id: str
    rule_name: str
    decisions: Dict[str, Any]
    execution_time_ms: float
    priority: str

class EvaluationResponse(BaseModel):
    """Complete evaluation response"""
    results: List[EvaluationResult]
    final_decision: Dict[str, Any]
    total_matches: int
    execution_time_ms: float
    evaluation_id: str

class TestRequest(BaseModel):
    """Test rule with sample data"""
    rule: Rule
    test_cases: List[Dict[str, Any]]

class TestResult(BaseModel):
    """Result of rule testing"""
    test_case_index: int
    facts: Dict[str, Any]
    matched: bool
    decisions: Dict[str, Any]
    expected: Optional[bool] = None
    passed: Optional[bool] = None

class ChainRequest(BaseModel):
    """Request to execute rule chain"""
    initial_facts: Dict[str, Any]
    rule_chain: List[str]
    max_iterations: int = 10

# ==================== Rule Engine Core ====================

class RuleEngineCore:
    """Core rule evaluation engine using rule_engine library"""
    def __init__(self):
        self.rule_cache = {}

    def evaluate_rule(self, rule: Rule, facts: Dict[str, Any]) -> EvaluationResult:
        """Evaluate a single rule against facts"""
        start_time = datetime.utcnow()
        try:
            # Compile rule if not in cache
            if rule.id not in self.rule_cache:
                self.rule_cache[rule.id] = rule_engine.Rule(rule.when)
            
            # Evaluate rule
            context = {**rule.defaults, **facts}
            matched = self.rule_cache[rule.id].matches(context)
            
            # Execute actions if rule matches
            decisions = {}
            if matched and rule.then:
                decisions = rule.then
            
            return EvaluationResult(
                matched=matched,
                rule_id=rule.id or "",
                rule_name=rule.name,
                decisions=decisions,
                execution_time_ms=(datetime.utcnow() - start_time).total_seconds() * 1000,
                priority=rule.priority
            )
            
        except Exception as e:
            logger.error(f"Error evaluating rule {rule.id}: {str(e)}")
            raise HTTPException(status_code=400, detail=f"Rule evaluation failed: {str(e)}")

    def evaluate_rules(self, rules: List[Rule], facts: Dict[str, Any], stop_on_first_match: bool = False) -> List[EvaluationResult]:
        """Evaluate multiple rules"""
        results = []
        for rule in rules:
            result = self.evaluate_rule(rule, facts)
            results.append(result)
            if stop_on_first_match and result.matched:
                break
        return results

# ==================== Rule Storage ====================

class RuleStore:
    """In-memory rule storage (use PostgreSQL in production)"""
    def __init__(self):
        self.rules: Dict[str, Rule] = {}
        self.rule_sets: Dict[str, RuleSet] = {}
        self.rule_history: Dict[str, List[Rule]] = {}
        self._load_sample_rules()
    
    def _load_sample_rules(self):
        """Load sample rules for demonstration"""
        sample_rule = Rule(
            id="sample-rule-1",
            name="High Value Transaction Check",
            description="Flag transactions over $10,000 for review",
            category="fraud_detection",
            priority=RulePriority.HIGH,
            when="amount > 10000",
            then={"status": "review_required", "reason": "High value transaction"},
            defaults={"currency": "USD"}
        )
        self.save_rule(sample_rule)
    
    def save_rule(self, rule: Rule):
        """Save a rule"""
        if not rule.id:
            rule.id = f"rule-{str(uuid.uuid4())[:8]}"
        
        # Update timestamps
        now = datetime.utcnow()
        if not rule.created_at:
            rule.created_at = now
        rule.updated_at = now
        
        # Save to history
        if rule.id not in self.rule_history:
            self.rule_history[rule.id] = []
        self.rule_history[rule.id].append(rule.copy(deep=True))
        
        # Save current version
        self.rules[rule.id] = rule
        return rule
    
    def get_rule(self, rule_id: str) -> Optional[Rule]:
        """Get rule by ID"""
        return self.rules.get(rule_id)
    
    def list_rules(self, category: Optional[str] = None, status: Optional[RuleStatus] = None) -> List[Rule]:
        """List all rules with optional filters"""
        result = list(self.rules.values())
        if category:
            result = [r for r in result if r.category == category]
        if status:
            result = [r for r in result if r.status == status]
        return result
    
    def delete_rule(self, rule_id: str) -> bool:
        """Delete a rule"""
        if rule_id in self.rules:
            del self.rules[rule_id]
            return True
        return False
    
    def get_rule_history(self, rule_id: str) -> List[Rule]:
        """Get rule version history"""
        return self.rule_history.get(rule_id, [])
    
    def save_rule_set(self, rule_set: RuleSet) -> RuleSet:
        """Save a rule set"""
        if not rule_set.id:
            rule_set.id = f"ruleset-{str(uuid.uuid4())[:8]}"
        self.rule_sets[rule_set.id] = rule_set
        return rule_set
    
    def get_rule_set(self, rule_set_id: str) -> Optional[RuleSet]:
        """Get rule set by ID"""
        return self.rule_sets.get(rule_set_id)
    
    def list_rule_sets(self) -> List[RuleSet]:
        """List all rule sets"""
        return list(self.rule_sets.values())

# ==================== Rule Chaining ====================

class RuleChainExecutor:
    """Execute chains of rules where one triggers another"""
    def __init__(self, rule_engine: RuleEngineCore, rule_store: RuleStore):
        self.rule_engine = rule_engine
        self.rule_store = rule_store
    
    def execute_chain(
        self, 
        initial_facts: Dict[str, Any], 
        rule_chain: List[str],
        max_iterations: int = 10
    ) -> Dict[str, Any]:
        """Execute a chain of rules"""
        facts = initial_facts.copy()
        results = {}
        
        for i in range(max_iterations):
            rule_id = rule_chain[i % len(rule_chain)]
            rule = self.rule_store.get_rule(rule_id)
            
            if not rule:
                logger.warning(f"Rule {rule_id} not found in chain")
                break
                
            result = self.rule_engine.evaluate_rule(rule, facts)
            results[rule_id] = result
            
            # Update facts with decisions
            if result.matched and result.decisions:
                facts.update(result.decisions)
            
            # Stop if we've gone through all rules
            if i >= len(rule_chain) - 1:
                break
        
        return {"facts": facts, "results": results}

# ==================== Initialize Services ====================

rule_engine = RuleEngineCore()
rule_store = RuleStore()
rule_chain_executor = RuleChainExecutor(rule_engine, rule_store)

# ==================== API Endpoints ====================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "rules_count": len(rule_store.rules),
        "rule_sets_count": len(rule_store.rule_sets)
    }

@app.post("/evaluate", response_model=EvaluationResponse)
async def evaluate_rules(request: EvaluationRequest):
    """
    Evaluate rules against provided facts
    
    Supports:
    - Direct rule evaluation
    - Rule set evaluation
    - Priority-based execution
    """
    start_time = datetime.utcnow()
    evaluation_id = f"eval-{str(uuid.uuid4())[:8]}"
    
    try:
        # Get rules to evaluate
        rules_to_evaluate = []
        if request.rules:
            rules_to_evaluate = request.rules
        elif request.rule_set_id:
            rule_set = rule_store.get_rule_set(request.rule_set_id)
            if not rule_set:
                raise HTTPException(status_code=404, detail="Rule set not found")
            rules_to_evaluate = rule_set.rules
        
        # Evaluate rules
        results = []
        for rule in rules_to_evaluate:
            if rule.status != RuleStatus.ACTIVE:
                continue
                
            result = rule_engine.evaluate_rule(rule, request.facts)
            results.append(result)
        
        # Determine final decision
        final_decision = {}
        if results:
            # Get highest priority match
            priority_order = [RulePriority.CRITICAL, RulePriority.HIGH, 
                            RulePriority.MEDIUM, RulePriority.LOW]
            
            for priority in priority_order:
                for result in results:
                    if result.matched and result.priority == priority:
                        final_decision = result.decisions
                        break
                if final_decision:
                    break
        
        execution_time_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
        
        return EvaluationResponse(
            results=results,
            final_decision=final_decision,
            total_matches=sum(1 for r in results if r.matched),
            execution_time_ms=execution_time_ms,
            evaluation_id=evaluation_id
        )
        
    except Exception as e:
        logger.error(f"Evaluation {evaluation_id} failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/rules", response_model=Rule)
async def load_rule(rule: Rule):
    """Load or update a rule"""
    try:
        return rule_store.save_rule(rule)
    except Exception as e:
        logger.error(f"Error saving rule: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/rules/dsl", response_model=Rule)
async def load_rule_from_dsl(dsl_text: str):
    """Load rule from DSL format"""
    try:
        # In a real implementation, parse the DSL text into a Rule object
        # For now, just return a sample rule
        return Rule(
            name="DSL Rule",
            description="Rule loaded from DSL",
            when="amount > 1000",
            then={"status": "review_required"}
        )
    except Exception as e:
        logger.error(f"Error parsing DSL: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/rules", response_model=List[Rule])
async def list_rules(
    category: Optional[str] = None,
    status: Optional[RuleStatus] = None
):
    """List all rules with optional filters"""
    try:
        return rule_store.list_rules(category=category, status=status)
    except Exception as e:
        logger.error(f"Error listing rules: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/rules/{rule_id}", response_model=Rule)
async def get_rule(rule_id: str):
    """Get rule by ID"""
    rule = rule_store.get_rule(rule_id)
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")
    return rule

@app.delete("/rules/{rule_id}")
async def delete_rule(rule_id: str):
    """Delete a rule"""
    if not rule_store.delete_rule(rule_id):
        raise HTTPException(status_code=404, detail="Rule not found")
    return {"status": "deleted", "rule_id": rule_id}

@app.get("/rules/{rule_id}/history", response_model=List[Rule])
async def get_rule_history(rule_id: str):
    """Get rule version history"""
    history = rule_store.get_rule_history(rule_id)
    if not history:
        raise HTTPException(status_code=404, detail="No history found for rule")
    return history

@app.post("/test", response_model=List[TestResult])
async def test_rule(request: TestRequest):
    """Test rule with multiple test cases"""
    results = []
    
    for i, test_case in enumerate(request.test_cases):
        try:
            # Evaluate rule with test case
            result = rule_engine.evaluate_rule(request.rule, test_case["facts"])
            
            # Check if test passed (if expected result was provided)
            passed = None
            if "expected" in test_case:
                passed = result.matched == test_case["expected"]
            
            results.append(TestResult(
                test_case_index=i,
                facts=test_case["facts"],
                matched=result.matched,
                decisions=result.decisions,
                expected=test_case.get("expected"),
                passed=passed
            ))
            
        except Exception as e:
            logger.error(f"Error in test case {i}: {str(e)}")
            results.append(TestResult(
                test_case_index=i,
                facts=test_case.get("facts", {}),
                matched=False,
                decisions={"error": str(e)},
                expected=test_case.get("expected"),
                passed=False
            ))
    
    return results

@app.post("/chain", response_model=Dict[str, Any])
async def execute_rule_chain(request: ChainRequest):
    """Execute a chain of rules"""
    try:
        return rule_chain_executor.execute_chain(
            request.initial_facts,
            request.rule_chain,
            request.max_iterations
        )
    except Exception as e:
        logger.error(f"Error executing rule chain: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/rulesets", response_model=RuleSet)
async def create_rule_set(rule_set: RuleSet):
    """Create a new rule set"""
    try:
        return rule_store.save_rule_set(rule_set)
    except Exception as e:
        logger.error(f"Error creating rule set: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/rulesets", response_model=List[RuleSet])
async def list_rule_sets():
    """List all rule sets"""
    try:
        return rule_store.list_rule_sets()
    except Exception as e:
        logger.error(f"Error listing rule sets: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/rulesets/{rule_set_id}", response_model=RuleSet)
async def get_rule_set(rule_set_id: str):
    """Get rule set by ID"""
    rule_set = rule_store.get_rule_set(rule_set_id)
    if not rule_set:
        raise HTTPException(status_code=404, detail="Rule set not found")
    return rule_set

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
RULES_MAIN

    # Create documents service directory
    mkdir -p "$ROOT_DIR/services/documents"
    
    # Create documents service requirements
    cat > "$ROOT_DIR/services/documents/requirements.txt" << 'DOCS_REQ'
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
python-multipart==0.0.6
PyYAML==6.0.2
Jinja2==3.1.4
docxtpl==0.16.8
openpyxl==3.1.5
pandas==2.2.2
PyPDF2==3.0.1
pikepdf==9.4.0
Pillow==10.4.0
qrcode==7.4.2
minio==7.1.16
python-magic==0.4.27
python-dotenv==1.0.0
DOCS_REQ

    # Create documents service main file
    mkdir -p "$ROOT_DIR/services/documents/templates"
    mkdir -p "$ROOT_DIR/services/documents/output"
    
    # Create sample template
    mkdir -p "$ROOT_DIR/services/documents/templates/sample"
    
    # Create sample template file
    cat > "$ROOT_DIR/services/documents/templates/sample/template.html" << 'SAMPLE_HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Sample Document</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .content { margin: 20px 0; }
        .footer { margin-top: 50px; font-size: 0.9em; color: #666; text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{ title }}</h1>
        <p>Generated on {{ date }}</p>
    </div>
    
    <div class="content">
        <p>Hello {{ recipient_name }},</p>
        
        <p>This is a sample document generated from the template engine service.</p>
        
        <h2>Document Details</h2>
        <ul>
            <li>Reference: {{ reference_number }}</li>
            <li>Amount: {{ "${:,.2f}".format(amount) if amount else 'N/A' }}</li>
            <li>Status: <strong>{{ status|default('Pending') }}</strong></li>
        </ul>
        
        {% if notes %}
        <h3>Notes:</h3>
        <p>{{ notes }}</p>
        {% endif %}
    </div>
    
    <div class="footer">
        <p>This is an automatically generated document. Please do not reply to this email.</p>
        {% if qr_data %}
        <div style="text-align: center; margin-top: 20px;">
            <img src="data:image/png;base64,{{ qr_data }}" alt="QR Code">
        </div>
        {% endif %}
    </div>
</body>
</html>
SAMPLE_HTML

    # Create template mapping file
    cat > "$ROOT_DIR/services/documents/templates/sample/mapping.yaml" << 'MAPPING_YAML'
name: "Sample Document"
description: "A sample document template for demonstration"
template_file: "sample/template.html"
output_format: "pdf"
fields:
  title:
    type: "string"
    required: true
    description: "Document title"
  recipient_name:
    type: "string"
    required: true
    description: "Name of the recipient"
  reference_number:
    type: "string"
    required: false
    description: "Reference number"
  amount:
    type: "number"
    required: false
    description: "Transaction amount"
  status:
    type: "string"
    required: false
    description: "Document status"
    default: "Draft"
  notes:
    type: "text"
    required: false
    description: "Additional notes"
  qr_data:
    type: "string"
    required: false
    description: "Base64 encoded QR code data"
sample_data:
  title: "Sample Document"
  recipient_name: "John Doe"
  reference_number: "REF-2023-001"
  amount: 1234.56
  status: "Approved"
  notes: "This is a sample note for demonstration purposes."
MAPPING_YAML

    # Create documents service main file
    cat > "$ROOT_DIR/services/documents/main.py" << 'DOCS_MAIN'
from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any, Union
import yaml
import json
import logging
from datetime import datetime
from enum import Enum
from pathlib import Path
import os
import re
import base64
import hashlib
import uuid
import io

# Document processing
from jinja2 import Environment, FileSystemLoader, Template
from docxtpl import DocxTemplate
from docx import Document
import openpyxl
import pandas as pd

# PDF processing
from PyPDF2 import PdfReader, PdfWriter
import pikepdf

# Image processing
from PIL import Image, ImageDraw, ImageFont
import qrcode

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Document Generation Service",
    description="Template-based document generation service with support for multiple formats",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure template and output directories exist
TEMPLATES_DIR = Path("templates")
OUTPUT_DIR = Path("output")
TEMPLATES_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

# Simple in-memory storage for generated documents
document_store = {}

class OutputFormat(str, Enum):
    PDF = "pdf"
    DOCX = "docx"
    XLSX = "xlsx"
    CSV = "csv"
    HTML = "html"
    PNG = "png"
    JPG = "jpg"

class GenerateRequest(BaseModel):
    template_path: str
    data: Dict[str, Any]
    output_format: OutputFormat = OutputFormat.PDF
    options: Dict[str, Any] = {}

class GenerateResponse(BaseModel):
    document_id: str
    output_format: str
    download_url: str
    timestamp: datetime

class TemplateInfo(BaseModel):
    name: str
    path: str
    description: Optional[str] = None
    fields: Dict[str, Any] = {}
    sample_data: Dict[str, Any] = {}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "templates_available": len(list(TEMPLATES_DIR.glob("**/*.html")))
    }

@app.get("/templates", response_model=List[TemplateInfo])
async def list_templates():
    """List all available templates"""
    templates = []
    for mapping_file in TEMPLATES_DIR.glob("**/mapping.yaml"):
        try:
            with open(mapping_file, 'r') as f:
                mapping = yaml.safe_load(f)
                templates.append(TemplateInfo(
                    name=mapping.get("name", mapping_file.parent.name),
                    path=str(mapping_file.relative_to(TEMPLATES_DIR).parent),
                    description=mapping.get("description"),
                    fields=mapping.get("fields", {}),
                    sample_data=mapping.get("sample_data", {})
                ))
        except Exception as e:
            logger.error(f"Error loading template {mapping_file}: {str(e)}")
    return templates

@app.post("/generate", response_model=GenerateResponse)
async def generate_document(request: GenerateRequest):
    """Generate a document from a template"""
    try:
        # Generate a unique document ID
        doc_id = str(uuid.uuid4())
        
        # Get template path
        template_dir = TEMPLATES_DIR / request.template_path
        mapping_file = template_dir / "mapping.yaml"
        
        if not mapping_file.exists():
            raise HTTPException(status_code=404, detail=f"Template mapping not found: {request.template_path}")
        
        # Load template mapping
        with open(mapping_file, 'r') as f:
            mapping = yaml.safe_load(f)
        
        # Get template file
        template_file = template_dir / mapping["template_file"]
        if not template_file.exists():
            raise HTTPException(status_code=404, detail=f"Template file not found: {mapping['template_file']}")
        
        # Render template
        env = Environment(loader=FileSystemLoader(template_dir))
        template = env.get_template(template_file.name)
        
        # Add default data
        data = {**mapping.get("sample_data", {}), **request.data}
        
        # Add timestamp if not provided
        if "date" not in data:
            data["date"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Render content
        if template_file.suffix == '.html':
            content = template.render(**data)
            output_file = OUTPUT_DIR / f"{doc_id}.{request.output_format}"
            
            # For HTML, just save as is
            if request.output_format == "html":
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(content)
            # For PDF, we'd normally use something like WeasyPrint or pdfkit here
            # For simplicity, we'll just save as HTML for now
            else:
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                # In a real implementation, convert to PDF here
                # This is a placeholder that would be replaced with actual PDF generation
                logger.info(f"Would convert {output_file} to PDF")
        
        # Store document info
        document_store[doc_id] = {
            "path": str(output_file),
            "content_type": f"application/{request.output_format}",
            "created_at": datetime.utcnow()
        }
        
        return GenerateResponse(
            document_id=doc_id,
            output_format=request.output_format,
            download_url=f"/documents/{doc_id}/download",
            timestamp=datetime.utcnow()
        )
        
    except Exception as e:
        logger.error(f"Error generating document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/documents/{document_id}/download")
async def download_document(document_id: str):
    """Download a generated document"""
    if document_id not in document_store:
        raise HTTPException(status_code=404, detail="Document not found")
    
    doc = document_store[document_id]
    if not os.path.exists(doc["path"]):
        raise HTTPException(status_code=404, detail="Document file not found")
    
    return FileResponse(
        doc["path"],
        media_type=doc["content_type"],
        filename=f"document{document_id}.{doc['content_type'].split('/')[-1]}"
    )

@app.get("/documents/{document_id}/preview")
async def preview_document(document_id: str):
    """Preview a generated document in the browser"""
    if document_id not in document_store:
        raise HTTPException(status_code=404, detail="Document not found")
    
    doc = document_store[document_id]
    if not os.path.exists(doc["path"]):
        raise HTTPException(status_code=404, detail="Document file not found")
    
    if doc["content_type"] == "application/pdf":
        return FileResponse(doc["path"], media_type="application/pdf")
    elif doc["content_type"] == "text/html":
        with open(doc["path"], 'r', encoding='utf-8') as f:
            return Response(content=f.read(), media_type="text/html")
    else:
        return FileResponse(doc["path"], media_type=doc["content_type"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
DOCS_MAIN

    # Create LLM Engine service directory
    mkdir -p "$ROOT_DIR/services/llm-engine/app"
    
    # Create LLM Engine requirements
    cat > "$ROOT_DIR/services/llm-engine/requirements.txt" << 'LLM_REQ'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0
httpx==0.25.2
python-multipart==0.0.6
python-dotenv==1.0.0
python-json-logger==2.0.7
python-dateutil==2.8.2
numpy>=1.24.0
pandas>=2.0.0
scikit-learn>=1.3.0
sentence-transformers>=2.2.2
LLM_REQ

    # Create LLM Engine main file
    mkdir -p "$ROOT_DIR/services/llm-engine/app/agents"
    
    # Create LLM Engine main application
    cat > "$ROOT_DIR/services/llm-engine/app/main.py" << 'LLM_MAIN'
"""
LLM Service - Complete FastAPI Implementation
Multi-Agent Orchestration with Ollama Integration
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import logging
from datetime import datetime
import uuid
import base64
import httpx

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="LLM & Multi-Agent Service",
    description="Ollama-based LLM service with multi-agent orchestration",
    version="1.0.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ollama client
class OllamaClient:
    def __init__(self, base_url: str = "http://ollama:11434"):
        self.base_url = base_url
        self.client = httpx.AsyncClient()

    async def generate(self, model: str, prompt: str, **kwargs):
        try:
            response = await self.client.post(
                f"{self.base_url}/api/generate",
                json={"model": model, "prompt": prompt, **kwargs},
                timeout=60.0
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error generating text: {str(e)}")
            raise HTTPException(status_code=500, detail=str(e))

# Initialize clients
ollama_client = OllamaClient()

# Models
class LLMRequest(BaseModel):
    prompt: str
    model: str = "llama2"
    max_tokens: int = 1000
    temperature: float = 0.7

class LLMResponse(BaseModel):
    text: str
    model: str
    tokens_used: int

# Routes
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Try to list models as a health check
        async with httpx.AsyncClient() as client:
            response = await client.get("http://ollama:11434/api/tags")
            response.raise_for_status()
            
        return {
            "status": "healthy",
            "ollama_connected": True,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {
            "status": "unhealthy",
            "ollama_connected": False,
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

@app.post("/generate", response_model=LLMResponse)
async def generate_completion(request: LLMRequest):
    """Generate LLM completion using Ollama"""
    try:
        result = await ollama_client.generate(
            model=request.model,
            prompt=request.prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )
        
        return LLMResponse(
            text=result.get("response", ""),
            model=request.model,
            tokens_used=len(result.get("response", "").split())
        )
    except Exception as e:
        logger.error(f"Error generating completion: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models")
async def list_models():
    """List available Ollama models"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("http://ollama:11434/api/tags")
            response.raise_for_status()
            return response.json()
    except Exception as e:
        logger.error(f"Error listing models: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
LLM_MAIN

    # Create ElevenLabs service directory
    mkdir -p "$ROOT_DIR/services/elevenlabs-service/app"
    
    # Create ElevenLabs requirements
    cat > "$ROOT_DIR/services/elevenlabs-service/requirements.txt" << 'ELEVEN_REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
pydantic>=2.0.0
python-multipart>=0.0.6
python-dotenv>=1.0.0
httpx>=0.24.0
websockets>=11.0.0
python-socketio>=5.8.0
pydub>=0.25.1
numpy>=1.24.0
ELEVEN_REQ

    # Create ElevenLabs main file
    cat > "$ROOT_DIR/services/elevenlabs-service/app/main.py" << 'ELEVEN_MAIN'
import asyncio
import json
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional
import httpx

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ElevenLabs Microservice",
    description="Microservice for handling real-time audio streaming with ElevenLabs-like interface",
    version="0.1.0"
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
class Config:
    # Service URLs
    STT_SERVICE_URL = "http://stt-service:8000/api/stt/transcribe"
    TTS_SERVICE_URL = "http://tts-service:8000/api/tts/synthesize/base64"
    LLM_SERVICE_URL = "http://llm-engine:8000/generate"
    
    # Audio configuration
    SAMPLE_RATE = 16000
    CHUNK_SIZE = 1024 * 4  # 4KB chunks
    
    # Timeouts in seconds
    HTTP_TIMEOUT = 30.0
    WEBSOCKET_TIMEOUT = 60.0
    
    # Voice settings
    DEFAULT_VOICE_ID = "default_en_female"
    DEFAULT_LANGUAGE = "en"

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.client_data: Dict[str, dict] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        self.client_data[client_id] = {
            "conversation": [],
            "voice_settings": {
                "voice_id": Config.DEFAULT_VOICE_ID,
                "language": Config.DEFAULT_LANGUAGE
            }
        }
        logger.info(f"Client connected: {client_id}")

    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            del self.client_data[client_id]
            logger.info(f"Client disconnected: {client_id}")

    async def send_message(self, client_id: str, message: dict):
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_json(message)

manager = ConnectionManager()

# Pydantic models for request/response validation
class AudioChunk(BaseModel):
    audio: str
    sample_rate: int = Config.SAMPLE_RATE

class TextRequest(BaseModel):
    text: str

# WebSocket endpoint for real-time audio streaming
@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            try:
                data = await asyncio.wait_for(
                    websocket.receive_json(),
                    timeout=Config.WEBSOCKET_TIMEOUT
                )
                
                if "audio" in data:
                    await process_audio_chunk(client_id, data["audio"])
                elif "text" in data:
                    await process_text_input(client_id, data["text"])
                
            except asyncio.TimeoutError:
                # Send keep-alive ping
                await websocket.send_json({"type": "ping", "timestamp": str(datetime.utcnow())})
                
    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        logger.error(f"WebSocket error: {str(e)}")
        manager.disconnect(client_id)

async def process_audio_chunk(client_id: str, audio_data: str):
    """Process incoming audio chunk by sending to STT service."""
    try:
        # Send audio to STT service
        async with httpx.AsyncClient(timeout=Config.HTTP_TIMEOUT) as client:
            response = await client.post(
                Config.STT_SERVICE_URL,
                json={"audio": audio_data, "sample_rate": Config.SAMPLE_RATE}
            )
            response.raise_for_status()
            result = response.json()
            
            if "text" in result and result["text"].strip():
                # Process the transcribed text
                await process_text_input(client_id, result["text"])
                
    except Exception as e:
        logger.error(f"Error processing audio chunk: {str(e)}")
        await manager.send_message(client_id, {
            "type": "error",
            "message": f"Error processing audio: {str(e)}"
        })

async def process_text_input(client_id: str, text: str):
    """Process text input (for non-audio input)."""
    try:
        # Add to conversation history
        manager.client_data[client_id]["conversation"].append({
            "role": "user",
            "content": text,
            "timestamp": str(datetime.utcnow())
        })
        
        # Get response from LLM
        async with httpx.AsyncClient(timeout=Config.HTTP_TIMEOUT) as client:
            response = await client.post(
                Config.LLM_SERVICE_URL,
                json={"prompt": text, "model": "llama2"}
            )
            response.raise_for_status()
            llm_response = response.json()
            
            # Add response to conversation
            manager.client_data[client_id]["conversation"].append({
                "role": "assistant",
                "content": llm_response.get("text", ""),
                "timestamp": str(datetime.utcnow())
            })
            
            # Convert response to speech
            await convert_text_to_speech(client_id, llm_response.get("text", ""))
            
    except Exception as e:
        logger.error(f"Error processing text input: {str(e)}")
        await manager.send_message(client_id, {
            "type": "error",
            "message": f"Error processing text: {str(e)}"
        })

async def convert_text_to_speech(client_id: str, text: str):
    """Convert text to speech using TTS service."""
    try:
        voice_settings = manager.client_data[client_id].get("voice_settings", {})
        
        async with httpx.AsyncClient(timeout=Config.HTTP_TIMEOUT) as client:
            response = await client.post(
                Config.TTS_SERVICE_URL,
                json={
                    "text": text,
                    "voice_id": voice_settings.get("voice_id", Config.DEFAULT_VOICE_ID),
                    "language": voice_settings.get("language", Config.DEFAULT_LANGUAGE)
                }
            )
            response.raise_for_status()
            result = response.json()
            
            # Send audio back to client
            await manager.send_message(client_id, {
                "type": "audio",
                "audio": result.get("audio", ""),
                "text": text
            })
            
    except Exception as e:
        logger.error(f"Error converting text to speech: {str(e)}")
        await manager.send_message(client_id, {
            "type": "error",
            "message": f"Error generating speech: {str(e)}"
        })

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "elevenlabs-service"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
ELEVEN_MAIN

    # Dockerfile for services
    for svc in ocr asr stt tts voice_streaming docgen docsign rules documents llm-engine elevenlabs-service; do
        mkdir -p "$ROOT_DIR/services/$svc"
        cat > "$ROOT_DIR/services/$svc/Dockerfile" << 'EOT'
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY . .
RUN adduser --disabled-password appuser && chown -R appuser /app
USER appuser
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOT
    done

    # Special CPU-optimized Dockerfile for STT
    mkdir -p "$ROOT_DIR/services/stt"
    cat > "$ROOT_DIR/services/stt/Dockerfile.cpu" << 'EOT'
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create models directory
RUN mkdir -p /root/.cache/whisper

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOT

    # Create documents service directory
    mkdir -p "$ROOT_DIR/services/documents"
    
    # Create documents service requirements
    cat > "$ROOT_DIR/services/documents/requirements.txt" << 'DOCS_REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
pydantic>=2.0.0
python-multipart>=0.0.6
PyYAML>=6.0
Jinja2>=3.0.0
docxtpl>=0.16.0
openpyxl>=3.0.0
pandas>=2.0.0
PyPDF2>=3.0.0
pikepdf>=8.0.0
Pillow>=10.0.0
qrcode>=7.0
DOCS_REQ

    # Create documents service Dockerfile
    cat > "$ROOT_DIR/services/documents/Dockerfile" << 'DOCS_DOCKER'
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN adduser --disabled-password appuser && chown -R appuser /app
USER appuser

# Create required directories
RUN mkdir -p /app/templates /app/output

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
DOCS_DOCKER

    # Create sample template
    mkdir -p "$ROOT_DIR/services/documents/templates"
    cat > "$ROOT_DIR/services/documents/templates/sample_template.html" << 'SAMPLE_TPL'
<!DOCTYPE html>
<html>
<head>
    <title>Document</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { text-align: center; margin-bottom: 30px; }
        .content { margin: 20px 0; }
        .footer { margin-top: 50px; font-size: 0.8em; text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{ title }}</h1>
        <p>Generated on {{ date }}</p>
    </div>
    
    <div class="content">
        <h2>Document Details</h2>
        <p><strong>Reference:</strong> {{ reference }}</p>
        <p><strong>Status:</strong> {{ status }}</p>
        
        <h3>Content</h3>
        <p>{{ content }}</p>
        
        {% if items %}
        <h3>Items</h3>
        <ul>
            {% for item in items %}
            <li>{{ item.name }} - {{ item.value }}</li>
            {% endfor %}
        </ul>
        {% endif %}
    </div>
    
    <div class="footer">
        <p>This is a sample document generated by the Document Service</p>
    </div>
</body>
</html>
SAMPLE_TPL

    # Create main.py for the documents service
    cat > "$ROOT_DIR/services/documents/main.py" << 'DOCS_MAIN'
from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any, Union
import yaml
import json
import logging
from datetime import datetime
import os
from pathlib import Path
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Document Generation Service",
    description="API for generating documents from templates",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure required directories exist
TEMPLATES_DIR = Path("templates")
OUTPUT_DIR = Path("output")
TEMPLATES_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

class HealthCheckResponse(BaseModel):
    status: str
    version: str
    timestamp: str

class DocumentRequest(BaseModel):
    template_name: str
    data: Dict[str, Any]
    output_format: str = "pdf"
    output_filename: Optional[str] = None

@app.get("/health")
async def health_check():
    return HealthCheckResponse(
        status="healthy",
        version="1.0.0",
        timestamp=datetime.utcnow().isoformat()
    )

@app.post("/generate")
async def generate_document(request: DocumentRequest):
    """Generate a document from a template"""
    try:
        template_path = TEMPLATES_DIR / request.template_name
        if not template_path.exists():
            raise HTTPException(status_code=404, detail="Template not found")
        
        # Generate a unique filename
        output_filename = request.output_filename or f"document_{uuid.uuid4().hex}"
        output_path = OUTPUT_DIR / f"{output_filename}.{request.output_format}"
        
        # In a real implementation, you would render the template here
        # For now, we'll just create a simple file
        with open(output_path, 'w') as f:
            f.write(f"Generated document from template: {request.template_name}\n")
            f.write(f"Data: {json.dumps(request.data, indent=2)}\n")
        
        return {
            "status": "success",
            "document_id": output_filename,
            "download_url": f"/download/{output_filename}.{request.output_format}"
        }
    except Exception as e:
        logger.error(f"Error generating document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/download/{filename}")
async def download_document(filename: str):
    """Download a generated document"""
    file_path = OUTPUT_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(file_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
DOCS_MAIN

    # Gateway files
    mkdir -p "$ROOT_DIR/services/gateway"
    cat > "$ROOT_DIR/services/gateway/nginx.conf" << 'EOT'
worker_processes 1;
events { worker_connections 1024; }
http {
  server {
    listen 80;
    location /health { return 200 'ok'; }
    location /auth { proxy_pass http://auth-service:8001; }
    location /api/links { proxy_pass http://links-service:8002; }
    location /s { proxy_pass http://links-service:8002; }
    location /api/messaging { proxy_pass http://messaging-service:8003; }
    location /api/push { proxy_pass http://push-service:8004; }
    location /ai/ocr { proxy_pass http://ocr-service:8001; }
    location /ai/asr { proxy_pass http://asr-service:8002; }
    location /ai/tts { proxy_pass http://tts-service:8003; }
    location /ai/voice { proxy_pass http://voice-service:8004; }
    location /ai/docgen { proxy_pass http://docgen-service:8005; }
    location /ai/docsign { proxy_pass http://docsign-service:8006; }
    location /ai/rules { proxy_pass http://rules-service:8007; }
    location /ai/documents { proxy_pass http://documents-service:8008; }
    location /pwa { proxy_pass http://pwa:80; }
  }
}
EOT

    cat > "$ROOT_DIR/services/gateway/Dockerfile" << 'EOT'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
EOT

    mkdir -p "$ROOT_DIR/services/pwa"
    cat > "$ROOT_DIR/services/pwa/index.html" << 'EOT'
<!doctype html><html><head><title>PWA</title></head><body><h1>PWA</h1><button id="enable">Enable Push</button><script>if('serviceWorker'in navigator){navigator.serviceWorker.register('/sw.js')}document.getElementById('enable').onclick=async()=>{const reg=await navigator.serviceWorker.ready;const res=await fetch('/api/push/vapid/public-key');const {publicKey}=await res.json();const sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:Uint8Array.from(atob(publicKey.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0))});await fetch('/api/push/subscribe',{method:'POST',headers:{'Content-Type':'application/json'},body: JSON.stringify(sub)});alert('Device registered for push.');};</script></body></html>
EOT

    cat > "$ROOT_DIR/services/pwa/sw.js" << 'EOT'
self.addEventListener('push',event=>{const d=event.data?event.data.text():'Hello';event.waitUntil(self.registration.showNotification('PWA',{body:d}))});
EOT

    cat > "$ROOT_DIR/services/pwa/Dockerfile" << 'EOT'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY sw.js /usr/share/nginx/html/sw.js
EOT

    # Create sample templates and flows
    create_sample_files() {
        echo -e "${YELLOW}Creating sample files...${NC}"
        
        # Sample Word template for DocGen
        mkdir -p "$ROOT_DIR/services/docgen/templates"
        cat > "$ROOT_DIR/services/docgen/templates/loan_offer.docx" << 'EOT'
# Loan Agreement

This agreement is made between [Your Company] and {{customer_name}}.

Loan Amount: {{loan_amount}}
Interest Rate: {{interest_rate}}%
Date: {{date}}

[Additional terms and conditions...]
EOT

        # Sample signing flow for DocSign
        mkdir -p "$ROOT_DIR/services/docsign/flows"
        cat > "$ROOT_DIR/services/docsign/flows/sample_flow.json" << 'EOT'
{
  "flow_id": "contract_123",
  "status": "in_progress",
  "document": "loan_agreement.pdf",
  "signers": [
    {
      "name": "Alice",
      "email": "alice@example.com",
      "department": "Legal",
      "signed": true,
      "timestamp": "2025-12-03T10:00:00Z"
    },
    {
      "name": "Bob",
      "email": "bob@example.com",
      "department": "Finance",
      "signed": false
    }
  ]
}
EOT
    }

    # Create Caddy configuration
    create_caddy_config() {
        echo -e "${YELLOW}Creating Caddy configuration...${NC}"
        
        mkdir -p "$ROOT_DIR/services/caddy"
        cat > "$ROOT_DIR/services/caddy/Caddyfile" << 'EOT'
# Global settings
{
    email etu.moses@gmail.com
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

# HTTP to HTTPS redirect
mint.weareupsyd.com, www.mint.weareupsyd.com {
    redir https://mint.weareupsyd.com{uri} permanent
}

# Main domain with path-based routing
https://mint.weareupsyd.com {
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # API Gateway
    handle_path /api/* {
        reverse_proxy gateway:80
    }

    # AI Services
    handle_path /ai/stt/* {
        # Rate limiting for STT
        @stt_ratelimit {
            path /ai/stt/transcribe
            rate_limit {
                zone stt 100 1m
            }
        }
        handle @stt_ratelimit {
            rate_limit stt
            reverse_proxy stt-service:8000
        }
        reverse_proxy stt-service:8000
    }

    handle_path /ai/tts/* {
        reverse_proxy tts-service:9000
    }

    handle_path /ai/llm/* {
        reverse_proxy llm-service:8080
    }

    # Documentation
    handle_path /docs* {
        root * /srv/docs
        file_server
        header Cache-Control "public, max-age=3600"
    }

    # Status page (protected with basic auth)
    handle_path /status* {
        basicauth {
            status $2a$10$J9nXm3eXyY1qZK5pX5X5Xe
        }
        reverse_proxy status-dashboard:3000
    }

    # Health checks
    handle_path /health {
        respond "OK" 200
    }

    # Main application
    handle {
        root * /srv
        try_files {path} /index.html
        file_server
        header Cache-Control "no-cache"
    }

    # TLS configuration
    tls {
        issuer acme
    }
}
EOT
    }

    # Function to create service YAML configurations
    create_service_configs() {
        echo -e "\n${BLUE}=== Creating Service Configurations ===${NC}"
        
        # Create services directory if it doesn't exist
        mkdir -p "$ROOT_DIR/services"
        
        # Auth Service
        mkdir -p "$ROOT_DIR/services/auth"
        cat > "$ROOT_DIR/services/auth/config.yaml" << 'EOT'
# Auth Service Configuration
database:
  host: postgres
  port: 5432
  name: authdb
  user: authuser
  password: ${DB_PASSWORD}

server:
  port: 8001
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

jwt:
  secret: ${JWT_SECRET}
  accessTokenExpiration: 15m
  refreshTokenExpiration: 7d

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

rateLimit:
  windowMs: 15m
  max: 100

externalServices:
  emailProvider: sendgrid
  storageProvider: minio
EOT

        # Documents Service
        mkdir -p "$ROOT_DIR/services/documents"
        cat > "$ROOT_DIR/services/documents/config.yaml" << 'EOT'
# Documents Service Configuration
server:
  port: 8008
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

storage:
  type: minio
  endpoint: minio:9000
  accessKey: ${MINIO_ACCESS_KEY}
  secretKey: ${MINIO_SECRET_KEY}
  bucketName: documents
  useSSL: false

database:
  host: postgres
  port: 5432
  name: documents
  user: ${DB_USER}
  password: ${DB_PASSWORD}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000
EOT

        # AI Services Common Config
        mkdir -p "$ROOT_DIR/services/ai"
        cat > "$ROOT_DIR/services/ai/common.yaml" << 'EOT'
# Common AI Services Configuration
server:
  port: 8000
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

rateLimit:
  windowMs: 15m
  max: 100

auth:
  required: true
  jwksUri: https://mint.weareupsyd.com/.well-known/jwks.json
EOT

        # STT Service
        mkdir -p "$ROOT_DIR/services/stt"
        cat > "$ROOT_DIR/services/stt/config.yaml" << 'EOT'
# Speech-to-Text Service Configuration
server:
  port: 8000
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

stt:
  model: ${STT_MODEL:-base}
  language: ${STT_LANGUAGE:-en}
  device: ${STT_DEVICE:-cpu}

ollama:
  url: ${OLLAMA_URL:-http://ollama:11434}
  model: ${OLLAMA_MODEL:-llama3}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

        echo -e "${GREEN}✓ Service configurations created${NC}"
    }

    # Function to install system dependencies for frontend development
    install_frontend_dependencies() {
        echo -e "\n${BLUE}=== Installing System Dependencies ===${NC}"
        
        # Check OS type
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo -e "${YELLOW}Detected Linux system. Installing dependencies...${NC}"
            
            # Update package lists
            if command -v apt-get >/dev/null 2>&1; then
                # Debian/Ubuntu
                sudo apt-get update
                sudo apt-get install -y \
                    build-essential \
                    libcairo2-dev \
                    libpango1.0-dev \
                    libjpeg-dev \
                    libgif-dev \
                    librsvg2-dev \
                    libxi-dev \
                    libx11-dev \
                    libxft-dev \
                    libxext-dev \
                    libgl1-mesa-dev \
                    libglu1-mesa-dev \
                    libxrender1 \
                    libxkbcommon-x11-0 \
                    libxcb-xinerama0 \
                    xvfb \
                    libgtk-3-0 \
                    libgbm1 \
                    libnss3 \
                    libasound2 \
                    libatk1.0-0 \
                    libatk-bridge2.0-0 \
                    libcups2 \
                    libdrm2 \
                    libxcomposite1 \
                    libxdamage1 \
                    libxfixes3 \
                    libxrandr2 \
                    libgbm1 \
                    libxkbcommon0 \
                    libpci3 \
                    libxshmfence1 \
                    libxss1 \
                    libxcb1 \
                    libxcb-dri3-0 \
                    libxtst6 \
                    libnss3 \
                    libatspi2.0-0 \
                    libcups2 \
                    libx11-xcb1 \
                    libxcb-dri3-0 \
                    libxcomposite1 \
                    libxcursor1 \
                    libxdamage1 \
                    libxfixes3 \
                    libxi6 \
                    libxrandr2 \
                    libxrender1 \
                    libxtst6 \
                    libasound2 \
                    libatk-bridge2.0-0 \
                    libatk1.0-0 \
                    libc6 \
                    libcairo2 \
                    libcups2 \
                    libdbus-1-3 \
                    libdrm2 \
                    libexpat1 \
                    libfontconfig1 \
                    libgbm1 \
                    libgcc1 \
                    libgdk-pixbuf2.0-0 \
                    libglib2.0-0 \
                    libgtk-3-0 \
                    libnspr4 \
                    libnss3 \
                    libpango-1.0-0 \
                    libpangocairo-1.0-0 \
                    libx11-6 \
                    libx11-xcb1 \
                    libxcb1 \
                    libxcomposite1 \
                    libxcursor1 \
                    libxdamage1 \
                    libxext6 \
                    libxfixes3 \
                    libxi6 \
                    libxrandr2 \
                    libxrender1 \
                    libxss1 \
                    libxtst6 \
                    wget \
                    curl \
                    git
                    
            elif command -v yum >/dev/null 2>&1; then
                # RHEL/CentOS
                sudo yum groupinstall -y 'Development Tools'
                sudo yum install -y \
                    libX11-devel \
                    libXcomposite-devel \
                    libXcursor-devel \
                    libXdamage-devel \
                    libXext-devel \
                    libXi-devel \
                    libXrandr-devel \
                    libXrender-devel \
                    libXtst-devel \
                    atk-devel \
                    cups-devel \
                    gtk3-devel \
                    nss-devel \
                    pango-devel \
                    xorg-x11-server-Xvfb \
                    wget \
                    curl \
                    git
            fi
            
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            echo -e "${YELLOW}Detected macOS. Please ensure Xcode Command Line Tools are installed.${NC}"
            xcode-select --install || true
            
            # Install Homebrew if not installed
            if ! command -v brew >/dev/null 2>&1; then
                echo -e "${YELLOW}Installing Homebrew...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            
            # Install dependencies
            echo -e "${YELLOW}Installing dependencies using Homebrew...${NC}"
            brew install pkg-config cairo pango libpng jpeg giflib librsvg
            
        else
            echo -e "${YELLOW}Unsupported operating system. Some dependencies may need to be installed manually.${NC}"
        fi
        
        echo -e "${GREEN}✓ System dependencies installed${NC}"
    }

    # Function to build frontend applications
    build_frontend() {
        echo -e "\n${BLUE}=== Building Frontend Applications ===${NC}"
        
        # Check if frontend directory exists
        if [ ! -d "$ROOT_DIR/frontend" ]; then
            echo -e "${YELLOW}Frontend directory not found at $ROOT_DIR/frontend${NC}"
            echo -e "Creating frontend directory..."
            mkdir -p "$ROOT_DIR/frontend"
        fi
        
        # Install system dependencies
        install_frontend_dependencies
        
        # Run the build script
        if [ -f "$ROOT_DIR/build-frontend.sh" ]; then
            echo -e "\n${YELLOW}Starting frontend build process...${NC}"
            chmod +x "$ROOT_DIR/build-frontend.sh"
            "$ROOT_DIR/build-frontend.sh"
            
            if [ $? -eq 0 ]; then
                echo -e "\n${GREEN}✓ Frontend build completed successfully!${NC}"
                echo -e "\n${BLUE}Development Servers:${NC}"
                echo -e "- Realtime Transcriber: http://localhost:3000"
                echo -e "- ElevenLabs Voice Agent: http://localhost:3001"
                return 0
            else
                echo -e "\n${RED}✗ Frontend build failed. Please check the logs above for errors.${NC}"
                return 1
            fi
        else
            echo -e "${RED}Error: Frontend build script not found at $ROOT_DIR/build-frontend.sh${NC}"
            return 1
        fi
    }

    # Function to create YAML configuration files for each service
    create_service_configs() {
        echo -e "\n${BLUE}=== Creating Service Configurations ===${NC}"
        
        # Create YAML configuration files for each service
        for service in "${SERVICES[@]}"; do
            config_file="${ROOT_DIR}/${service}/config.yaml"
            echo -e "${YELLOW}Creating configuration file for ${service} service...${NC}"
            cat > "${config_file}" << 'EOT'
service:
  name: ${service}
  port: 8000
  cors:
    allowedOrigins:
      - https://mint.weareupsyd.com
      - http://localhost:3000
  auth:
    required: true
EOT
            echo -e "${GREEN}✓ Configuration file created for ${service} service${NC}"
        done
    }

    # Create service configuration files
    create_service_configs() {
        echo -e "\n${BLUE}=== Creating Service Configurations ===${NC}"
        
        # Create services directory if it doesn't exist
        mkdir -p "$ROOT_DIR/services"
        
        # Auth Service
        mkdir -p "$ROOT_DIR/services/auth"
        cat > "$ROOT_DIR/services/auth/config.yaml" << 'EOT'
# Auth Service Configuration
database:
  host: postgres
  port: 5432
  name: authdb
  user: authuser
  password: ${DB_PASSWORD}

server:
  port: 8001
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

jwt:
  secret: ${JWT_SECRET}
  accessTokenExpiration: 15m
  refreshTokenExpiration: 7d

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

rateLimit:
  windowMs: 15m
  max: 100

externalServices:
  emailProvider: sendgrid
  storageProvider: minio
EOT

        # Documents Service
        mkdir -p "$ROOT_DIR/services/documents"
        cat > "$ROOT_DIR/services/documents/config.yaml" << 'EOT'
# Documents Service Configuration
server:
  port: 8008
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

storage:
  type: minio
  endpoint: minio:9000
  accessKey: ${MINIO_ACCESS_KEY}
  secretKey: ${MINIO_SECRET_KEY}
  bucketName: documents
  useSSL: false

database:
  host: postgres
  port: 5432
  name: documents
  user: ${DB_USER}
  password: ${DB_PASSWORD}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000
EOT

        # AI Services Common Config
        mkdir -p "$ROOT_DIR/services/ai"
        cat > "$ROOT_DIR/services/ai/common.yaml" << 'EOT'
# Common AI Services Configuration
server:
  port: 8000
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

rateLimit:
  windowMs: 15m
  max: 100

auth:
  required: true
  jwksUri: https://mint.weareupsyd.com/.well-known/jwks.json
EOT

        # STT Service
        mkdir -p "$ROOT_DIR/services/stt"
        cat > "$ROOT_DIR/services/stt/config.yaml" << 'EOT'
# Speech-to-Text Service Configuration
server:
  port: 8000
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

stt:
  model: ${STT_MODEL:-base}
  language: ${STT_LANGUAGE:-en}
  device: ${STT_DEVICE:-cpu}

ollama:
  url: ${OLLAMA_URL:-http://ollama:11434}
  model: ${OLLAMA_MODEL:-llama3}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

        # TTS Service
        mkdir -p "$ROOT_DIR/services/tts"
        cat > "$ROOT_DIR/services/tts/config.yaml" << 'EOT'
# Text-to-Speech Service Configuration
server:
  port: 9000
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

tts:
  provider: ${TTS_PROVIDER:-coqui}
  voice: ${TTS_VOICE:-tts_models/en/ljspeech/vits}
  model: ${TTS_MODEL:-vits}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

        # LLM Service
        mkdir -p "$ROOT_DIR/services/llm"
        cat > "$ROOT_DIR/services/llm/config.yaml" << 'EOT'
# LLM Service Configuration
server:
  port: 8080
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

llm:
  provider: ${LLM_PROVIDER:-ollama}
  model: ${LLM_MODEL:-qwen:4b}
  temperature: ${LLM_TEMPERATURE:-0.7}
  maxTokens: ${LLM_MAX_TOKENS:-2048}

ollama:
  url: ${OLLAMA_URL:-http://ollama:11434}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    echo -e "${GREEN}✓ Service configurations created${NC}"
}

# Create configurations for additional services listed in nginx config
create_missing_service_configs() {
    echo -e "\n${BLUE}=== Creating Additional Service Configurations ===${NC}"
    
    # Links Service
    mkdir -p "$ROOT_DIR/services/links"
    cat > "$ROOT_DIR/services/links/config.yaml" << 'EOT'
# Links Service Configuration
server:
  port: 8002
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

database:
  host: postgres
  port: 5432
  name: links
  user: ${DB_USER}
  password: ${DB_PASSWORD}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

rateLimit:
  windowMs: 15m
  max: 100

auth:
  required: true
EOT

    # Messaging Service
    mkdir -p "$ROOT_DIR/services/messaging"
    cat > "$ROOT_DIR/services/messaging/config.yaml" << 'EOT'
# Messaging Service Configuration
server:
  port: 8003
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

database:
  host: postgres
  port: 5432
  name: messaging
  user: ${DB_USER}
  password: ${DB_PASSWORD}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # Push Service
    mkdir -p "$ROOT_DIR/services/push"
    cat > "$ROOT_DIR/services/push/config.yaml" << 'EOT'
# Push Notification Service Configuration
server:
  port: 8004
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

webPush:
  vapidPublicKey: ${VAPID_PUBLIC_KEY}
  vapidPrivateKey: ${VAPID_PRIVATE_KEY}
  vapidEmail: ${VAPID_EMAIL}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # OCR Service
    mkdir -p "$ROOT_DIR/services/ocr"
    cat > "$ROOT_DIR/services/ocr/config.yaml" << 'EOT'
# OCR Service Configuration
server:
  port: 8001
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

ocr:
  provider: tesseract
  languages: [eng]
  dpi: 300

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # Voice Service
    mkdir -p "$ROOT_DIR/services/voice"
    cat > "$ROOT_DIR/services/voice/config.yaml" << 'EOT'
# Voice Service Configuration
server:
  port: 8004
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

voice:
  sampleRate: 16000
  channels: 1
  bitDepth: 16
  silenceThreshold: 0.5

stt:
  url: http://stt-service:8000/api/stt

tts:
  url: http://tts-service:9000/api/tts

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # DocGen Service
    mkdir -p "$ROOT_DIR/services/docgen"
    cat > "$ROOT_DIR/services/docgen/config.yaml" << 'EOT'
# Document Generation Service Configuration
server:
  port: 8005
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

templates:
  directory: /app/templates
  defaultFormat: pdf

storage:
  type: minio
  endpoint: minio:9000
  accessKey: ${MINIO_ACCESS_KEY}
  secretKey: ${MINIO_SECRET_KEY}
  bucketName: documents
  useSSL: false

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # DocSign Service
    mkdir -p "$ROOT_DIR/services/docsign"
    cat > "$ROOT_DIR/services/docsign/config.yaml" << 'EOT'
# Document Signing Service Configuration
server:
  port: 8006
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

signing:
  defaultExpiry: 30d
  defaultFormat: pdf

storage:
  type: minio
  endpoint: minio:9000
  accessKey: ${MINIO_ACCESS_KEY}
  secretKey: ${MINIO_SECRET_KEY}
  bucketName: documents
  useSSL: false

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # Rules Service
    mkdir -p "$ROOT_DIR/services/rules"
    cat > "$ROOT_DIR/services/rules/config.yaml" << 'EOT'
# Rules Engine Service Configuration
server:
  port: 8007
  environment: ${NODE_ENV:-development}
  logLevel: ${LOG_LEVEL:-info}

rules:
  directory: /app/rules
  defaultFormat: json

database:
  host: postgres
  port: 5432
  name: rules
  user: ${DB_USER}
  password: ${DB_PASSWORD}

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000

auth:
  required: true
EOT

    # PWA Configuration
    mkdir -p "$ROOT_DIR/services/pwa"
    cat > "$ROOT_DIR/services/pwa/config.yaml" << 'EOT'
# Progressive Web App Configuration
server:
  port: 80
  environment: ${NODE_ENV:-production}
  logLevel: ${LOG_LEVEL:-info}

pwa:
  name: "AI Platform"
  shortName: "AIPlatform"
  themeColor: "#2563eb"
  backgroundColor: "#ffffff"
  display: "standalone"
  scope: "/"
  startUrl: "/"

api:
  baseUrl: "/api"
  authUrl: "/auth"

cors:
  allowedOrigins:
    - https://mint.weareupsyd.com
    - http://localhost:3000
EOT

echo -e "${GREEN}✓ Additional service configurations created${NC}"
}

add_stt_service() {
    echo -e "${YELLOW}Adding STT service with Ollama integration...${NC}"
    
    # Create STT service directory
    mkdir -p "$ROOT_DIR/services/stt"
    
    # Create requirements.txt
    cat > "$ROOT_DIR/services/stt/requirements.txt" << 'EOT'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
torch>=2.0.0
torchaudio>=2.0.0
transformers>=4.28.0
soundfile>=0.12.1
numpy>=1.24.2
python-multipart>=0.0.6
python-dotenv>=1.0.0
aiohttp>=3.8.0
EOT

    # Create Dockerfile
    cat > "$ROOT_DIR/services/stt/Dockerfile" << 'EOT'
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create models directory
RUN mkdir -p /root/.cache/whisper

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOT

    # Create main.py
    cat > "$ROOT_DIR/services/stt/main.py" << 'EOT'
from fastapi import FastAPI, UploadFile, HTTPException, status, WebSocket
from fastapi.middleware.cors import CORSMiddleware
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
import torchaudio
import io
import os
import logging
import aiohttp
from typing import Optional
from pydantic import BaseModel

app = FastAPI(title="Speech-to-Text Service with Ollama")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
MODEL_NAME = os.getenv("WHISPER_MODEL", "tiny")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen:4b")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Model and processor
model = None
processor = None

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    ollama_connected: bool

async def check_ollama_connection() -> bool:
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{OLLAMA_URL}/api/tags") as response:
                return response.status == 200
    except Exception:
        return False

@app.on_event("startup")
async def load_model():
    global model, processor
    try:
        model_path = os.getenv("MODEL_PATH", "/root/.cache/whisper")
        
        logger.info(f"Loading Whisper model: {MODEL_NAME}")
        model = WhisperForConditionalGeneration.from_pretrained(
            f"openai/whisper-{MODEL_NAME}",
            cache_dir=model_path,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=True,
        )
        processor = WhisperProcessor.from_pretrained(
            f"openai/whisper-{MODEL_NAME}",
            cache_dir=model_path
        )
        logger.info("Model and processor loaded successfully")
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise

@app.get("/health")
async def health_check():
    ollama_connected = await check_ollama_connection()
    return {
        "status": "healthy" if model is not None else "model not loaded",
        "model_loaded": model is not None,
        "ollama_connected": ollama_connected
    }

@app.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile,
    language: str = "en",
    post_process: bool = False
):
    if not model or not processor:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model not loaded"
        )
    
    try:
        # Read and process audio
        content = await audio.read()
        audio_data, sample_rate = torchaudio.load(io.BytesIO(content), format=audio.filename.split('.')[-1])
        
        # Convert to mono if stereo
        if len(audio_data.shape) > 1 and audio_data.shape[0] > 1:
            audio_data = torch.mean(audio_data, dim=0, keepdim=True)
        
        # Resample if needed
        if sample_rate != 16000:
            resampler = torchaudio.transforms.Resample(orig_freq=sample_rate, new_freq=16000)
            audio_data = resampler(audio_data)
        
        # Get input features
        input_features = processor(
            audio_data.squeeze().numpy(),
            sampling_rate=16000,
            return_tensors="pt"
        ).input_features
        
        # Generate token ids
        predicted_ids = model.generate(input_features)
        
        # Decode token ids to text
        transcription = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0]
        
        return {
            "transcription": transcription,
            "language": language,
            "model": f"whisper-{MODEL_NAME}",
            "post_processed": post_process
        }
    
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error processing audio: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOT

    echo -e "${GREEN}STT service added successfully${NC}"
    echo -e "${YELLOW}To use the STT service, add the following to your docker-compose.yml:${NC}"
    cat << 'COMPOSE'
  stt-service:
    build: ./services/stt
    container_name: stt-service
    ports:
      - "8000:8000"
    environment:
      - OLLAMA_URL=http://ollama:11434
      - WHISPER_MODEL=tiny
      - OLLAMA_MODEL=llama3
    volumes:
      - stt_models:/root/.cache/whisper
    depends_on:
      - ollama
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 8G

# Add to volumes section:
volumes:
  ollama_data:
  stt_models:
COMPOSE
}


# Function to display the main menu
show_menu() {
    clear
    echo -e "${BLUE}=== AI Platform Superstack Management ===${NC}"
    echo -e "${GREEN}1.${NC} Setup and initialize all services"
    echo -e "${GREEN}2.${NC} Build frontend applications"
    echo -e "${GREEN}3.${NC} Start all services"
    echo -e "${GREEN}4.${NC} Stop all services"
    echo -e "${GREEN}5.${NC} View service status"
    echo -e "${GREEN}6.${NC} View logs"
    echo -e "${GREEN}7.${NC} Add STT Service with Ollama"
    echo -e "${GREEN}0.${NC} Exit"
    echo -e "\n${YELLOW}Select an option (0-7): ${NC}"
}

# Function to handle menu selection
handle_menu_selection() {
    local choice
    read -r -p "" choice
    case $choice in
        1)
            echo -e "\n${BLUE}=== Setting up and initializing all services ===${NC}"
            echo -e "${YELLOW}Creating project directories...${NC}"
            create_directories
            echo -e "${YELLOW}Creating environment files...${NC}"
            create_env_files
            echo -e "${YELLOW}Creating docker-compose configuration...${NC}"
            create_docker_compose
            echo -e "${YELLOW}Creating service files...${NC}"
            create_service_files
            echo -e "${YELLOW}Creating service configurations...${NC}"
            create_service_configs
            create_missing_service_configs
            echo -e "${GREEN}✓ All services have been set up successfully!${NC}"
            echo -e "\n${YELLOW}To start the services, please run:${NC}"
            echo "1. cd $ROOT_DIR"
            echo "2. docker-compose up -d"
            ;;
        2)
            echo -e "\n${BLUE}=== Building frontend applications ===${NC}"
            build_frontend
            ;;
        3)
            echo -e "\n${BLUE}=== Starting all services ===${NC}"
            docker-compose up -d
            echo -e "${GREEN}✓ Services started successfully${NC}"
            ;;
        4)
            echo -e "\n${BLUE}=== Stopping all services ===${NC}"
            docker-compose down
            echo -e "${GREEN}✓ Services stopped successfully${NC}"
            ;;
        5)
            echo -e "\n${BLUE}=== Service Status ===${NC}"
            docker-compose ps
            ;;
        6)
            show_logs_menu
            ;;
        7)
            echo -e "\n${BLUE}=== Adding STT Service with Ollama ===${NC}"
            add_stt_service
            read -p "Press [Enter] to return to the main menu..."
            ;;
        0)
            echo -e "\n${GREEN}Exiting... Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
}

# Function to show logs menu
show_logs_menu() {
    echo -e "\n${BLUE}=== View Logs ===${NC}"
    echo -e "${GREEN}1.${NC} All services"
    echo -e "${GREEN}2.${NC} Frontend services"
    echo -e "${GREEN}3.${NC} Backend services"
    echo -e "${GREEN}4.${NC} Database"
    echo -e "${GREEN}5.${NC} Back to main menu"
    echo -e "\n${YELLOW}Select an option (1-5): ${NC}"
    
    local log_choice
    read -r -p "" log_choice
    case $log_choice in
        1)
            docker-compose logs -f
            ;;
        2)
            docker-compose logs -f realtime-transcriber eleven-labs-voice-agent
            ;;
        3)
            docker-compose logs -f auth-service ocr-service asr-service tts-service voice-service docgen-service docsign-service rules-service
            ;;
        4)
            docker-compose logs -f postgres redis
            ;;
        5)
            return
            ;;
        *)
            echo -e "\n${RED}Invalid option. Returning to main menu.${NC}"
            ;;
    esac
    
    # Return to logs menu after viewing logs
    show_logs_menu
}

# Main menu loop
while true; do
    show_menu
    handle_menu_selection
    
    # Pause to show the result before clearing the screen
    echo -e "\n${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s -r
    
    # If user chose to view logs, don't clear the screen immediately
    if [ "$choice" != "6" ] && [ "$log_choice" != "5" ]; then
        clear
    fi
done

# Run the main function if no arguments are provided
if [ $# -eq 0 ]; then
    main
else
    main "$@"
fi
 

 
 

# =============================
# openapi.yaml (combined summary)
# =============================
cat > "$ROOT"/openapi.yaml << 'OPEN'
openapi: 3.0.3
info:
  title: AI + Auth Superstack API
  version: 1.0.0
  description: |
    # API Documentation
    
    Welcome to the AI Superstack API documentation. This API provides access to various AI services including authentication, messaging, and document processing.
    
    ## Base URL
    All API endpoints are relative to `https://mint.weareupsyd.com`
    
    ## Authentication
    Most endpoints require authentication. Include your JWT token in the `Authorization` header:
    ```
    Authorization: Bearer <your_token>
    ```

servers:
  - url: https://mint.weareupsyd.com
    description: Production server
paths:
  /auth/register: { post: { summary: Register user } }
  /auth/login: { post: { summary: Login (magic, otp, push, whatsapp) } }
  /auth/verify/magic: { get: { summary: Verify magic link } }
  /auth/verify/otp: { post: { summary: Verify OTP } }
  /api/links: { post: { summary: Create short link } }
  /s/{code}: { get: { summary: Resolve short link } }
  /api/messaging/email: { post: { summary: Send email } }
  /api/messaging/whatsapp: { post: { summary: Send WhatsApp } }
  /api/messaging/sms: { post: { summary: Send SMS } }
  /api/push/vapid/public-key: { get: { summary: Get VAPID public key } }
  /api/push/subscribe: { post: { summary: Subscribe device } }
  /api/push/send: { post: { summary: Send push notification } }
  /ai/ocr: { post: { summary: OCR raw } }
  /ai/ocr/structured: { post: { summary: OCR structured (regex) } }
  /ai/asr/stt: { post: { summary: Speech to text } }
  /ai/tts: { post: { summary: Text to speech } }
  /ai/voice/ws: { get: { summary: Voice WebSocket streaming } }
  /ai/docgen/templates: { get: { summary: List templates } }
  /ai/docgen/generate: { post: { summary: Generate document } }
  /ai/docsign/sign: { post: { summary: Sign PDF (metadata) } }
  /ai/rules/evaluate: { post: { summary: Evaluate rules } }
OPEN

# =============================
# README
# =============================
cat > "$ROOT"/README.md << 'MD'
# AI + Auth Superstack

Run all services:
```bash
cd ai-superstack
docker compose up --build -d
```

## Access URLs
- Gateway: http://localhost
- PWA: http://localhost:8080
- API Documentation: https://mint.weareupsyd.com/docs
MD

# Final hints
echo -e "\n✅ Project created under: $ROOT"
echo -e "ℹ️  Edit $ROOT/.env for secrets and API keys, then run:"
echo "   cd $ROOT && docker compose up --build -d"
}

# Main function
main() {
    create_directories
    create_env_files
    create_docker_compose
    create_service_files
    
    echo -e "\n${GREEN}✓ All services and configurations have been created successfully!${NC}"
    echo -e "\nTo start the services, run:"
    echo -e "   cd $ROOT_DIR && docker compose up --build -d"
    echo -e "\nThen access the application at http://localhost"
}

# Run the main function
main "$@"

exit 0
