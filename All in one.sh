#!/usr/bin/env bash
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — CLEAN, CONSISTENT, REFACTORED (Block 1/...)
#
# Purpose:
# - A single big bash script that scaffolds a multi-service AI microservice stack,
#   builds minimal service files, creates a cleaned docker-compose, and provides
#   an interactive management menu.
#
# - This script is intentionally modular: it generates the project layout,
#   .env, docker-compose.yml (clean, deduped), lightweight service skeletons
#   (STT, Documents, Auth, LLM, Rules, ElevenLabs-like WS), and Dockerfiles.
#
# How you'll use it:
# 1) Paste Block 1 (this file) into a new file `all-in-one.sh` in an empty dir.
# 2) Make executable: chmod +x all-in-one.sh
# 3) Run: ./all-in-one.sh
#
# This file is the first block (lines 1..500). It creates the scaffolding and
# the first set of service skeletons. Subsequent blocks will add more services,
# advanced configs, and full implementations. Each block continues the same
# script and appends additional files. Keep pasting subsequent blocks in order.
#
# NOTE:
# - The generated services are safe "developer skeletons" — they run and expose
#   health endpoints. Heavy dependencies (Torch, transformers) are optional and
#   can be toggled in requirements to avoid long builds on dev machines.
# - If you want a lighter dev run, remove heavy deps from requirements files.
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# -------- Colors and formatting ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAG='\033[0;35m'
NC='\033[0m'

# -------- Project root ----------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${BLUE}Project root:${NC} $ROOT_DIR"

# -------- Utility: safe write (creates file only if changed) ----------
_safe_write() {
    # $1 = path, stdin = content
    local path="$1"
    local tmp
    tmp="$(mktemp)"
    cat - >"$tmp"
    if [ -f "$path" ]; then
        if cmp -s "$tmp" "$path"; then
            rm -f "$tmp"
            return 0
        fi
    fi
    mv "$tmp" "$path"
    chmod 644 "$path"
    echo -e "${GREEN}WROTE:${NC} $path"
}

# -------- Create directories ----------
create_directories() {
    echo -e "${YELLOW}Creating directory structure...${NC}"
    mkdir -p "$ROOT_DIR/services"/{auth,stt,tts,asr,ocr,documents,docgen,docsign,voice_streaming,elevenlabs-service,llm-engine,rules,gateway,pwa}
    mkdir -p "$ROOT_DIR/logs"/{caddy,auth,stt,documents,elevenlabs}
    mkdir -p "$ROOT_DIR/data"/{minio,postgres,redis,weaviate,ollama}
    mkdir -p "$ROOT_DIR/volumes"
    mkdir -p "$ROOT_DIR/services/documents"/{templates,output}
    mkdir -p "$ROOT_DIR/services/stt/models"
    echo -e "${GREEN}✓ Directories created${NC}"
}

# -------- Create .env and .env.example ----------
create_env_files() {
    echo -e "${YELLOW}Creating .env and .env.example...${NC}"
    if [ ! -f "$ROOT_DIR/.env" ]; then
        _safe_write "$ROOT_DIR/.env" <<'EOT'
# ========================
# Environment (copy and edit)
# ========================
# Databases
POSTGRES_USER=ai_user
POSTGRES_PASSWORD=ChangeMePostgres123!
POSTGRES_DB=ai_platform
POSTGRES_PORT=5432
POSTGRES_HOST=postgres

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_BUCKET=documents

# Ollama
OLLAMA_URL=http://ollama:11434

# STT / TTS models
STT_MODEL=openai/whisper-tiny
MODEL_CACHE=/root/.cache/models

# General
NODE_ENV=development
LOG_LEVEL=info
EOT
    else
        echo -e "${GREEN}Using existing .env${NC}"
    fi

    if [ ! -f "$ROOT_DIR/.env.example" ]; then
        _safe_write "$ROOT_DIR/.env.example" <<'EOT'
# Copy this to .env and edit values for your environment.
# Example:
# MINIO_ROOT_PASSWORD=supersecret
EOT
    fi
}

# -------- Create cleaned docker-compose --------
create_docker_compose() {
    echo -e "${YELLOW}Generating docker-compose.yml...${NC}"
    _safe_write "$ROOT_DIR/docker-compose.yml" <<'YAML'
version: '3.9'
services:
  # -----------------------
  # Supporting infrastructure
  # -----------------------
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-ai_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-ChangeMePostgres123!}
      POSTGRES_DB:   ${POSTGRES_DB:-ai_platform}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-ai_user} || exit 1"]
      interval: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - ./data/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      retries: 5

  minio:
    image: minio/minio:latest
    container_name: minio
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    command: server /data --console-address ":9001"
    volumes:
      - ./data/minio:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    healthcheck:
      test: ["CMD-SHELL", "curl -fs http://localhost:9000/minio/health/live || exit 1"]
      interval: 20s
      retries: 5

  # -----------------------
  # Core microservices (skeletal)
  # -----------------------
  stt-service:
    build:
      context: ./services/stt
      dockerfile: Dockerfile
    container_name: stt-service
    ports:
      - "8011:8000"
    environment:
      - MODEL_PATH=${MODEL_CACHE:-/root/.cache/models}
      - STT_MODEL=${STT_MODEL:-openai/whisper-tiny}
    volumes:
      - ./services/stt/models:${MODEL_CACHE:-/root/.cache/models}
    depends_on:
      - redis

  documents-service:
    build:
      context: ./services/documents
      dockerfile: Dockerfile
    container_name: documents-service
    ports:
      - "8008:8000"
    volumes:
      - ./services/documents/templates:/app/templates:ro
      - ./services/documents/output:/app/output
    environment:
      - DOCUMENTS_MINIO_ENDPOINT=minio:9000
      - DOCUMENTS_MINIO_ACCESS_KEY=${MINIO_ROOT_USER:-minioadmin}
      - DOCUMENTS_MINIO_SECRET_KEY=${MINIO_ROOT_PASSWORD:-minioadmin}
    depends_on:
      - minio

  auth-service:
    build:
      context: ./services/auth
      dockerfile: Dockerfile
    container_name: auth-service
    ports:
      - "8001:8000"
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-ai_user}:${POSTGRES_PASSWORD:-pass}@postgres:5432/${POSTGRES_DB:-ai_platform}
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis

  llm-engine:
    build:
      context: ./services/llm-engine
      dockerfile: Dockerfile
    container_name: llm-engine
    ports:
      - "8009:8000"
    environment:
      - OLLAMA_BASE_URL=${OLLAMA_URL:-http://ollama:11434}
    depends_on:
      - postgres
      - redis

  elevenlabs-service:
    build:
      context: ./services/elevenlabs-service
      dockerfile: Dockerfile
    container_name: elevenlabs-service
    ports:
      - "8010:8000"
    depends_on:
      - stt-service
      - llm-engine
      - documents-service

  # -----------------------
  # Optional / heavy services (commented out initially)
  # -----------------------
  # ollama:
  #   image: ollama/ollama:latest
  #   container_name: ollama
  #   ports:
  #     - "11434:11434"
  #   volumes:
  #     - ./data/ollama:/root/.ollama

volumes:
  # add per-service volumes here if needed
  stt_models:
YAML
    echo -e "${GREEN}✓ docker-compose.yml generated${NC}"
}

# -------- Service skeleton creators ----------
create_service_files() {
    echo -e "${YELLOW}Generating service skeletons (auth, stt, documents, llm, elevenlabs, rules)...${NC}"

    # -----------------------
    # AUTH SERVICE (skeleton)
    # -----------------------
    mkdir -p "$ROOT_DIR/services/auth"
    _safe_write "$ROOT_DIR/services/auth/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-dotenv>=1.0.0
psycopg2-binary>=2.9
redis>=4.5.0
pydantic>=2.0
REQ

    _safe_write "$ROOT_DIR/services/auth/main.py" <<'PYAUTH'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import logging

app = FastAPI(title="Auth Service (skeleton)")
logging.basicConfig(level=logging.INFO)

class HealthResponse(BaseModel):
    status: str

@app.get("/health")
async def health():
    return HealthResponse(status="healthy")
PYAUTH

    _safe_write "$ROOT_DIR/services/auth/Dockerfile" <<'DFAUTH'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFAUTH

    # -----------------------
    # STT SERVICE (skeleton, CPU-friendly toggles)
    # -----------------------
    mkdir -p "$ROOT_DIR/services/stt"
    _safe_write "$ROOT_DIR/services/stt/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
python-dotenv>=1.0.0
# heavy deps (optional) - comment out if you want a lightweight build:
torch>=2.0.0
torchaudio>=2.0.0
transformers>=4.28.1
soundfile>=0.12.1
numpy>=1.23.0
REQ

    _safe_write "$ROOT_DIR/services/stt/main.py" <<'PYSTT'
# Lightweight STT skeleton with optional model support
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import os, io, logging, base64

app = FastAPI(title="STT Service (skeleton)")
logging.basicConfig(level=logging.INFO)

class Base64Payload(BaseModel):
    audio_base64: str
    filename: str = "upload.wav"

@app.get("/health")
async def health():
    return {"status":"healthy", "model_loaded": False}

@app.post("/api/stt/transcribe")
async def transcribe(file: UploadFile = File(None), payload: Base64Payload = None):
    """
    - Accepts multipart file upload or JSON base64 payload.
    - Returns a mock transcription in skeleton mode.
    """
    if file:
        data = await file.read()
    elif payload:
        data = base64.b64decode(payload.audio_base64)
    else:
        raise HTTPException(status_code=400, detail="No audio provided")

    # In skeleton mode, we return a fixed response; replace with model logic in future blocks.
    return {"transcription":"[skeleton] transcription not enabled in lightweight mode", "length_bytes": len(data)}
PYSTT

    _safe_write "$ROOT_DIR/services/stt/Dockerfile" <<'DFSTT'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y ffmpeg libsndfile1 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFSTT

    # -----------------------
    # DOCUMENTS SERVICE
    # -----------------------
    mkdir -p "$ROOT_DIR/services/documents/templates/sample"
    _safe_write "$ROOT_DIR/services/documents/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
Jinja2>=3.0
PyYAML>=6.0
REQ

    _safe_write "$ROOT_DIR/services/documents/main.py" <<'PYDOCS'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
from pathlib import Path
import yaml, uuid, datetime, logging
from jinja2 import Environment, FileSystemLoader

app = FastAPI(title="Documents Service (skeleton)")
logging.basicConfig(level=logging.INFO)
BASE = Path(__file__).resolve().parent
TEMPLATES = BASE / "templates"
OUT = BASE / "output"
TEMPLATES.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)

class GenReq(BaseModel):
    template: str
    data: Dict[str, Any] = {}
    output_format: str = "html"

@app.get("/health")
async def health():
    templates = [p.name for p in TEMPLATES.iterdir() if p.is_dir()]
    return {"status":"healthy","templates":templates}

@app.post("/generate")
async def generate(req: GenReq):
    tpl_dir = TEMPLATES / req.template
    if not tpl_dir.exists():
        raise HTTPException(status_code=404, detail="Template not found")
    mapping = tpl_dir / "mapping.yaml"
    if not mapping.exists():
        raise HTTPException(status_code=400, detail="mapping.yaml missing")
    cfg = yaml.safe_load(mapping.read_text())
    tpl_file = tpl_dir / cfg.get("template_file")
    env = Environment(loader=FileSystemLoader(str(tpl_dir)))
    tpl = env.get_template(tpl_file.name)
    data = {**cfg.get("sample_data",{}), **req.data}
    if "date" not in data:
        data["date"] = datetime.datetime.utcnow().isoformat()
    rendered = tpl.render(**data)
    doc_id = str(uuid.uuid4())
    out_path = OUT / f"{doc_id}.{req.output_format}"
    out_path.write_text(rendered, encoding="utf-8")
    return {"document_id": doc_id, "path": str(out_path)}
PYDOCS

    _safe_write "$ROOT_DIR/services/documents/Dockerfile" <<'DFDOCS'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFDOCS

    # create a sample template
    _safe_write "$ROOT_DIR/services/documents/templates/sample/mapping.yaml" <<'MAP'
name: "Sample Document"
template_file: "template.html"
sample_data:
  title: "Sample Document"
  recipient_name: "Jane Doe"
  reference_number: "REF-2025-001"
  amount: 123.45
MAP

    _safe_write "$ROOT_DIR/services/documents/templates/sample/template.html" <<'TPL'
<html>
  <head><meta charset="utf-8"><title>{{ title }}</title></head>
  <body>
    <h1>{{ title }}</h1>
    <p>To: {{ recipient_name }}</p>
    <p>Ref: {{ reference_number }}</p>
    <p>Amount: {{ amount }}</p>
    <p>Generated: {{ date }}</p>
  </body>
</html>
TPL

    # -----------------------
    # LLM ENGINE (skeleton)
    # -----------------------
    mkdir -p "$ROOT_DIR/services/llm-engine"
    _safe_write "$ROOT_DIR/services/llm-engine/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
httpx>=0.24
REQ

    _safe_write "$ROOT_DIR/services/llm-engine/main.py" <<'PYLLM'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os, logging, httpx

app = FastAPI(title="LLM Engine (skeleton)")
logging.basicConfig(level=logging.INFO)

class LLMReq(BaseModel):
    prompt: str
    model: str = "local"

@app.get("/health")
async def health():
    return {"status":"healthy","ollama": os.getenv("OLLAMA_BASE_URL", "")}

@app.post("/generate")
async def generate(req: LLMReq):
    # This skeleton proxies to Ollama if available; otherwise returns echo.
    ollama = os.getenv("OLLAMA_BASE_URL")
    if ollama:
        try:
            async with httpx.AsyncClient() as client:
                r = await client.post(f"{ollama}/api/generate", json={"model": req.model, "prompt": req.prompt}, timeout=30.0)
                r.raise_for_status()
                return {"text": r.json()}
        except Exception as e:
            return {"text": f"[proxy error] {str(e)}"}
    return {"text": f"[skeleton] echo: {req.prompt}"}
PYLLM

    _safe_write "$ROOT_DIR/services/llm-engine/Dockerfile" <<'DFLLM'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFLLM

    # -----------------------
    # ElevenLabs-like bridge (skeleton)
    # -----------------------
    mkdir -p "$ROOT_DIR/services/elevenlabs-service"
    _safe_write "$ROOT_DIR/services/elevenlabs-service/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
httpx>=0.24
websockets>=11.0.0
python-dotenv>=1.0.0
REQ

    _safe_write "$ROOT_DIR/services/elevenlabs-service/main.py" <<'PYEL'
import asyncio, logging
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="ElevenLabs Bridge (skeleton)")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"])
logging.basicConfig(level=logging.INFO)

@app.get("/health")
async def health():
    return {"status":"healthy"}

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(ws: WebSocket, client_id: str):
    await ws.accept()
    try:
        while True:
            msg = await ws.receive_text()
            # echo back for now
            await ws.send_text(f"[echo] {msg}")
    except Exception:
        await ws.close()
PYEL

    _safe_write "$ROOT_DIR/services/elevenlabs-service/Dockerfile" <<'DFEL'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFEL

    # -----------------------
    # Rules Engine (skeleton)
    # -----------------------
    mkdir -p "$ROOT_DIR/services/rules"
    _safe_write "$ROOT_DIR/services/rules/requirements.txt" <<'REQR'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
pydantic>=2.0
rule-engine>=4.5.3
REQR

    _safe_write "$ROOT_DIR/services/rules/main.py" <<'PYRULES'
from fastapi import FastAPI
import logging
app = FastAPI(title="Rules Engine (skeleton)")
logging.basicConfig(level=logging.INFO)

@app.get("/health")
async def health():
    return {"status":"healthy","rules_loaded":0}

@app.post("/evaluate")
async def evaluate(payload: dict):
    # Minimal evaluation stub
    return {"matched": False, "decisions": {}}
PYRULES

    _safe_write "$ROOT_DIR/services/rules/Dockerfile" <<'DFRULE'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFRULE

    echo -e "${GREEN}✓ Service skeletons created${NC}"
}

# -------- Simple menu system (safe, improved) ----------
show_menu() {
    cat <<EOF

${MAG}=== Superstack Manager ===${NC}

1) Setup project (dirs, env, skeletons)
2) Build all images (docker-compose build)
3) Start all services (docker-compose up -d)
4) Stop all services (docker-compose down)
5) Status (docker-compose ps)
6) Tail logs (choose a container)
7) Add sample data / seeds
0) Exit

EOF
    printf "Select an option: "
}

menu_loop() {
    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1)
                create_directories
                create_env_files
                create_docker_compose
                create_service_files
                echo -e "${GREEN}Setup completed. Next: docker-compose build${NC}"
                ;;
            2)
                echo -e "${YELLOW}Building images (this may take a while)...${NC}"
                docker-compose build --pull
                ;;
            3)
                echo -e "${YELLOW}Starting services...${NC}"
                docker-compose up -d
                ;;
            4)
                docker-compose down
                ;;
            5)
                docker-compose ps
                ;;
            6)
                echo "Enter container name (eg stt-service):"
                read -r ctn
                docker-compose logs -f "$ctn"
                ;;
            7)
                echo -e "${YELLOW}Seeding sample templates for documents...${NC}"
                # nothing heavy here; sample template already created
                ls -la services/documents/templates || true
                ;;
            0)
                echo -e "${GREEN}Bye${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

# Run menu if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${BLUE}All-in-one setup script (block 1).${NC}"
    echo -e "${YELLOW}Tip: after setup, run option 2 to build images.${NC}"
    menu_loop
fi
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — FULL STT (CPU) + DocSign (Block 2/...)
#
# Paste this directly after Block 1 in your `all-in-one.sh` file.
# This block:
#  - Replaces the lightweight STT skeleton with a CPU-optimized, production-like
#    STT service (Whisper via transformers + torchaudio) configured for CPU-only.
#  - Adds a DocSign service that accepts a PDF and a signature (image or text),
#    then overlays the signature onto the last page and returns the signed PDF.
#  - Writes docker-compose.override.yml so you don't lose the cleaned compose.
#
# IMPORTANT:
#  - These services will build locally and may take time due to wheel compilation.
#    To speed builds, prefer installing prebuilt wheels for torch/torchaudio (see README).
#  - All model usage is CPU-only (explicit device set to "cpu"). No GPU bits or CUDA.
# ==============================================================================

# -------- Helper: ensure _safe_write exists (from Block 1) ----------
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo -e "${RED}Error:${NC} _safe_write helper not found. Make sure you pasted Block 1 before Block 2."
  exit 1
fi

# -------------------------------
# Full STT implementation (CPU)
# -------------------------------
create_stt_full() {
    echo -e "${YELLOW}Creating full STT service (CPU-only)...${NC}"
    mkdir -p "$ROOT_DIR/services/stt"
    # requirements: recommend CPU-specific torch wheels if possible
    _safe_write "$ROOT_DIR/services/stt/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
transformers>=4.30.0
torchaudio>=2.2.2
torch>=2.2.2
soundfile>=0.12.1
numpy>=1.24.0
python-dotenv>=1.0.0
pydantic>=2.0
REQ

    # CPU-only optimized Dockerfile: uses manylinux CPU wheel index hint (user may override)
    _safe_write "$ROOT_DIR/services/stt/Dockerfile" <<'DFSTT'
# STT service Dockerfile (CPU-only optimized)
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps needed for audio processing and torch wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    libsndfile1 \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .

# NOTE: If you have a faster way to install CPU wheels (like a local wheelcache),
# edit the requirements or run pip with --find-links to a wheel index.
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create a non-root user to run the app
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
DFSTT

    # Main STT app: CPU-only whisper using transformers + torchaudio
    _safe_write "$ROOT_DIR/services/stt/main.py" <<'PYSTT_MAIN'
"""
STT Service (CPU-only)

Endpoints:
 - GET  /health
 - POST /api/stt/transcribe  (multipart form 'file' or JSON { "audio_base64": "...", "filename": "..." })

Behavior:
 - Loads a small Whisper model by default (openai/whisper-tiny).
 - Forces device to CPU. No CUDA usage.
 - Uses torchaudio to read audio buffers and resamples to 16kHz.
 - Returns plain text transcription.

Notes:
 - This is designed for CPU-only environments. Use a small model for reasonable latency.
 - For production, consider model caching and background downloads.
"""

import os
import io
import base64
import logging
from typing import Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, status
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# optional heavy imports
try:
    import torch
    import torchaudio
    from transformers import WhisperProcessor, WhisperForConditionalGeneration
except Exception as e:
    torch = None
    torchaudio = None
    WhisperProcessor = None
    WhisperForConditionalGeneration = None
    IMPORT_ERROR = str(e)
else:
    IMPORT_ERROR = None

app = FastAPI(title="STT Service (CPU)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

logger = logging.getLogger("stt")
logging.basicConfig(level=logging.INFO)

MODEL = None
PROCESSOR = None
MODEL_NAME = os.getenv("STT_MODEL", os.getenv("STT_MODEL_NAME", "openai/whisper-tiny"))
MODEL_CACHE = os.getenv("MODEL_PATH", "/root/.cache/models")
DEVICE = torch.device("cpu") if torch else None

class Base64Payload(BaseModel):
    audio_base64: str
    filename: Optional[str] = "upload.wav"
    language: Optional[str] = "en"

@app.on_event("startup")
def load_model():
    global MODEL, PROCESSOR
    if IMPORT_ERROR:
        logger.warning("Model libraries not available: %s", IMPORT_ERROR)
        return

    try:
        logger.info("Loading model '%s' into device '%s' (cache=%s)", MODEL_NAME, DEVICE, MODEL_CACHE)
        # load processor + model, forcing CPU (torch device will be cpu)
        PROCESSOR = WhisperProcessor.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        MODEL = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        if torch:
            MODEL.to(DEVICE)
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.exception("Failed to load model: %s", e)
        MODEL = None
        PROCESSOR = None

@app.get("/health")
async def health():
    return {
        "status": "healthy" if MODEL is not None and PROCESSOR is not None else "model not loaded",
        "model": MODEL_NAME,
        "import_error": IMPORT_ERROR or ""
    }

def read_audio_bytes(audio_bytes: bytes):
    """Load audio bytes to waveform (tensor) and sample rate using torchaudio"""
    if torchaudio is None:
        raise RuntimeError("torchaudio not available")
    bio = io.BytesIO(audio_bytes)
    waveform, sr = torchaudio.load(bio)
    # convert to mono
    if waveform.dim() > 1 and waveform.size(0) > 1:
        waveform = waveform.mean(dim=0, keepdim=True)
    # resample to 16000 if needed
    if sr != 16000:
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=16000)
        waveform = resampler(waveform)
        sr = 16000
    return waveform.squeeze(0).numpy(), sr

@app.post("/api/stt/transcribe")
async def transcribe(file: UploadFile = File(None), payload: Base64Payload = None, language: str = "en"):
    """
    Accepts either:
     - multipart 'file'
     - JSON body with base64 audio (POST with JSON)
    Returns: {"transcription": "..."}
    """
    if IMPORT_ERROR:
        raise HTTPException(status_code=503, detail=f"Missing dependencies: {IMPORT_ERROR}")

    if MODEL is None or PROCESSOR is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    audio_bytes = None
    try:
        if file:
            audio_bytes = await file.read()
        elif payload and payload.audio_base64:
            audio_bytes = base64.b64decode(payload.audio_base64)
        else:
            raise HTTPException(status_code=400, detail="No audio provided")

        waveform_np, sr = read_audio_bytes(audio_bytes)

        # Prepare features
        inputs = PROCESSOR(waveform_np, sampling_rate=sr, return_tensors="pt")
        # Ensure tensors on CPU
        inputs = {k: v.to(DEVICE) for k, v in inputs.items()}

        # Generate
        with torch.no_grad():
            predicted_ids = MODEL.generate(**inputs)
        transcription = PROCESSOR.batch_decode(predicted_ids, skip_special_tokens=True)[0]

        return {"transcription": transcription, "language": language}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Transcription failure")
        raise HTTPException(status_code=500, detail=str(e))
PYSTT_MAIN

    echo -e "${GREEN}✓ Full STT service files written${NC}"
}

# -------------------------------------
# DocSign service: overlay signature onto PDF
# CPU-focused; uses ReportLab + PyPDF2 + Pillow
# -------------------------------------
create_docsign_service() {
    echo -e "${YELLOW}Creating DocSign service (PDF signing overlay)...${NC}"
    mkdir -p "$ROOT_DIR/services/docsign"
    _safe_write "$ROOT_DIR/services/docsign/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
Pillow>=9.5.0
reportlab>=4.1.0
PyPDF2>=3.0.0
python-dotenv>=1.0.0
REQ

    _safe_write "$ROOT_DIR/services/docsign/Dockerfile" <<'DFDOCSIGN'
# DocSign Dockerfile (CPU-only)
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFDOCSIGN

    _safe_write "$ROOT_DIR/services/docsign/main.py" <<'PYDOCSIGN'
"""
DocSign Service (CPU)
 - POST /sign  multipart form:
     - file: the PDF to sign
     - name: signatory name (optional)
     - signature: optional image (png/jpg). If omitted, service creates a text-signature image.
 - GET  /health
 - GET  /signed/{filename}  to download signed PDFs from output dir

Implementation notes:
 - Uses ReportLab to create a PDF "overlay" containing the signature image positioned
   at bottom-right of the last page. Then merges that overlay onto the last page
   using PyPDF2's merge_page.
 - All operations are CPU-friendly.
"""

import os
import io
import uuid
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from PIL import Image, ImageDraw, ImageFont
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from PyPDF2 import PdfReader, PdfWriter
from pathlib import Path

app = FastAPI(title="DocSign Service (CPU)")

BASE = Path(__file__).resolve().parent
OUTPUT = BASE / "output"
OUTPUT.mkdir(exist_ok=True)

@app.get("/health")
async def health():
    return {"status": "healthy", "signed_count": len(list(OUTPUT.glob("*.pdf")))}

def create_signature_image(name: str, width=600, height=150):
    """
    Create a simple signature-like image: white background, handwriting-style text.
    For better signatures, user can upload an image.
    """
    img = Image.new("RGBA", (width, height), (255,255,255,0))
    draw = ImageDraw.Draw(img)
    try:
        # Try to use a nicer font if available
        font = ImageFont.truetype("DejaVuSans.ttf", 48)
    except Exception:
        font = ImageFont.load_default()
    text = name or "Signer"
    # center text vertically and horizontally biased to the right (like a signature)
    w, h = draw.textsize(text, font=font)
    x = max(10, width - w - 20)
    y = (height - h) // 2
    draw.text((x, y), text, fill=(10,10,10,255), font=font)
    # add a small flourish: a line under the text
    draw.line((x, y + h + 6, width - 10, y + h + 6), fill=(10,10,10,120), width=2)
    return img

def create_overlay_pdf(signature_img: Image.Image, page_width: float, page_height: float, sig_w: int=200, sig_h: int=80, margin=36):
    """
    Create an in-memory PDF overlay with signature image positioned at bottom-right.
    page_width/page_height are in points (1 point = 1/72 inch)
    """
    packet = io.BytesIO()
    c = canvas.Canvas(packet, pagesize=(page_width, page_height))
    # position signature at bottom-right with margin
    sig_x = page_width - sig_w - margin
    sig_y = margin
    # save PIL image to bytes as PNG for ReportLab
    img_bytes = io.BytesIO()
    signature_img.save(img_bytes, format="PNG")
    img_bytes.seek(0)
    c.drawImage(ImageReader(img_bytes), sig_x, sig_y, width=sig_w, height=sig_h, mask='auto')
    c.save()
    packet.seek(0)
    return packet

# small helper to make reportlab accept PIL image bytes
from reportlab.lib.utils import ImageReader

@app.post("/sign")
async def sign_pdf(file: UploadFile = File(...), name: str = Form(None), signature: UploadFile = File(None)):
    # verify uploaded pdf
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    pdf_bytes = await file.read()
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid PDF: {e}")

    # prepare signature image
    if signature:
        sig_bytes = await signature.read()
        sig_img = Image.open(io.BytesIO(sig_bytes)).convert("RGBA")
    else:
        sig_img = create_signature_image(name or "Signer", width=400, height=120)

    # Get last page size (points)
    last_page = reader.pages[-1]
    media = last_page.mediabox
    # PyPDF2 uses Decimal for coordinates; convert to float
    page_width = float(media.width)
    page_height = float(media.height)

    # scale signature image to a reasonable size relative to page
    target_sig_w = min( int(page_width * 0.35), 500 )
    target_sig_h = int(target_sig_w * (sig_img.height / sig_img.width))
    sig_img = sig_img.resize((target_sig_w, target_sig_h), Image.ANTIALIAS)

    overlay_pdf_stream = create_overlay_pdf(sig_img, page_width, page_height, sig_w=target_sig_w, sig_h=target_sig_h)

    # merge overlay onto last page
    overlay_reader = PdfReader(overlay_pdf_stream)
    overlay_page = overlay_reader.pages[0]

    writer = PdfWriter()
    for i, p in enumerate(reader.pages):
        if i == len(reader.pages) - 1:
            # merge overlay_page onto p
            p.merge_page(overlay_page)
        writer.add_page(p)

    # write out signed PDF
    out_name = f"signed_{uuid.uuid4().hex}.pdf"
    out_path = OUTPUT / out_name
    with open(out_path, "wb") as f:
        writer.write(f)

    return {"signed_file": f"/signed/{out_name}", "path": str(out_path)}

@app.get("/signed/{filename}")
async def get_signed(filename: str):
    path = OUTPUT / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(path, media_type="application/pdf", filename=filename)
PYDOCSIGN

    echo -e "${GREEN}✓ DocSign service files written${NC}"
}

# --------------------------
# docker-compose override (adds/updates docsign and full stt)
# --------------------------
create_docker_compose_override() {
    echo -e "${YELLOW}Writing docker-compose.override.yml (adds docsign + tuned stt)...${NC}"
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
version: '3.9'
services:
  stt-service:
    build:
      context: ./services/stt
      dockerfile: Dockerfile
    container_name: stt-service
    ports:
      - "8011:8000"
    environment:
      - MODEL_PATH=/root/.cache/models
      - STT_MODEL=openai/whisper-tiny
    volumes:
      - ./services/stt/models:/root/.cache/models

  docsign:
    build:
      context: ./services/docsign
      dockerfile: Dockerfile
    container_name: docsign
    ports:
      - "8012:8000"
    volumes:
      - ./services/docsign/output:/app/output
YAML
    echo -e "${GREEN}✓ docker-compose.override.yml written${NC}"
}

# --------------------------
# Register new actions in menu (optional)
# --------------------------
register_block2_menu_actions() {
    # This appends convenience functions to the running shell session if user wants to call them manually.
    echo -e "${YELLOW}Registering Block2 convenience functions...${NC}"
    echo -e "${BLUE}To create full STT and DocSign services, run:${NC}"
    echo "  ./all-in-one.sh (option 1) OR call these functions in a shell where _safe_write exists:"
    echo "  create_stt_full"
    echo "  create_docsign_service"
    echo "  create_docker_compose_override"
    echo -e "${YELLOW}If you re-run menu option 1 (Setup project), these files will be created automatically.${NC}"
}

# --------------------------
# Execute creation right away if user has already run setup (idempotent)
# --------------------------
# If services folders already exist from Block 1, we still overwrite with improved files.
create_stt_full
create_docsign_service
create_docker_compose_override
register_block2_menu_actions

echo -e "${GREEN}Block 2 created: full STT (CPU) and DocSign services.${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1) docker-compose build stt-service docsign --pull"
echo "  2) docker-compose up -d stt-service docsign"
echo ""
echo "Health endpoints:"
echo "  STT:   http://localhost:8011/health"
echo "  DocSign: http://localhost:8012/health"
echo ""
echo "Test DocSign:"
echo "  curl -X POST http://localhost:8012/sign -F \"file=@/path/to/input.pdf\" -F \"name=Alice\" -o /dev/null && echo 'done'"
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — FULL STT (CPU) + DocSign (Block 2/...)
#
# Paste this directly after Block 1 in your `all-in-one.sh` file.
# This block:
#  - Replaces the lightweight STT skeleton with a CPU-optimized, production-like
#    STT service (Whisper via transformers + torchaudio) configured for CPU-only.
#  - Adds a DocSign service that accepts a PDF and a signature (image or text),
#    then overlays the signature onto the last page and returns the signed PDF.
#  - Writes docker-compose.override.yml so you don't lose the cleaned compose.
#
# IMPORTANT:
#  - These services will build locally and may take time due to wheel compilation.
#    To speed builds, prefer installing prebuilt wheels for torch/torchaudio (see README).
#  - All model usage is CPU-only (explicit device set to "cpu"). No GPU bits or CUDA.
# ==============================================================================

# -------- Helper: ensure _safe_write exists (from Block 1) ----------
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo -e "${RED}Error:${NC} _safe_write helper not found. Make sure you pasted Block 1 before Block 2."
  exit 1
fi

# -------------------------------
# Full STT implementation (CPU)
# -------------------------------
create_stt_full() {
    echo -e "${YELLOW}Creating full STT service (CPU-only)...${NC}"
    mkdir -p "$ROOT_DIR/services/stt"
    # requirements: recommend CPU-specific torch wheels if possible
    _safe_write "$ROOT_DIR/services/stt/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
transformers>=4.30.0
torchaudio>=2.2.2
torch>=2.2.2
soundfile>=0.12.1
numpy>=1.24.0
python-dotenv>=1.0.0
pydantic>=2.0
REQ

    # CPU-only optimized Dockerfile: uses manylinux CPU wheel index hint (user may override)
    _safe_write "$ROOT_DIR/services/stt/Dockerfile" <<'DFSTT'
# STT service Dockerfile (CPU-only optimized)
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps needed for audio processing and torch wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    libsndfile1 \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .

# NOTE: If you have a faster way to install CPU wheels (like a local wheelcache),
# edit the requirements or run pip with --find-links to a wheel index.
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create a non-root user to run the app
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
DFSTT

    # Main STT app: CPU-only whisper using transformers + torchaudio
    _safe_write "$ROOT_DIR/services/stt/main.py" <<'PYSTT_MAIN'
"""
STT Service (CPU-only)

Endpoints:
 - GET  /health
 - POST /api/stt/transcribe  (multipart form 'file' or JSON { "audio_base64": "...", "filename": "..." })

Behavior:
 - Loads a small Whisper model by default (openai/whisper-tiny).
 - Forces device to CPU. No CUDA usage.
 - Uses torchaudio to read audio buffers and resamples to 16kHz.
 - Returns plain text transcription.

Notes:
 - This is designed for CPU-only environments. Use a small model for reasonable latency.
 - For production, consider model caching and background downloads.
"""

import os
import io
import base64
import logging
from typing import Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, status
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# optional heavy imports
try:
    import torch
    import torchaudio
    from transformers import WhisperProcessor, WhisperForConditionalGeneration
except Exception as e:
    torch = None
    torchaudio = None
    WhisperProcessor = None
    WhisperForConditionalGeneration = None
    IMPORT_ERROR = str(e)
else:
    IMPORT_ERROR = None

app = FastAPI(title="STT Service (CPU)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

logger = logging.getLogger("stt")
logging.basicConfig(level=logging.INFO)

MODEL = None
PROCESSOR = None
MODEL_NAME = os.getenv("STT_MODEL", os.getenv("STT_MODEL_NAME", "openai/whisper-tiny"))
MODEL_CACHE = os.getenv("MODEL_PATH", "/root/.cache/models")
DEVICE = torch.device("cpu") if torch else None

class Base64Payload(BaseModel):
    audio_base64: str
    filename: Optional[str] = "upload.wav"
    language: Optional[str] = "en"

@app.on_event("startup")
def load_model():
    global MODEL, PROCESSOR
    if IMPORT_ERROR:
        logger.warning("Model libraries not available: %s", IMPORT_ERROR)
        return

    try:
        logger.info("Loading model '%s' into device '%s' (cache=%s)", MODEL_NAME, DEVICE, MODEL_CACHE)
        # load processor + model, forcing CPU (torch device will be cpu)
        PROCESSOR = WhisperProcessor.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        MODEL = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        if torch:
            MODEL.to(DEVICE)
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.exception("Failed to load model: %s", e)
        MODEL = None
        PROCESSOR = None

@app.get("/health")
async def health():
    return {
        "status": "healthy" if MODEL is not None and PROCESSOR is not None else "model not loaded",
        "model": MODEL_NAME,
        "import_error": IMPORT_ERROR or ""
    }

def read_audio_bytes(audio_bytes: bytes):
    """Load audio bytes to waveform (tensor) and sample rate using torchaudio"""
    if torchaudio is None:
        raise RuntimeError("torchaudio not available")
    bio = io.BytesIO(audio_bytes)
    waveform, sr = torchaudio.load(bio)
    # convert to mono
    if waveform.dim() > 1 and waveform.size(0) > 1:
        waveform = waveform.mean(dim=0, keepdim=True)
    # resample to 16000 if needed
    if sr != 16000:
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=16000)
        waveform = resampler(waveform)
        sr = 16000
    return waveform.squeeze(0).numpy(), sr

@app.post("/api/stt/transcribe")
async def transcribe(file: UploadFile = File(None), payload: Base64Payload = None, language: str = "en"):
    """
    Accepts either:
     - multipart 'file'
     - JSON body with base64 audio (POST with JSON)
    Returns: {"transcription": "..."}
    """
    if IMPORT_ERROR:
        raise HTTPException(status_code=503, detail=f"Missing dependencies: {IMPORT_ERROR}")

    if MODEL is None or PROCESSOR is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    audio_bytes = None
    try:
        if file:
            audio_bytes = await file.read()
        elif payload and payload.audio_base64:
            audio_bytes = base64.b64decode(payload.audio_base64)
        else:
            raise HTTPException(status_code=400, detail="No audio provided")

        waveform_np, sr = read_audio_bytes(audio_bytes)

        # Prepare features
        inputs = PROCESSOR(waveform_np, sampling_rate=sr, return_tensors="pt")
        # Ensure tensors on CPU
        inputs = {k: v.to(DEVICE) for k, v in inputs.items()}

        # Generate
        with torch.no_grad():
            predicted_ids = MODEL.generate(**inputs)
        transcription = PROCESSOR.batch_decode(predicted_ids, skip_special_tokens=True)[0]

        return {"transcription": transcription, "language": language}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Transcription failure")
        raise HTTPException(status_code=500, detail=str(e))
PYSTT_MAIN

    echo -e "${GREEN}✓ Full STT service files written${NC}"
}

# -------------------------------------
# DocSign service: overlay signature onto PDF
# CPU-focused; uses ReportLab + PyPDF2 + Pillow
# -------------------------------------
create_docsign_service() {
    echo -e "${YELLOW}Creating DocSign service (PDF signing overlay)...${NC}"
    mkdir -p "$ROOT_DIR/services/docsign"
    _safe_write "$ROOT_DIR/services/docsign/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
Pillow>=9.5.0
reportlab>=4.1.0
PyPDF2>=3.0.0
python-dotenv>=1.0.0
REQ

    _safe_write "$ROOT_DIR/services/docsign/Dockerfile" <<'DFDOCSIGN'
# DocSign Dockerfile (CPU-only)
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFDOCSIGN

    _safe_write "$ROOT_DIR/services/docsign/main.py" <<'PYDOCSIGN'
"""
DocSign Service (CPU)
 - POST /sign  multipart form:
     - file: the PDF to sign
     - name: signatory name (optional)
     - signature: optional image (png/jpg). If omitted, service creates a text-signature image.
 - GET  /health
 - GET  /signed/{filename}  to download signed PDFs from output dir

Implementation notes:
 - Uses ReportLab to create a PDF "overlay" containing the signature image positioned
   at bottom-right of the last page. Then merges that overlay onto the last page
   using PyPDF2's merge_page.
 - All operations are CPU-friendly.
"""

import os
import io
import uuid
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from PIL import Image, ImageDraw, ImageFont
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from PyPDF2 import PdfReader, PdfWriter
from pathlib import Path

app = FastAPI(title="DocSign Service (CPU)")

BASE = Path(__file__).resolve().parent
OUTPUT = BASE / "output"
OUTPUT.mkdir(exist_ok=True)

@app.get("/health")
async def health():
    return {"status": "healthy", "signed_count": len(list(OUTPUT.glob("*.pdf")))}

def create_signature_image(name: str, width=600, height=150):
    """
    Create a simple signature-like image: white background, handwriting-style text.
    For better signatures, user can upload an image.
    """
    img = Image.new("RGBA", (width, height), (255,255,255,0))
    draw = ImageDraw.Draw(img)
    try:
        # Try to use a nicer font if available
        font = ImageFont.truetype("DejaVuSans.ttf", 48)
    except Exception:
        font = ImageFont.load_default()
    text = name or "Signer"
    # center text vertically and horizontally biased to the right (like a signature)
    w, h = draw.textsize(text, font=font)
    x = max(10, width - w - 20)
    y = (height - h) // 2
    draw.text((x, y), text, fill=(10,10,10,255), font=font)
    # add a small flourish: a line under the text
    draw.line((x, y + h + 6, width - 10, y + h + 6), fill=(10,10,10,120), width=2)
    return img

def create_overlay_pdf(signature_img: Image.Image, page_width: float, page_height: float, sig_w: int=200, sig_h: int=80, margin=36):
    """
    Create an in-memory PDF overlay with signature image positioned at bottom-right.
    page_width/page_height are in points (1 point = 1/72 inch)
    """
    packet = io.BytesIO()
    c = canvas.Canvas(packet, pagesize=(page_width, page_height))
    # position signature at bottom-right with margin
    sig_x = page_width - sig_w - margin
    sig_y = margin
    # save PIL image to bytes as PNG for ReportLab
    img_bytes = io.BytesIO()
    signature_img.save(img_bytes, format="PNG")
    img_bytes.seek(0)
    c.drawImage(ImageReader(img_bytes), sig_x, sig_y, width=sig_w, height=sig_h, mask='auto')
    c.save()
    packet.seek(0)
    return packet

# small helper to make reportlab accept PIL image bytes
from reportlab.lib.utils import ImageReader

@app.post("/sign")
async def sign_pdf(file: UploadFile = File(...), name: str = Form(None), signature: UploadFile = File(None)):
    # verify uploaded pdf
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    pdf_bytes = await file.read()
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid PDF: {e}")

    # prepare signature image
    if signature:
        sig_bytes = await signature.read()
        sig_img = Image.open(io.BytesIO(sig_bytes)).convert("RGBA")
    else:
        sig_img = create_signature_image(name or "Signer", width=400, height=120)

    # Get last page size (points)
    last_page = reader.pages[-1]
    media = last_page.mediabox
    # PyPDF2 uses Decimal for coordinates; convert to float
    page_width = float(media.width)
    page_height = float(media.height)

    # scale signature image to a reasonable size relative to page
    target_sig_w = min( int(page_width * 0.35), 500 )
    target_sig_h = int(target_sig_w * (sig_img.height / sig_img.width))
    sig_img = sig_img.resize((target_sig_w, target_sig_h), Image.ANTIALIAS)

    overlay_pdf_stream = create_overlay_pdf(sig_img, page_width, page_height, sig_w=target_sig_w, sig_h=target_sig_h)

    # merge overlay onto last page
    overlay_reader = PdfReader(overlay_pdf_stream)
    overlay_page = overlay_reader.pages[0]

    writer = PdfWriter()
    for i, p in enumerate(reader.pages):
        if i == len(reader.pages) - 1:
            # merge overlay_page onto p
            p.merge_page(overlay_page)
        writer.add_page(p)

    # write out signed PDF
    out_name = f"signed_{uuid.uuid4().hex}.pdf"
    out_path = OUTPUT / out_name
    with open(out_path, "wb") as f:
        writer.write(f)

    return {"signed_file": f"/signed/{out_name}", "path": str(out_path)}

@app.get("/signed/{filename}")
async def get_signed(filename: str):
    path = OUTPUT / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(path, media_type="application/pdf", filename=filename)
PYDOCSIGN

    echo -e "${GREEN}✓ DocSign service files written${NC}"
}

# --------------------------
# docker-compose override (adds/updates docsign and full stt)
# --------------------------
create_docker_compose_override() {
    echo -e "${YELLOW}Writing docker-compose.override.yml (adds docsign + tuned stt)...${NC}"
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
version: '3.9'
services:
  stt-service:
    build:
      context: ./services/stt
      dockerfile: Dockerfile
    container_name: stt-service
    ports:
      - "8011:8000"
    environment:
      - MODEL_PATH=/root/.cache/models
      - STT_MODEL=openai/whisper-tiny
    volumes:
      - ./services/stt/models:/root/.cache/models

  docsign:
    build:
      context: ./services/docsign
      dockerfile: Dockerfile
    container_name: docsign
    ports:
      - "8012:8000"
    volumes:
      - ./services/docsign/output:/app/output
YAML
    echo -e "${GREEN}✓ docker-compose.override.yml written${NC}"
}

# --------------------------
# Register new actions in menu (optional)
# --------------------------
register_block2_menu_actions() {
    # This appends convenience functions to the running shell session if user wants to call them manually.
    echo -e "${YELLOW}Registering Block2 convenience functions...${NC}"
    echo -e "${BLUE}To create full STT and DocSign services, run:${NC}"
    echo "  ./all-in-one.sh (option 1) OR call these functions in a shell where _safe_write exists:"
    echo "  create_stt_full"
    echo "  create_docsign_service"
    echo "  create_docker_compose_override"
    echo -e "${YELLOW}If you re-run menu option 1 (Setup project), these files will be created automatically.${NC}"
}

# --------------------------
# Execute creation right away if user has already run setup (idempotent)
# --------------------------
# If services folders already exist from Block 1, we still overwrite with improved files.
create_stt_full
create_docsign_service
create_docker_compose_override
register_block2_menu_actions

echo -e "${GREEN}Block 2 created: full STT (CPU) and DocSign services.${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1) docker-compose build stt-service docsign --pull"
echo "  2) docker-compose up -d stt-service docsign"
echo ""
echo "Health endpoints:"
echo "  STT:   http://localhost:8011/health"
echo "  DocSign: http://localhost:8012/health"
echo ""
echo "Test DocSign:"
echo "  curl -X POST http://localhost:8012/sign -F \"file=@/path/to/input.pdf\" -F \"name=Alice\" -o /dev/null && echo 'done'"
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 3
# Adds:
#   - Complete DocSign Workflow Engine
#   - OTP system (email/SMS/webhook-pluggable)
#   - Sequential Signer logic
#   - Workflow storage (JSON files)
#   - Signing UI microservice skeleton
# ==============================================================================

create_docsign_workflow_extensions() {
    echo -e "${YELLOW}Extending DocSign service with workflow, OTP, and routing...${NC}"

    # ---------------------------------------------------------------------
    # 1. Workflow storage
    #    Located under services/docsign/workflows/<workflow_id>.json
    # ---------------------------------------------------------------------
    mkdir -p "$ROOT_DIR/services/docsign/workflows"
    mkdir -p "$ROOT_DIR/services/docsign/audit"

    # ---------------------------------------------------------------------
    # 2. Update DocSign requirements (add workflow + OTP libs)
    # ---------------------------------------------------------------------
    _safe_write "$ROOT_DIR/services/docsign/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
Pillow>=9.5.0
reportlab>=4.1.0
PyPDF2>=3.0.0
python-dotenv>=1.0.0
pydantic>=2.0
REQ

    # ---------------------------------------------------------------------
    # 3. Replace DocSign's main.py with full workflow functionality
    # ---------------------------------------------------------------------
    _safe_write "$ROOT_DIR/services/docsign/main.py" <<'PYDOCSIGN'
"""
DocSign Workflow Engine (CPU-only)

New features (Block 3):
 - Create signing workflows with multiple signers.
 - OTP delivery hook (SMS/email/webhook; default=console print).
 - Signer-specific URLs:   /workflow/<wf_id>/start/<email>
 - OTP verification:       POST /workflow/<wf_id>/verify
 - Completion:             POST /workflow/<wf_id>/sign
 - JSON workflow storage:  workflows/<wf_id>.json
 - Audit trail storage:    audit/<wf_id>.log
 - Final merged PDF saved in output/

The workflow format:
{
  "workflow_id": "...",
  "status": "pending|in_progress|completed",
  "pdf_original": "original_<id>.pdf",
  "pdf_signed": null or "finished_<id>.pdf",
  "current_signer": 0,
  "signers": [
     {
       "email": "a@x.com",
       "name": "Alice",
       "otp": "123456",
       "signed": false,
       "signature_file": null
     },
     ...
  ]
}
"""

import os
import io
import uuid
import json
import random
import string
from typing import Optional
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from PIL import Image, ImageDraw, ImageFont
from reportlab.pdfgen import canvas
from PyPDF2 import PdfReader, PdfWriter
from reportlab.lib.utils import ImageReader

BASE = Path(__file__).resolve().parent
WORKFLOW_DIR = BASE / "workflows"
AUDIT_DIR = BASE / "audit"
OUTPUT_DIR = BASE / "output"

WORKFLOW_DIR.mkdir(exist_ok=True)
AUDIT_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

app = FastAPI(title="DocSign Workflow Engine")


# -------------------------------------------------------------------------
# Utility: audit log
# -------------------------------------------------------------------------
def audit(wf_id: str, message: str):
    with open(AUDIT_DIR / f"{wf_id}.log", "a") as f:
        f.write(message + "\n")


# -------------------------------------------------------------------------
# OTP generator
# -------------------------------------------------------------------------
def generate_otp():
    return "".join(random.choices(string.digits, k=6))


def send_otp(email: str, otp: str):
    """
    To integrate with real SMS/email:
    - Add webhook here
    - Add SMTP
    - Add SMS gateway
    """
    print(f"[DocSign OTP] Send to {email}: {otp}")


# -------------------------------------------------------------------------
# Pydantic models for API
# -------------------------------------------------------------------------
class WorkflowCreate(BaseModel):
    signers: list[str]
    names: Optional[list[str]] = None


class OTPVerify(BaseModel):
    email: str
    otp: str


# -------------------------------------------------------------------------
# Core helpers
# -------------------------------------------------------------------------
def load_workflow(wf_id):
    f = WORKFLOW_DIR / f"{wf_id}.json"
    if not f.exists():
        raise HTTPException(status_code=404, detail="Workflow not found")
    return json.loads(f.read_text())


def save_workflow(wf):
    f = WORKFLOW_DIR / f"{wf['workflow_id']}.json"
    f.write_text(json.dumps(wf, indent=2))


# -------------------------------------------------------------------------
# Create workflow
# -------------------------------------------------------------------------
@app.post("/workflow/create")
async def create_workflow(
    pdf: UploadFile = File(...),
    payload: WorkflowCreate = Form(...)
):
    if not pdf.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="PDF required")

    pdf_bytes = await pdf.read()
    original_name = f"original_{uuid.uuid4().hex}.pdf"
    original_path = OUTPUT_DIR / original_name
    original_path.write_bytes(pdf_bytes)

    wf_id = uuid.uuid4().hex
    signers = []
    for i, email in enumerate(payload.signers):
        name = (
            payload.names[i]
            if payload.names and i < len(payload.names)
            else email.split("@")[0]
        )
        otp = generate_otp()
        send_otp(email, otp)
        signers.append({
            "email": email,
            "name": name,
            "otp": otp,
            "signed": False,
            "signature_file": None
        })

    wf = {
        "workflow_id": wf_id,
        "status": "pending",
        "pdf_original": original_name,
        "pdf_signed": None,
        "current_signer": 0,
        "signers": signers
    }
    save_workflow(wf)
    audit(wf_id, "Workflow created")

    return {
        "workflow_id": wf_id,
        "next_signer_url": f"/workflow/{wf_id}/start/{signers[0]['email']}"
    }


# -------------------------------------------------------------------------
# Start signing: returns signer metadata
# -------------------------------------------------------------------------
@app.get("/workflow/{wf_id}/start/{email}")
async def begin(wf_id: str, email: str):
    wf = load_workflow(wf_id)
    idx = wf["current_signer"]
    signer = wf["signers"][idx]
    if signer["email"] != email:
        raise HTTPException(status_code=403, detail="Not your turn")

    return {
        "workflow_id": wf_id,
        "email": signer["email"],
        "name": signer["name"],
        "message": "OTP required → POST /workflow/{wf_id}/verify"
    }


# -------------------------------------------------------------------------
# OTP verification
# -------------------------------------------------------------------------
@app.post("/workflow/{wf_id}/verify")
async def verify_otp(wf_id: str, payload: OTPVerify):
    wf = load_workflow(wf_id)
    idx = wf["current_signer"]
    signer = wf["signers"][idx]

    if signer["email"] != payload.email:
        raise HTTPException(status_code=403, detail="Not your turn")

    if payload.otp != signer["otp"]:
        raise HTTPException(status_code=401, detail="Invalid OTP")

    audit(wf_id, f"OTP verified for {payload.email}")
    return {"status": "verified"}


# -------------------------------------------------------------------------
# Signature image generator
# -------------------------------------------------------------------------
def signature_from_name(name):
    img = Image.new("RGBA", (500, 150), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype("DejaVuSans.ttf", 48)
    except:
        f = ImageFont.load_default()
    w, h = d.textsize(name, font=f)
    d.text((20, (150 - h) // 2), name, font=f, fill=(0, 0, 0, 255))
    return img


# -------------------------------------------------------------------------
# Sign action
# -------------------------------------------------------------------------
@app.post("/workflow/{wf_id}/sign")
async def sign_pdf(
    wf_id: str,
    email: str = Form(...),
    signature: UploadFile = File(None)
):
    wf = load_workflow(wf_id)
    idx = wf["current_signer"]
    signer = wf["signers"][idx]

    if signer["email"] != email:
        raise HTTPException(status_code=403, detail="Not your turn")

    # load PDF
    original_path = OUTPUT_DIR / wf["pdf_original"]
    pdf_bytes = original_path.read_bytes()
    reader = PdfReader(io.BytesIO(pdf_bytes))
    last_page = reader.pages[-1]
    w, h = float(last_page.mediabox.width), float(last_page.mediabox.height)

    # load signature image
    if signature:
        sig_bytes = await signature.read()
        sig_img = Image.open(io.BytesIO(sig_bytes)).convert("RGBA")
    else:
        sig_img = signature_from_name(signer["name"])

    # resize
    target_w = int(w * 0.33)
    target_h = int(target_w * (sig_img.height / sig_img.width))
    sig_img = sig_img.resize((target_w, target_h))

    # overlay
    packet = io.BytesIO()
    from reportlab.pdfgen import canvas
    c = canvas.Canvas(packet, pagesize=(w, h))
    img_io = io.BytesIO()
    sig_img.save(img_io, format="PNG")
    img_io.seek(0)
    c.drawImage(ImageReader(img_io), w - target_w - 40, 40, target_w, target_h, mask="auto")
    c.save()
    packet.seek(0)

    overlay_reader = PdfReader(packet)
    overlay_page = overlay_reader.pages[0]

    writer = PdfWriter()
    for i, p in enumerate(reader.pages):
        if i == len(reader.pages) - 1:
            p.merge_page(overlay_page)
        writer.add_page(p)

    # Save intermediate or final PDF
    if idx == len(wf["signers"]) - 1:
        # finished
        out_name = f"finished_{wf_id}.pdf"
        (OUTPUT_DIR / out_name).write_bytes(io.BytesIO(writer.write_bytes()).getvalue())
        wf["pdf_signed"] = out_name
        wf["status"] = "completed"
        audit(wf_id, f"{email} completed signing; WORKFLOW COMPLETE")
    else:
        # next signer
        out_name = f"partial_{wf_id}_{idx}.pdf"
        (OUTPUT_DIR / out_name).write_bytes(io.BytesIO(writer.write_bytes()).getvalue())
        wf["pdf_original"] = out_name
        wf["current_signer"] += 1
        audit(wf_id, f"{email} signed; moved to next signer")

    signer["signed"] = True
    signer["signature_file"] = out_name
    save_workflow(wf)

    return {
        "workflow_id": wf_id,
        "status": wf["status"],
        "next": (
            f"/workflow/{wf_id}/start/{wf['signers'][wf['current_signer']]['email']}"
            if wf["status"] != "completed"
            else None
        )
    }


# -------------------------------------------------------------------------
# Output fetch
# -------------------------------------------------------------------------
@app.get("/workflow/{wf_id}/output")
async def get_output(wf_id: str):
    wf = load_workflow(wf_id)
    if not wf["pdf_signed"]:
        raise HTTPException(status_code=400, detail="Workflow not completed")
    path = OUTPUT_DIR / wf["pdf_signed"]
    return FileResponse(path, media_type="application/pdf")
PYDOCSIGN

    echo -e "${GREEN}✓ DocSign workflow engine implemented${NC}"
}

# ----------------------------------------------------------------------
# Signing UI Microservice (static placeholder)
# You can replace this with Next.js build in later blocks.
# ----------------------------------------------------------------------
create_signing_ui() {
    echo -e "${YELLOW}Creating signing-ui microservice...${NC}"
    mkdir -p "$ROOT_DIR/services/signing-ui"

    _safe_write "$ROOT_DIR/services/signing-ui/Dockerfile" <<'DF'
FROM node:18-slim
WORKDIR /app
COPY . .
RUN npm init -y
RUN npm install express
EXPOSE 8080
CMD ["node", "server.js"]
DF

    _safe_write "$ROOT_DIR/services/signing-ui/server.js" <<'JS'
const express = require("express");
const path = require("path");
const app = express();

app.get("/", (_, res) => {
  res.send(`
    <h2>Signing UI Placeholder</h2>
    <p>This will render the signing page based on workflow links.</p>
  `);
});

app.listen(8080, () => console.log("Signing UI running on port 8080"));
JS

    echo -e "${GREEN}✓ signing-ui microservice created${NC}"
}

# ----------------------------------------------------------------------
# Compose override to wire workflow + UI
# ----------------------------------------------------------------------
create_docsign_compose_extension() {
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAML2'
version: '3.9'

services:
  docsign:
    build: ./services/docsign
    container_name: docsign
    ports:
      - "8012:8000"
    volumes:
      - ./services/docsign/output:/app/output
      - ./services/docsign/workflows:/app/workflows
      - ./services/docsign/audit:/app/audit

  signing-ui:
    build: ./services/signing-ui
    container_name: signing-ui
    ports:
      - "8013:8080"
YAML2
    echo -e "${GREEN}✓ docker-compose updated${NC}"
}

# Run all creation steps
create_docsign_workflow_extensions
create_signing_ui
create_docsign_compose_extension

echo -e "${GREEN}Block 3 added: Workflow + OTP + Signing UI${NC}"
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 4
# Adds:
#  - PostgreSQL + Redis migration service (idempotent SQL migration runner)
#  - Lightweight schema migrations using plain SQL files + migration history table
#  - A Python migration runner (uses psycopg2) that applies new SQL files in order
#  - Dockerfile + requirements for the migrations service
#
# Paste this block immediately after Block 3 in your `all-in-one.sh`.
# Running the migrations:
#   docker-compose build migrations
#   docker-compose run --rm migrations
#
# The runner reads DATABASE_URL from environment (from .env). It creates a
# `schema_migrations` table and applies SQL files under services/migrations/sql/
# in numeric order. It's intentionally simple and DB-agnostic (Postgres SQL).
# ==============================================================================

_create_db_migrations() {
    echo -e "${YELLOW}Creating migrations service and SQL files...${NC}"

    mkdir -p "$ROOT_DIR/services/migrations/sql"

    # 1) requirements
    _safe_write "$ROOT_DIR/services/migrations/requirements.txt" <<'REQ'
psycopg2-binary>=2.9
python-dotenv>=1.0.0
REQ

    # 2) Dockerfile
    _safe_write "$ROOT_DIR/services/migrations/Dockerfile" <<'DF'
FROM python:3.11-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "migrate.py"]
DF

    # 3) migration runner (migrate.py)
    _safe_write "$ROOT_DIR/services/migrations/migrate.py" <<'PYMIG'
#!/usr/bin/env python3
"""
Simple SQL-based migration runner.

Behavior:
- Reads DATABASE_URL from environment (or .env)
- Ensures schema_migrations table exists
- Scans ./sql for files named like 0001_description.sql, 0002_*.sql
- Applies any files with version > max(applied_versions)
- Records applied migrations in schema_migrations

Usage:
  - docker-compose run --rm migrations
  - or run locally: python migrate.py
"""
import os
import sys
import glob
import psycopg2
from psycopg2.extras import execute_values
from pathlib import Path
from dotenv import load_dotenv
import re

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

DATABASE_URL = os.getenv("DATABASE_URL") or os.getenv("DATABASE_URI") or os.getenv("POSTGRES_URL") or None
if not DATABASE_URL:
    # support older defaults if .env not set
    host = os.getenv("POSTGRES_HOST", "postgres")
    port = os.getenv("POSTGRES_PORT", "5432")
    user = os.getenv("POSTGRES_USER", "ai_user")
    password = os.getenv("POSTGRES_PASSWORD", "ChangeMePostgres123!")
    db = os.getenv("POSTGRES_DB", "ai_platform")
    DATABASE_URL = f"postgresql://{user}:{password}@{host}:{port}/{db}"

SQL_DIR = Path(__file__).resolve().parent / "sql"

MIGRATION_TABLE_DDL = """
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    filename TEXT NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
"""

def get_connection():
    return psycopg2.connect(DATABASE_URL)

def ensure_migration_table(conn):
    with conn.cursor() as cur:
        cur.execute(MIGRATION_TABLE_DDL)
    conn.commit()

def get_applied_versions(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT version FROM schema_migrations")
        rows = cur.fetchall()
        return set(r[0] for r in rows)

def discover_sql_files():
    files = sorted(SQL_DIR.glob("*.sql"))
    # parse version prefix e.g., 0001_init.sql -> 0001
    parsed = []
    for f in files:
        m = re.match(r"^([0-9]+)_.*\.sql$", f.name)
        if m:
            parsed.append((int(m.group(1)), f))
    parsed.sort(key=lambda x: x[0])
    return parsed

def apply_migration(conn, version_int, filepath):
    version = f"{version_int:04d}"
    sql = filepath.read_text()
    print(f"Applying {filepath.name} (version {version})...")
    with conn.cursor() as cur:
        cur.execute(sql)
        cur.execute("INSERT INTO schema_migrations (version, filename) VALUES (%s, %s)", (version, filepath.name))
    conn.commit()
    print(f"Applied {filepath.name}")

def main():
    if not SQL_DIR.exists():
        print("No SQL directory found at", SQL_DIR)
        sys.exit(1)

    parsed = discover_sql_files()
    if not parsed:
        print("No migration files found in", SQL_DIR)
        sys.exit(0)

    conn = get_connection()
    try:
        ensure_migration_table(conn)
        applied = get_applied_versions(conn)
        for ver_int, path in parsed:
            ver = f"{ver_int:04d}"
            if ver in applied:
                print(f"Skipping {path.name} (already applied)")
                continue
            apply_migration(conn, ver_int, path)
        print("Migrations complete.")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
PYMIG

    # 4) sample SQL migration (0001)
    _safe_write "$ROOT_DIR/services/migrations/sql/0001_create_base_tables.sql" <<'SQL1'
-- 0001_create_base_tables.sql
-- Creates base tables used by services: users, workflows, documents, signature_records, audit

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  password_hash TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workflows (
  id SERIAL PRIMARY KEY,
  workflow_id TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL,
  pdf_original TEXT,
  pdf_signed TEXT,
  current_signer INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workflow_signers (
  id SERIAL PRIMARY KEY,
  workflow_id TEXT NOT NULL,
  signer_email TEXT NOT NULL,
  signer_name TEXT,
  signer_index INTEGER,
  otp TEXT,
  signed BOOLEAN DEFAULT FALSE,
  signature_file TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS documents (
  id SERIAL PRIMARY KEY,
  document_id TEXT UNIQUE NOT NULL,
  path TEXT,
  content_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS signature_records (
  id SERIAL PRIMARY KEY,
  workflow_id TEXT,
  signer_email TEXT,
  signature_file TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_entries (
  id SERIAL PRIMARY KEY,
  workflow_id TEXT,
  message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
SQL1

    # 5) optional second migration example (0002) - adds indexes
    _safe_write "$ROOT_DIR/services/migrations/sql/0002_indexes.sql" <<'SQL2'
-- 0002_indexes.sql
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_workflows_wfid ON workflows(workflow_id);
CREATE INDEX IF NOT EXISTS idx_signers_workflow ON workflow_signers(workflow_id);
SQL2

    # 6) a tiny helper script to run migrations locally (optional)
    _safe_write "$ROOT_DIR/services/migrations/run_local.sh" <<'RUNLOCAL'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python migrate.py
RUNLOCAL
    chmod +x "$ROOT_DIR/services/migrations/run_local.sh"

    # 7) update docker-compose.override.yml to add migrations service
    if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
        # append migrations service if not already present
        if ! grep -q "service.*migrations" -A2 "$ROOT_DIR/docker-compose.override.yml" 2>/dev/null; then
            cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAMLAPP'

  migrations:
    build:
      context: ./services/migrations
      dockerfile: Dockerfile
    container_name: migrations
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-ai_user}:${POSTGRES_PASSWORD:-ChangeMePostgres123!}@postgres:5432/${POSTGRES_DB:-ai_platform}
    depends_on:
      - postgres
    entrypoint: ["python", "migrate.py"]
    restart: "no"
YAMLAPP
            echo -e "${GREEN}✓ migrations service appended to docker-compose.override.yml${NC}"
        else
            echo -e "${YELLOW}migrations service already present in docker-compose.override.yml — skipped append${NC}"
        fi
    else
        # create a small override with migrations only
        _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  migrations:
    build:
      context: ./services/migrations
      dockerfile: Dockerfile
    container_name: migrations
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-ai_user}:${POSTGRES_PASSWORD:-ChangeMePostgres123!}@postgres:5432/${POSTGRES_DB:-ai_platform}
    depends_on:
      - postgres
    entrypoint: ["python", "migrate.py"]
    restart: "no"
YAMLNEW
        echo -e "${GREEN}✓ docker-compose.override.yml created with migrations service${NC}"
    fi

    echo -e "${GREEN}✓ Migrations service created (SQL runner + sample SQL files)${NC}"
    echo -e "${YELLOW}Run migrations with:${NC} docker-compose build migrations && docker-compose run --rm migrations${NC}"
}

# Execute creation right away
_create_db_migrations

# helpful note for the user
echo -e "${BLUE}Block 4 installed: migrations service and sample SQL files.${NC}"
echo -e "${BLUE}Tip:${NC} If you prefer to run migrations locally without Docker, set DATABASE_URL in your shell or .env and run services/migrations/run_local.sh"
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 5
# Adds:
#  - Notification microservice (email via SMTP, webhook, and SMS gateway stub)
#  - Redis-backed rate-limiting / dedupe for OTPs and notifications
#  - Integration helpers for DocSign workflows (webhook-friendly)
#  - Dockerfile + requirements
#  - Compose override to wire notifications service and Redis dependency
#
# Behavior:
#  - POST /notify  { "to": "...", "type": "email|sms|webhook", "subject": "...", "body": "...", "webhook_url": "..." }
#  - POST /send-otp { "to": "...", "method": "email|sms", "otp": "123456", "ttl_secs": 300 }
#  - GET  /health
#  - Uses REDIS for storing OTP keys and preventing repeated sends.
#  - SMTP uses env variables (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS). If not set, email falls back to console-print.
# ==============================================================================

create_notifications_service() {
    echo -e "${YELLOW}Creating notifications service...${NC}"
    mkdir -p "$ROOT_DIR/services/notifications"

    # requirements
    _safe_write "$ROOT_DIR/services/notifications/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
httpx>=0.24.0
python-dotenv>=1.0.0
redis>=4.5.0
pydantic>=2.0
REQ

    # Dockerfile
    _safe_write "$ROOT_DIR/services/notifications/Dockerfile" <<'DFNOTIF'
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFNOTIF

    # main.py
    _safe_write "$ROOT_DIR/services/notifications/main.py" <<'PYNOTIF'
"""
Notifications Service
 - POST /notify    : send general notification (email/sms/webhook)
 - POST /send-otp  : send OTP (stores in Redis with TTL)
 - GET  /verify-otp?to=...&otp=...  : verify OTP
 - GET  /health

Redis keys:
 - otp:{to} => otp string (ttl)
Rate limits:
 - send-lock:{to} to prevent rapid repeat sends (short TTL)
"""

import os
import smtplib
import json
import logging
from typing import Optional
from pathlib import Path
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import httpx
import redis
from dotenv import load_dotenv
from email.message import EmailMessage
from time import time

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_FROM = os.getenv("SMTP_FROM", "noreply@example.com")

RATE_LOCK_TTL = int(os.getenv("NOTIF_RATE_LOCK_TTL", "5"))  # seconds between identical sends

r = redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=5)

app = FastAPI(title="Notifications Service")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notifications")

class NotifyPayload(BaseModel):
    to: str
    type: str = Field(..., description="email|sms|webhook")
    subject: Optional[str] = None
    body: str
    webhook_url: Optional[str] = None

class OTPSendPayload(BaseModel):
    to: str
    method: str = Field("email", description="email|sms")
    otp: str
    ttl_secs: int = 300

@app.get("/health")
async def health():
    try:
        pong = r.ping()
        redis_ok = bool(pong)
    except Exception as e:
        redis_ok = False
    return {"status":"healthy", "redis": redis_ok}

def send_email_smtp(to: str, subject: str, body: str):
    if not SMTP_HOST or not SMTP_USER or not SMTP_PASS:
        # fallback to console printing
        logger.info("SMTP not configured — printing email to console")
        logger.info("TO: %s\nSUBJECT: %s\nBODY:\n%s", to, subject, body)
        return True

    msg = EmailMessage()
    msg["From"] = SMTP_FROM
    msg["To"] = to
    msg["Subject"] = subject or "Notification"
    msg.set_content(body)

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        logger.info("Email sent to %s", to)
        return True
    except Exception as e:
        logger.exception("SMTP send failed")
        return False

def send_webhook(url: str, payload: dict):
    try:
        with httpx.Client(timeout=10.0) as client:
            r = client.post(url, json=payload)
            r.raise_for_status()
        logger.info("Webhook sent to %s", url)
        return True
    except Exception as e:
        logger.exception("Webhook failed")
        return False

def send_sms_stub(to: str, body: str):
    # Replace with real SMS gateway integration (Twilio, Africa's Talking, etc.)
    logger.info("[SMS STUB] to=%s body=%s", to, body)
    return True

@app.post("/notify")
async def notify(payload: NotifyPayload):
    lock_key = f"send-lock:{payload.type}:{payload.to}"
    # simple rate lock to avoid accidental spam
    if r.set(lock_key, "1", nx=True, ex=RATE_LOCK_TTL):
        pass
    else:
        raise HTTPException(status_code=429, detail="Rate limit: try again later")

    if payload.type == "email":
        ok = send_email_smtp(payload.to, payload.subject or "Notification", payload.body)
        if not ok:
            raise HTTPException(status_code=502, detail="Email send failed")
        return {"status":"sent","method":"email"}
    elif payload.type == "webhook":
        if not payload.webhook_url:
            raise HTTPException(status_code=400, detail="webhook_url required for webhook type")
        ok = send_webhook(payload.webhook_url, {"to": payload.to, "body": payload.body})
        if not ok:
            raise HTTPException(status_code=502, detail="Webhook failed")
        return {"status":"sent","method":"webhook"}
    elif payload.type == "sms":
        ok = send_sms_stub(payload.to, payload.body)
        if not ok:
            raise HTTPException(status_code=502, detail="SMS send failed")
        return {"status":"sent","method":"sms"}
    else:
        raise HTTPException(status_code=400, detail="Unknown notification type")

@app.post("/send-otp")
async def send_otp(payload: OTPSendPayload):
    key = f"otp:{payload.to}"
    existing = r.get(key)
    if existing:
        # already have an OTP — don't overwrite; return remaining TTL
        ttl = r.ttl(key)
        return {"status":"exists","ttl": ttl}

    # store otp with TTL
    r.set(key, payload.otp, ex=payload.ttl_secs)
    # also set a short send-lock to avoid duplicates
    r.set(f"send-lock:otp:{payload.to}", "1", ex=RATE_LOCK_TTL)

    # send via method
    if payload.method == "email":
        subject = "Your verification code"
        body = f"Your OTP is {payload.otp}. It expires in {payload.ttl_secs} seconds."
        ok = send_email_smtp(payload.to, subject, body)
    elif payload.method == "sms":
        ok = send_sms_stub(payload.to, f"Your OTP is {payload.otp}")
    else:
        ok = False

    if not ok:
        raise HTTPException(status_code=502, detail="Failed to send OTP")

    return {"status":"sent","method": payload.method, "ttl": payload.ttl_secs}

@app.get("/verify-otp")
async def verify_otp(to: str, otp: str):
    key = f"otp:{to}"
    stored = r.get(key)
    if not stored:
        raise HTTPException(status_code=404, detail="No OTP found or expired")
    if stored != otp:
        raise HTTPException(status_code=401, detail="Invalid OTP")
    # optionally delete the key on successful verification
    r.delete(key)
    return {"status":"verified"}
PYNOTIF

    # Compose override: add notifications service
    if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
        if ! grep -q "notifications" "$ROOT_DIR/docker-compose.override.yml"; then
            cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  notifications:
    build:
      context: ./services/notifications
      dockerfile: Dockerfile
    container_name: notifications
    environment:
      - REDIS_URL=redis://redis:6379/0
      - SMTP_HOST=${SMTP_HOST:-}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USER=${SMTP_USER:-}
      - SMTP_PASS=${SMTP_PASS:-}
      - SMTP_FROM=${SMTP_FROM:-noreply@example.com}
    depends_on:
      - redis
YAML
            echo -e "${GREEN}✓ notifications service appended to docker-compose.override.yml${NC}"
        else
            echo -e "${YELLOW}notifications service already exists in docker-compose.override.yml — skipped${NC}"
        fi
    else
        _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  notifications:
    build:
      context: ./services/notifications
      dockerfile: Dockerfile
    container_name: notifications
    environment:
      - REDIS_URL=redis://redis:6379/0
YAMLNEW
        echo -e "${GREEN}✓ docker-compose.override.yml created with notifications service${NC}"
    fi

    echo -e "${GREEN}✓ Notifications service created (SMTP/webhook/SMS stub + Redis)${NC}"
    echo -e "${YELLOW}Health endpoint after start: http://localhost:8000/health (port maps via compose)${NC}"
}

create_notifications_service

echo -e "${BLUE}Block 5 installed: notifications microservice (SMTP/webhook/SMS stub).${NC}"
echo -e "${BLUE}Next suggested block: Full Next.js Signing UI or Gateway routing integration.${NC}"
```bash
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 6
# Next.js Signing UI (production-ready) — paste after previous blocks
#
# Adds a full Next.js signing interface:
#  - /workflow/[wfId]/start/[email]  (OTP -> signature pad -> sign)
#  - API proxy at /api/proxy/*        (forwards to docsign service)
#  - Minimal styling (no Tailwind) to avoid extra installs
#  - Dockerfile (build + start)
#  - docker-compose.override.yml entry to wire into stack at port 3000
#
# Notes:
#  - The Next.js app proxies requests to the docsign service at
#    http://docsign:8000 by default (set NEXT_PUBLIC_DOCSIGN_URL env to override).
#  - This UI is intentionally simple and lightweight so you can iterate quickly.
# ==============================================================================

# ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Block 1..5 first."
  exit 1
fi

create_nextjs_signing_ui() {
  echo -e "${YELLOW}Creating Next.js Signing UI...${NC}"
  mkdir -p "$ROOT_DIR/services/signing-ui-next"
  cd "$ROOT_DIR/services/signing-ui-next" || exit 1

  # package.json
  _safe_write "$ROOT_DIR/services/signing-ui-next/package.json" <<'PKG'
{
  "name": "signing-ui",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "axios": "^1.4.0",
    "next": "14.1.0",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
PKG

  # next.config.js
  _safe_write "$ROOT_DIR/services/signing-ui-next/next.config.js" <<'NEXTCFG'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    NEXT_PUBLIC_DOCSIGN_URL: process.env.NEXT_PUBLIC_DOCSIGN_URL || 'http://docsign:8000'
  }
}
module.exports = nextConfig
NEXTCFG

  # Basic global CSS
  mkdir -p "$ROOT_DIR/services/signing-ui-next/styles"
  _safe_write "$ROOT_DIR/services/signing-ui-next/styles/globals.css" <<'CSS'
:root{
  --bg:#f7f7fb;
  --card:#ffffff;
  --muted:#6b7280;
  --accent:#0b5fff;
  --danger:#ef4444;
}
html,body,#__next{height:100%}
body{font-family:Inter,ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial; background:var(--bg); margin:0; color:#0f172a}
.container{max-width:900px;margin:28px auto;padding:20px}
.card{background:var(--card);border-radius:8px;padding:20px;box-shadow:0 6px 18px rgba(8,8,15,0.06)}
.h1{font-size:20px;margin:0 0 12px}
.small{font-size:13px;color:var(--muted)}
.input, textarea{width:100%;padding:10px;border:1px solid #e6e9ef;border-radius:6px;margin-top:8px}
.button{background:var(--accent);color:white;padding:10px 14px;border-radius:6px;border:0;cursor:pointer}
.button:disabled{opacity:0.6}
.row{display:flex;gap:12px;align-items:center}
.canvas-wrap{border:1px dashed #e6e9ef;border-radius:6px;padding:10px;background:#fbfdff}
.notice{background:#fff9e6;border-left:4px solid #ffd54b;padding:10px;border-radius:6px;margin-bottom:12px}
.footer{margin-top:18px;font-size:13px;color:var(--muted)}
CSS

  # pages/_app.js
  mkdir -p "$ROOT_DIR/services/signing-ui-next/pages"
  _safe_write "$ROOT_DIR/services/signing-ui-next/pages/_app.js" <<'APPJS'
import '../styles/globals.css'

export default function App({ Component, pageProps }) {
  return <Component {...pageProps} />
}
APPJS

  # pages/index.js
  _safe_write "$ROOT_DIR/services/signing-ui-next/pages/index.js" <<'INDEXJS'
import Link from "next/link";

export default function Home(){
  return (
    <div className="container">
      <div className="card">
        <h1 className="h1">Signing UI (Placeholder)</h1>
        <p className="small">Use a workflow link from the DocSign workflow engine to start signing.</p>
        <p className="small">Example (replace with your workflow id and signer email):</p>
        <pre>/workflow/{'{wfId}'}/start/{'{email}'}</pre>
        <p className="small">You can also use the signing UI API proxy under <code>/api/proxy</code>.</p>
        <div style={{marginTop:12}}>
          <Link href="/"><a className="button">Refresh</a></Link>
        </div>
      </div>
    </div>
  )
}
INDEXJS

  # pages/api/proxy/[...path].js - proxy to docsign backend
  mkdir -p "$ROOT_DIR/services/signing-ui-next/pages/api/proxy"
  _safe_write "$ROOT_DIR/services/signing-ui-next/pages/api/proxy/[...path].js" <<'PROXYJS'
import httpProxy from "http-proxy";
import { NextApiRequest, NextApiResponse } from "next";

const proxy = httpProxy.createProxyServer();

const target = process.env.NEXT_PUBLIC_DOCSIGN_URL || "http://docsign:8000";

export const config = {
  api: {
    bodyParser: false,
    externalResolver: true
  }
};

export default function handler(req, res) {
  // rewrite URL: /api/proxy/<path> -> <target>/<path>
  const path = req.query.path;
  const forwardPath = Array.isArray(path) ? path.join("/") : path;
  req.url = `/${forwardPath}${req.url.includes("?") ? "?" + req.url.split("?")[1] : ""}`;
  proxy.web(req, res, { target, changeOrigin: true }, (e) => {
    console.error("Proxy error:", e);
    res.status(502).json({ error: "proxy_error", details: String(e) });
  });
}
PROXYJS

  # pages/workflow/[wfId]/start/[email].js - OTP + signature pad
  mkdir -p "$ROOT_DIR/services/signing-ui-next/pages/workflow/[wfId]/start"
  _safe_write "$ROOT_DIR/services/signing-ui-next/pages/workflow/[wfId]/start/[email].js" <<'SIGNPAGE'
import { useState, useRef, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/router";

export default function SignPage(){
  const router = useRouter();
  const { wfId, email } = router.query;
  const [status, setStatus] = useState("loading");
  const [otp, setOtp] = useState("");
  const [verified, setVerified] = useState(false);
  const [message, setMessage] = useState("");
  const canvasRef = useRef(null);
  const [drawing, setDrawing] = useState(false);

  useEffect(()=>{ if(wfId && email) setStatus("ready") }, [wfId, email]);

  // canvas helpers
  useEffect(()=>{
    const canvas = canvasRef.current;
    if(!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0,0,canvas.width,canvas.height);
    ctx.strokeStyle = "#111827";
    ctx.lineWidth = 2.5;
    ctx.lineCap = "round";
  }, [canvasRef]);

  function startDraw(e){
    setDrawing(true);
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    const ctx = canvas.getContext("2d");
    ctx.beginPath();
    ctx.moveTo(e.clientX - rect.left, e.clientY - rect.top);
  }
  function draw(e){
    if(!drawing) return;
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    const ctx = canvas.getContext("2d");
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top);
    ctx.stroke();
  }
  function endDraw(){
    setDrawing(false);
  }
  function clearCanvas(){
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0,0,canvas.width,canvas.height);
  }

  async function requestVerifyOTP(){
    setMessage("");
    try{
      // The workflow engine already generated and sent OTP — just ask user to enter it
      // We call the docsign verify endpoint via proxy.
      const res = await axios.post(`/api/proxy/workflow/${wfId}/verify`, { email, otp });
      if(res.data && res.data.status === "verified"){
        setVerified(true);
        setMessage("OTP verified — you can sign now");
      } else {
        setMessage("Verified response: " + JSON.stringify(res.data));
      }
    }catch(e){
      setMessage("OTP verify failed: " + (e.response?.data?.detail || e.message));
    }
  }

  async function submitSignature(){
    setMessage("Submitting signature...");
    try{
      const canvas = canvasRef.current;
      const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/png"));
      const form = new FormData();
      form.append("email", email);
      form.append("signature", blob, "signature.png");

      const res = await axios.post(`/api/proxy/workflow/${wfId}/sign`, form, {
        headers: { "Content-Type": "multipart/form-data" }
      });

      setMessage("Signature submitted. Workflow status: " + (res.data.status || ""));
      if(res.data.next){
        setTimeout(()=>{ window.location.href = res.data.next.replace("http://docsign:8000",""); }, 1200);
      } else {
        setMessage("Signing complete; you can download the final document via DocSign.");
      }
    }catch(e){
      setMessage("Signing failed: " + (e.response?.data?.detail || e.message));
    }
  }

  return (
    <div className="container">
      <div className="card">
        <h1 className="h1">Sign Document</h1>
        <p className="small">Workflow: <strong>{wfId}</strong></p>
        <p className="small">Signer: <strong>{email}</strong></p>

        {!verified && (
          <>
            <div className="notice">Enter the OTP sent to your email. If you did not receive it, ask the workflow creator to resend.</div>
            <input className="input" placeholder="Enter OTP" value={otp} onChange={e=>setOtp(e.target.value)} />
            <div style={{marginTop:8}} className="row">
              <button className="button" onClick={requestVerifyOTP}>Verify OTP</button>
            </div>
          </>
        )}

        {verified && (
          <>
            <div style={{marginTop:12}}>
              <div className="small">Draw your signature below (mouse or touch)</div>
              <div className="canvas-wrap" style={{marginTop:8}}>
                <canvas
                  ref={canvasRef}
                  width={800}
                  height={200}
                  onMouseDown={startDraw}
                  onMouseMove={draw}
                  onMouseUp={endDraw}
                  onMouseLeave={endDraw}
                  style={{width:"100%",height:200}}
                />
              </div>
              <div style={{marginTop:8}} className="row">
                <button className="button" onClick={submitSignature}>Submit Signature</button>
                <button className="button" style={{background:"#e5e7eb", color:"#0f172a"}} onClick={clearCanvas}>Clear</button>
              </div>
            </div>
          </>
        )}

        {message && <div style={{marginTop:12}} className="small">{message}</div>}
        <div className="footer">UI proxies backend via <code>/api/proxy/*</code></div>
      </div>
    </div>
  )
}
SIGNPAGE

  # simple 404 fallback
  _safe_write "$ROOT_DIR/services/signing-ui-next/pages/404.js" <<'NOTFOUND'
export default function NotFound(){
  return (
    <div style={{padding:40}}>
      <h2>Page not found</h2>
      <p>Check your workflow link.</p>
    </div>
  )
}
NOTFOUND

  # Dockerfile: build + start
  _safe_write "$ROOT_DIR/services/signing-ui-next/Dockerfile" <<'DFNEXT'
# Next.js Dockerfile (build then start)
FROM node:18-slim AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --legacy-peer-deps || npm install
COPY . .
RUN npm run build

FROM node:18-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/package.json /app/package.json
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./next.config.js
COPY --from=builder /app/styles ./styles
COPY --from=builder /app/pages ./pages
EXPOSE 3000
CMD ["npm","start"]
DFNEXT

  # Add entry to docker-compose.override.yml
  if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
    if ! grep -q "signing-ui-next" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  signing-ui-next:
    build:
      context: ./services/signing-ui-next
      dockerfile: Dockerfile
    container_name: signing-ui-next
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_DOCSIGN_URL=${NEXT_PUBLIC_DOCSIGN_URL:-http://docsign:8000}
    depends_on:
      - docsign
YAML
      echo -e "${GREEN}✓ docker-compose.override.yml updated with signing-ui-next${NC}"
    else
      echo -e "${YELLOW}signing-ui-next already present in docker-compose.override.yml — skipped${NC}"
    fi
  else
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'

services:
  signing-ui-next:
    build:
      context: ./services/signing-ui-next
      dockerfile: Dockerfile
    container_name: signing-ui-next
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_DOCSIGN_URL=${NEXT_PUBLIC_DOCSIGN_URL:-http://docsign:8000}
    depends_on:
      - docsign
YAMLNEW
    echo -e "${GREEN}✓ docker-compose.override.yml created and signing-ui-next added${NC}"
  fi

  echo -e "${GREEN}✓ Next.js Signing UI created (services/signing-ui-next)${NC}"
  echo -e "${BLUE}To run locally (dev): cd services/signing-ui-next && npm install && npm run dev -p 3000${NC}"
  echo -e "${BLUE}To run with Docker Compose:${NC}"
  echo "  docker-compose build signing-ui-next"
  echo "  docker-compose up -d signing-ui-next"
  echo -e "${BLUE}Access UI at http://localhost:3000 (after compose up)${NC}"

  cd "$ROOT_DIR" || true
}

create_nextjs_signing_ui

echo -e "${GREEN}Block 6 installed: Next.js Signing UI + proxy + Dockerfile + compose wiring.${NC}"
```
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 7
# API Gateway (FastAPI) with routing, JWT auth (optional), Redis rate limiting,
# health aggregation and proxying for internal services.
#
# Paste this block immediately after previous blocks in your `all-in-one.sh`.
#
# Features:
# - Async reverse proxy to backend services (stt-service, docsign, notifications, llm-engine, etc.)
# - Aggregated /health endpoint that checks dependent services
# - Optional JWT verification: set GATEWAY_JWT_SECRET to enable token validation
# - Redis-backed rate limiting per IP or per-subject (configurable)
# - Basic request logging and simple metrics counters (in-memory)
# - Dockerfile + requirements + docker-compose.override.yml wiring
#
# Notes:
# - For production-grade gateway please use a dedicated gateway (Traefik/NGINX/Envoy) or add more robust tracing.
# - This gateway is intended as a developer-friendly API façade to unify internal endpoints.
# ==============================================================================

# ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Block 1..6 first."
  exit 1
fi

create_api_gateway() {
  echo -e "${YELLOW}Creating API Gateway service...${NC}"
  mkdir -p "$ROOT_DIR/services/gateway"

  # requirements
  _safe_write "$ROOT_DIR/services/gateway/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
httpx>=0.24.0
python-dotenv>=1.0.0
pyjwt>=2.8.0
redis>=4.5.0
pydantic>=2.0
REQ

  # Dockerfile
  _safe_write "$ROOT_DIR/services/gateway/Dockerfile" <<'DFGATE'
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 80
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "1"]
DFGATE

  # main.py (gateway implementation)
  _safe_write "$ROOT_DIR/services/gateway/main.py" <<'PYGATE'
"""
API Gateway (FastAPI)
 - Proxy /api/{service}/{path...} to internal services
 - Aggregated /health that calls services' /health endpoints
 - Optional JWT validation (GATEWAY_JWT_SECRET)
 - Redis rate limiting (sliding window)
"""

import os
import time
import logging
import asyncio
from typing import List
from fastapi import FastAPI, Request, HTTPException, status, Response
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import httpx
import jwt
from dotenv import load_dotenv
import redis.asyncio as aioredis

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

# Config via env
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
GATEWAY_JWT_SECRET = os.getenv("GATEWAY_JWT_SECRET", "")
RATE_LIMIT_PER_MIN = int(os.getenv("GATEWAY_RATE_PER_MIN", "120"))  # requests per minute per key
RATE_LIMIT_KEY_TYPE = os.getenv("GATEWAY_RATE_KEY_TYPE", "ip")  # ip | sub (JWT subject) | api_key

# Map logical service names to internal URLs
SERVICE_MAP = {
    "stt": os.getenv("STT_SERVICE_URL", "http://stt-service:8000"),
    "docsign": os.getenv("DOCSIGN_SERVICE_URL", "http://docsign:8000"),
    "documents": os.getenv("DOCUMENTS_SERVICE_URL", "http://documents-service:8000"),
    "notifications": os.getenv("NOTIFICATIONS_SERVICE_URL", "http://notifications:8000"),
    "llm": os.getenv("LLM_SERVICE_URL", "http://llm-engine:8000"),
    "eleven": os.getenv("ELEVEN_SERVICE_URL", "http://elevenlabs-service:8000"),
    "auth": os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000"),
}

app = FastAPI(title="API Gateway")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

logger = logging.getLogger("gateway")
logging.basicConfig(level=logging.INFO)

# Async Redis client
redis = aioredis.from_url(REDIS_URL, decode_responses=True)

# Simple in-memory metrics
metrics = {
    "requests_total": 0,
    "responses_2xx": 0,
    "responses_4xx": 0,
    "responses_5xx": 0
}

# ------------------------
# Rate limiting helpers
# ------------------------
async def rate_limit_key(request: Request):
    if RATE_LIMIT_KEY_TYPE == "ip":
        client_host = request.client.host if request.client else "anon"
        return f"rl:ip:{client_host}"
    elif RATE_LIMIT_KEY_TYPE == "sub":
        # attempt to extract JWT subject
        try:
            token = (request.headers.get("authorization") or "").split("Bearer ")[-1]
            decoded = jwt.decode(token, GATEWAY_JWT_SECRET, algorithms=["HS256"]) if token and GATEWAY_JWT_SECRET else {}
            sub = decoded.get("sub", "anon")
            return f"rl:sub:{sub}"
        except Exception:
            return "rl:anon"
    else:
        return "rl:anon"

async def is_rate_limited(key: str):
    # sliding window using redis INCR with EXPIRE
    now = int(time.time())
    window = 60  # seconds
    key_ts = f"{key}:{now // window}"
    count = await redis.incr(key_ts)
    if count == 1:
        await redis.expire(key_ts, window + 5)
    return count > RATE_LIMIT_PER_MIN

# ------------------------
# JWT validation
# ------------------------
def validate_jwt(token: str):
    if not GATEWAY_JWT_SECRET:
        return None
    try:
        payload = jwt.decode(token, GATEWAY_JWT_SECRET, algorithms=["HS256"])
        return payload
    except jwt.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

# ------------------------
# Aggregated health endpoint
# ------------------------
@app.get("/health")
async def health():
    # Check local services from SERVICE_MAP asynchronously with timeout
    async def check(url: str):
        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                r = await client.get(f"{url}/health")
                if r.status_code == 200:
                    return {"url": url, "ok": True, "status": r.json()}
                else:
                    return {"url": url, "ok": False, "status_code": r.status_code}
        except Exception as e:
            return {"url": url, "ok": False, "error": str(e)}

    tasks = [check(u) for u in SERVICE_MAP.values()]
    results = await asyncio.gather(*tasks)
    overall = all(r.get("ok") for r in results)
    return {"status": "healthy" if overall else "degraded", "services": results}

# ------------------------
# Proxy implementation
# ------------------------
@app.api_route("/api/{service}/{path:path}", methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
async def proxy(service: str, path: str, request: Request):
    metrics["requests_total"] += 1

    # validate service
    if service not in SERVICE_MAP:
        raise HTTPException(status_code=404, detail="Unknown service")

    target_base = SERVICE_MAP[service].rstrip("/")
    forward_url = f"{target_base}/{path}"

    # rate limiting
    key = await rate_limit_key(request)
    if await is_rate_limited(key):
        metrics["responses_4xx"] += 1
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    # optional auth
    auth_header = request.headers.get("authorization")
    if GATEWAY_JWT_SECRET:
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing Authorization header")
        token = auth_header.split("Bearer ")[-1]
        validate_jwt(token)

    # build forwarded request
    method = request.method
    headers = dict(request.headers)
    # remove host to avoid host header conflicts
    headers.pop("host", None)

    try:
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
            # stream body
            body = await request.body()
            resp = await client.request(method, forward_url, headers=headers, content=body, params=request.query_params)
            # stream response back
            content = resp.content
            response = Response(content=content, status_code=resp.status_code, headers=dict(resp.headers))
            if 200 <= resp.status_code < 300:
                metrics["responses_2xx"] += 1
            elif 400 <= resp.status_code < 500:
                metrics["responses_4xx"] += 1
            else:
                metrics["responses_5xx"] += 1
            return response
    except httpx.RequestError as e:
        metrics["responses_5xx"] += 1
        raise HTTPException(status_code=502, detail=str(e))

# ------------------------
# Simple metrics endpoint
# ------------------------
@app.get("/metrics")
async def get_metrics():
    return metrics

# ------------------------
# Root route
# ------------------------
@app.get("/")
async def root():
    return {"message":"API Gateway", "services": list(SERVICE_MAP.keys())}
PYGATE

  # Compose override to add gateway service
  if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
    if ! grep -q "gateway:" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  gateway:
    build:
      context: ./services/gateway
      dockerfile: Dockerfile
    container_name: gateway
    ports:
      - "8080:80"
    environment:
      - REDIS_URL=${REDIS_URL:-redis://redis:6379/0}
      - GATEWAY_JWT_SECRET=${GATEWAY_JWT_SECRET:-}
      - GATEWAY_RATE_PER_MIN=${GATEWAY_RATE_PER_MIN:-120}
      - GATEWAY_RATE_KEY_TYPE=${GATEWAY_RATE_KEY_TYPE:-ip}
    depends_on:
      - redis
YAML
      echo -e "${GREEN}✓ gateway appended to docker-compose.override.yml${NC}"
    else
      echo -e "${YELLOW}gateway already exists in docker-compose.override.yml — skipped${NC}"
    fi
  else
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  gateway:
    build:
      context: ./services/gateway
      dockerfile: Dockerfile
    container_name: gateway
    ports:
      - "8080:80"
    environment:
      - REDIS_URL=${REDIS_URL:-redis://redis:6379/0}
YAMLNEW
    echo -e "${GREEN}✓ docker-compose.override.yml created with gateway service${NC}"
  fi

  echo -e "${GREEN}✓ API Gateway service created (services/gateway){NC}"
  echo -e "${BLUE}To build and run the gateway:${NC}"
  echo "  docker-compose build gateway"
  echo "  docker-compose up -d gateway"
}

create_api_gateway

echo -e "${GREEN}Block 7 added: API Gateway with proxy, health aggregation, JWT validation (optional), and rate limiting.${NC}"
```bash
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 8A
# Full STT Model API (CPU-only) with streaming websocket support
#
# Paste this block after previous blocks in your `all-in-one.sh`.
# This block creates a new service: services/stt-advanced
# - HTTP POST /health
# - HTTP POST /api/stt/transcribe  (multipart file OR JSON base64)
# - WebSocket /ws/transcribe       (send base64 chunks, server returns partial/final transcripts)
# - CPU-only inference using transformers Whisper + torchaudio (small model by default)
# - Concurrency guarded by asyncio.Lock to avoid model contention
# - Dockerfile optimized for CPU (same pattern as previous STT)
# - docker-compose.override.yml entry for stt-advanced (port 8020)
#
# IMPORTANT NOTES:
# - This service is heavy (torch/torchaudio/transformers). Use small models (whisper-tiny)
#   for reasonable CPU performance. If you want a lighter dev mode, remove torch/torchaudio
#   from requirements; the service will start and /health will report model not loaded.
# - WebSocket streaming here is chunk-based: client sends JSON messages with fields:
#     { "chunk_base64": "...", "eof": false }
#   When eof=true, the server will run final transcription and return {"final": "..."}.
#   The server may also return intermediate partial transcriptions periodically.
#
# No GPU/CUDA libraries are installed or required by the Dockerfile — CPU only.
# ==============================================================================

# ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Block 1..7 first."
  exit 1
fi

create_stt_advanced() {
  echo -e "${YELLOW}Creating STT-Advanced service (services/stt-advanced)...${NC}"
  mkdir -p "$ROOT_DIR/services/stt-advanced"

  # requirements
  _safe_write "$ROOT_DIR/services/stt-advanced/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-multipart>=0.0.6
transformers>=4.30.0
torch>=2.2.2
torchaudio>=2.2.2
soundfile>=0.12.1
httpx>=0.24.0
python-dotenv>=1.0.0
pydantic>=2.0
REQ

  # Dockerfile (CPU only)
  _safe_write "$ROOT_DIR/services/stt-advanced/Dockerfile" <<'DF'
# STT-Advanced Dockerfile (CPU-only)
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    libsndfile1 \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# If you have prebuilt torch/torchaudio wheels, consider --find-links for faster installs
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
DF

  # main.py
  _safe_write "$ROOT_DIR/services/stt-advanced/main.py" <<'PY'
"""
STT-Advanced Service (CPU-only) with HTTP + WebSocket streaming

Endpoints:
 - GET  /health
 - POST /api/stt/transcribe  (multipart file OR JSON { "audio_base64": "...", "filename": "..." })
 - WebSocket /ws/transcribe  (send JSON messages {"chunk_base64": "...", "eof": false})

Design:
 - Uses transformers WhisperProcessor + WhisperForConditionalGeneration
 - Forces device to CPU (torch.device("cpu"))
 - Uses torchaudio to load audio buffers and resamples to 16000 Hz
 - Protects model with asyncio.Lock to avoid concurrent inference requests
 - Provides lightweight intermediate partial transcripts by re-transcribing accumulated audio
"""
import os
import io
import base64
import logging
import asyncio
from typing import Optional, Dict, Any
from fastapi import FastAPI, UploadFile, File, HTTPException, status, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# optional heavy imports
try:
    import torch
    import torchaudio
    from transformers import WhisperProcessor, WhisperForConditionalGeneration
except Exception as exc:
    torch = None
    torchaudio = None
    WhisperProcessor = None
    WhisperForConditionalGeneration = None
    IMPORT_ERROR = str(exc)
else:
    IMPORT_ERROR = None

app = FastAPI(title="STT-Advanced (CPU)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

logger = logging.getLogger("stt-advanced")
logging.basicConfig(level=logging.INFO)

MODEL = None
PROCESSOR = None
MODEL_NAME = os.getenv("STT_MODEL", os.getenv("STT_MODEL_NAME", "openai/whisper-tiny"))
MODEL_CACHE = os.getenv("MODEL_PATH", "/root/.cache/models")
DEVICE = torch.device("cpu") if torch else None

# guard to serialize model access
inference_lock = asyncio.Lock()

# Streaming buffer per websocket connection
# maps connection id -> bytearray
STREAM_BUFFERS: Dict[str, bytearray] = {}

# config
PARTIAL_TRANSCRIBE_BYTES = int(os.getenv("STT_PARTIAL_BYTES", "160000"))  # when to run a partial on accumulated bytes


class Base64Req(BaseModel):
    audio_base64: str
    filename: Optional[str] = "upload.wav"
    language: Optional[str] = "en"


@app.on_event("startup")
def load_model():
    global MODEL, PROCESSOR
    if IMPORT_ERROR:
        logger.warning("Model libraries not available: %s", IMPORT_ERROR)
        return

    try:
        logger.info("Loading model '%s' (cache=%s) onto CPU", MODEL_NAME, MODEL_CACHE)
        PROCESSOR = WhisperProcessor.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        MODEL = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME, cache_dir=MODEL_CACHE)
        if torch and MODEL is not None:
            MODEL.to(DEVICE)
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.exception("Failed to load model: %s", e)
        MODEL = None
        PROCESSOR = None


@app.get("/health")
async def health():
    return {
        "status": "healthy" if MODEL is not None and PROCESSOR is not None else "model not loaded",
        "model": MODEL_NAME,
        "import_error": IMPORT_ERROR or ""
    }


def read_audio_bytes(audio_bytes: bytes):
    """Load audio bytes to waveform (tensor) and sample rate using torchaudio"""
    if torchaudio is None:
        raise RuntimeError("torchaudio not available")
    bio = io.BytesIO(audio_bytes)
    waveform, sr = torchaudio.load(bio)
    # convert to mono
    if waveform.dim() > 1 and waveform.size(0) > 1:
        waveform = waveform.mean(dim=0, keepdim=True)
    # resample to 16000 if needed
    if sr != 16000:
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=16000)
        waveform = resampler(waveform)
        sr = 16000
    return waveform.squeeze(0).numpy(), sr


async def transcribe_numpy(waveform_np, sr):
    """
    Run model inference in a serialized manner using inference_lock.
    Returns transcription string.
    """
    if IMPORT_ERROR:
        raise RuntimeError(f"Model dependencies missing: {IMPORT_ERROR}")
    if MODEL is None or PROCESSOR is None:
        raise RuntimeError("Model not loaded")

    # prepare features
    inputs = PROCESSOR(waveform_np, sampling_rate=sr, return_tensors="pt")
    # move tensors to CPU explicitly
    inputs = {k: v.to(DEVICE) for k, v in inputs.items()}

    async with inference_lock:
        # run generation synchronously but guarded
        with torch.no_grad():
            predicted_ids = MODEL.generate(**inputs)
        transcription = PROCESSOR.batch_decode(predicted_ids, skip_special_tokens=True)[0]
    return transcription


@app.post("/api/stt/transcribe")
async def transcribe(file: UploadFile = File(None), payload: Base64Req = None, language: str = "en"):
    """
    Accept either file upload or JSON base64 body.
    """
    if IMPORT_ERROR:
        raise HTTPException(status_code=503, detail=f"Missing dependencies: {IMPORT_ERROR}")

    if MODEL is None or PROCESSOR is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    audio_bytes = None
    try:
        if file:
            audio_bytes = await file.read()
        elif payload and payload.audio_base64:
            audio_bytes = base64.b64decode(payload.audio_base64)
        else:
            raise HTTPException(status_code=400, detail="No audio provided")

        waveform_np, sr = read_audio_bytes(audio_bytes)
        transcription = await transcribe_numpy(waveform_np, sr)
        return {"transcription": transcription, "language": language}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Transcription failure")
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------
# WebSocket streaming endpoint
# ---------------------------
# Protocol:
# - Client sends JSON messages:
#   { "chunk_base64": "<base64 audio bytes>", "eof": false }  // append chunk
#   { "eof": true }                                           // mark end
# - Server responds with JSON messages:
#   { "partial": "interim text" }
#   { "final": "final transcription" }
#
# The server will attempt to run partial transcriptions every time accumulated bytes exceed PARTIAL_TRANSCRIBE_BYTES.
#
@app.websocket("/ws/transcribe")
async def websocket_transcribe(ws: WebSocket):
    await ws.accept()
    conn_id = str(id(ws))
    STREAM_BUFFERS[conn_id] = bytearray()
    try:
        while True:
            msg = await ws.receive_text()
            # parse JSON
            try:
                import json
                payload = json.loads(msg)
            except Exception:
                await ws.send_text(json.dumps({"error": "invalid_json"}))
                continue

            # eof handling
            if payload.get("eof"):
                # final transcription on accumulated buffer
                audio_bytes = bytes(STREAM_BUFFERS.get(conn_id, b""))
                if not audio_bytes:
                    await ws.send_text(json.dumps({"error": "no_audio"}))
                    await ws.close()
                    break
                try:
                    waveform_np, sr = read_audio_bytes(audio_bytes)
                    text = await transcribe_numpy(waveform_np, sr)
                    await ws.send_text(json.dumps({"final": text}))
                except Exception as e:
                    await ws.send_text(json.dumps({"error": str(e)}))
                # cleanup and close
                STREAM_BUFFERS.pop(conn_id, None)
                await ws.close()
                break

            # append chunk if provided
            chunk_b64 = payload.get("chunk_base64")
            if chunk_b64:
                try:
                    chunk = base64.b64decode(chunk_b64)
                    STREAM_BUFFERS[conn_id].extend(chunk)
                except Exception as e:
                    await ws.send_text(json.dumps({"error": f"bad_chunk: {e}"}))
                    continue

                # if accumulated size exceeds threshold, run a partial transcription
                if len(STREAM_BUFFERS[conn_id]) >= PARTIAL_TRANSCRIBE_BYTES:
                    try:
                        audio_bytes = bytes(STREAM_BUFFERS[conn_id])
                        waveform_np, sr = read_audio_bytes(audio_bytes)
                        partial = await transcribe_numpy(waveform_np, sr)
                        await ws.send_text(json.dumps({"partial": partial}))
                    except Exception as e:
                        await ws.send_text(json.dumps({"error": f"partial_failed: {e}"}))
                        # continue receiving chunks
            else:
                # unknown message shape
                await ws.send_text(json.dumps({"error": "missing_chunk_or_eof"}))

    except WebSocketDisconnect:
        # client disconnected
        STREAM_BUFFERS.pop(conn_id, None)
    except Exception as e:
        STREAM_BUFFERS.pop(conn_id, None)
        logger.exception("WebSocket error: %s", e)
        try:
            await ws.send_text(json.dumps({"error": str(e)}))
            await ws.close()
        except Exception:
            pass
PY

  # docker-compose override: add stt-advanced service
  if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
    if ! grep -q "stt-advanced" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  stt-advanced:
    build:
      context: ./services/stt-advanced
      dockerfile: Dockerfile
    container_name: stt-advanced
    ports:
      - "8020:8000"
    environment:
      - STT_MODEL=${STT_MODEL:-openai/whisper-tiny}
      - MODEL_PATH=${MODEL_PATH:-/root/.cache/models}
YAML
      echo -e "${GREEN}✓ stt-advanced appended to docker-compose.override.yml${NC}"
    else
      echo -e "${YELLOW}stt-advanced already present in docker-compose.override.yml — skipped${NC}"
    fi
  else
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  stt-advanced:
    build:
      context: ./services/stt-advanced
      dockerfile: Dockerfile
    container_name: stt-advanced
    ports:
      - "8020:8000"
    environment:
      - STT_MODEL=${STT_MODEL:-openai/whisper-tiny}
      - MODEL_PATH=${MODEL_PATH:-/root/.cache/models}
YAMLNEW
    echo -e "${GREEN}✓ docker-compose.override.yml created with stt-advanced${NC}"
  fi

  echo -e "${GREEN}✓ STT-Advanced created under services/stt-advanced${NC}"
  echo -e "${BLUE}To build and run the service:${NC}"
  echo "  docker-compose build stt-advanced --pull"
  echo "  docker-compose up -d stt-advanced"
  echo ""
  echo -e "${BLUE}HTTP health: http://localhost:8020/health${NC}"
  echo -e "${BLUE}HTTP transcribe: http://localhost:8020/api/stt/transcribe (multipart or base64 json)${NC}"
  echo -e "${BLUE}WebSocket: ws://localhost:8020/ws/transcribe (send JSON chunks)${NC}"
}

create_stt_advanced

echo -e "${GREEN}Block 8A installed: STT-Advanced (HTTP + WebSocket streaming, CPU-only).${NC}"
```
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 9
# Full Auth Service (Postgres-backed, JWT + refresh tokens, CPU-only)
#
# Paste this block after previous blocks in your `all-in-one.sh`.
#
# Features:
# - PostgreSQL-backed users (migrations created earlier include `users` table)
# - Register (POST /register) — stores email, full_name, password_hash
# - Login (POST /login) — verifies password, returns access_token (JWT) + refresh_token
# - Refresh (POST /refresh) — exchange refresh token for new access token
# - Protected endpoint example (GET /me) — requires Authorization: Bearer <access_token>
# - Password hashing using bcrypt
# - Token signing using HS256 (SECRET_KEY env)
# - Dockerfile + requirements
# - Compose override wiring (exposes port 8001)
#
# Notes:
# - This is intentionally minimal and secure for a dev environment.
# - For production: enable HTTPS, rotate keys, store refresh tokens in DB with revocation,
#   add rate limiting, account lockouts, email verification, password reset flows, etc.
# ==============================================================================

# Ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Block 1..8 first."
  exit 1
fi

create_auth_full() {
  echo -e "${YELLOW}Creating full Auth service (services/auth)...${NC}"
  mkdir -p "$ROOT_DIR/services/auth"

  # requirements
  _safe_write "$ROOT_DIR/services/auth/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-dotenv>=1.0.0
psycopg2-binary>=2.9
bcrypt>=4.0.1
pyjwt>=2.8.0
pydantic>=2.0
REQ

  # Dockerfile
  _safe_write "$ROOT_DIR/services/auth/Dockerfile" <<'DFAUTH'
FROM python:3.11-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFAUTH

  # main.py implementing auth logic
  _safe_write "$ROOT_DIR/services/auth/main.py" <<'PYAUTH'
"""
Auth Service (Postgres-backed)

Endpoints:
 - GET  /health
 - POST /register   { "email", "password", "full_name" }
 - POST /login      { "email", "password" } -> { access_token, refresh_token, token_type }
 - POST /refresh    { "refresh_token" } -> { access_token }
 - GET  /me         (protected) -> user info

Configuration via environment (.env):
 - SECRET_KEY (required)  : used to sign JWTs
 - ACCESS_TOKEN_EXPIRE_MINUTES (default 15)
 - REFRESH_TOKEN_EXPIRE_DAYS (default 7)
 - DATABASE_URL: full postgres URL or will be assembled from POSTGRES_* env vars
"""

import os
import time
import logging
from typing import Optional
from datetime import datetime, timedelta
from pathlib import Path

from fastapi import FastAPI, HTTPException, Depends, status, Request
from pydantic import BaseModel, EmailStr
import psycopg2
from psycopg2.extras import RealDictCursor
import bcrypt
import jwt
from dotenv import load_dotenv

# Load env from project .env
load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

# Config
SECRET_KEY = os.getenv("SECRET_KEY", "dev_secret_change_me")
ACCESS_EXPIRE_MIN = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

POSTGRES_USER = os.getenv("POSTGRES_USER", "ai_user")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "ChangeMePostgres123!")
POSTGRES_DB = os.getenv("POSTGRES_DB", "ai_platform")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
DATABASE_URL = os.getenv("DATABASE_URL") or f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"

ALGORITHM = "HS256"

app = FastAPI(title="Auth Service")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("auth")

# DB helper
def get_db_conn():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)

# Pydantic models
class RegisterReq(BaseModel):
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class LoginReq(BaseModel):
    email: EmailStr
    password: str

class TokenResp(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int

class RefreshReq(BaseModel):
    refresh_token: str

# Utility functions
def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_EXPIRE_MIN))
    to_encode.update({"exp": expire, "type": "access"})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return token

def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=REFRESH_EXPIRE_DAYS))
    to_encode.update({"exp": expire, "type": "refresh"})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return token

def decode_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"Token error: {e}")

# Endpoints
@app.get("/health")
def health():
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        conn.close()
        return {"status": "healthy", "db": True}
    except Exception as e:
        return {"status": "degraded", "db": False, "error": str(e)}

@app.post("/register", status_code=201)
def register(payload: RegisterReq):
    hashed = hash_password(payload.password)
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        cur.execute("INSERT INTO users (email, full_name, password_hash) VALUES (%s, %s, %s) RETURNING id, email, full_name, created_at", (payload.email, payload.full_name, hashed))
        user = cur.fetchone()
        conn.commit()
        return {"id": user["id"], "email": user["email"], "full_name": user["full_name"], "created_at": user["created_at"]}
    except psycopg2.IntegrityError:
        conn.rollback()
        raise HTTPException(status_code=400, detail="User already exists")
    finally:
        cur.close()
        conn.close()

@app.post("/login", response_model=TokenResp)
def login(payload: LoginReq):
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, email, full_name, password_hash FROM users WHERE email = %s", (payload.email,))
    user = cur.fetchone()
    cur.close()
    conn.close()
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access = create_access_token({"sub": user["email"], "user_id": user["id"]})
    refresh = create_refresh_token({"sub": user["email"], "user_id": user["id"]})
    return {"access_token": access, "refresh_token": refresh, "expires_in": ACCESS_EXPIRE_MIN * 60}

@app.post("/refresh", response_model=TokenResp)
def refresh_token(payload: RefreshReq):
    payload_decoded = decode_token(payload.refresh_token)
    if payload_decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")
    email = payload_decoded.get("sub")
    user_id = payload_decoded.get("user_id")
    # Optionally: verify refresh token hasn't been revoked (DB)
    access = create_access_token({"sub": email, "user_id": user_id})
    refresh = create_refresh_token({"sub": email, "user_id": user_id})
    return {"access_token": access, "refresh_token": refresh, "expires_in": ACCESS_EXPIRE_MIN * 60}

# Dependency: get current user
def get_current_user(request: Request):
    auth: str = request.headers.get("authorization") or ""
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth")
    token = auth.split("Bearer ")[1]
    data = decode_token(token)
    if data.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type")
    return {"email": data.get("sub"), "user_id": data.get("user_id")}

@app.get("/me")
def me(user = Depends(get_current_user)):
    return {"email": user["email"], "user_id": user["user_id"]}
PYAUTH

  # Compose override: ensure auth service exists and uses DATABASE_URL env
  if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
    if ! grep -q "auth-service" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  auth-service:
    build:
      context: ./services/auth
      dockerfile: Dockerfile
    container_name: auth-service
    ports:
      - "8001:8000"
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-ai_user}:${POSTGRES_PASSWORD:-ChangeMePostgres123!}@postgres:5432/${POSTGRES_DB:-ai_platform}
YAML
      echo -e "${GREEN}✓ auth-service appended to docker-compose.override.yml${NC}"
    else
      echo -e "${YELLOW}auth-service already present in docker-compose.override.yml — skipped${NC}"
    fi
  else
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  auth-service:
    build:
      context: ./services/auth
      dockerfile: Dockerfile
    container_name: auth-service
    ports:
      - "8001:8000"
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-ai_user}:${POSTGRES_PASSWORD:-ChangeMePostgres123!}@postgres:5432/${POSTGRES_DB:-ai_platform}
YAMLNEW
    echo -e "${GREEN}✓ docker-compose.override.yml created with auth-service${NC}"
  fi

  echo -e "${GREEN}✓ Auth service created under services/auth (full implementation).${NC}"
  echo -e "${BLUE}Steps to run:${NC}"
  echo "  1) Ensure migrations were applied (services/migrations)."
  echo "  2) docker-compose build auth-service"
  echo "  3) docker-compose up -d auth-service"
  echo -e "${BLUE}Health: http://localhost:8001/health"
  echo -e "${BLUE}Register: POST http://localhost:8001/register { email, password, full_name }"
  echo -e "${BLUE}Login: POST http://localhost:8001/login { email, password }"
}

create_auth_full

echo -e "${GREEN}Block 9 installed: Auth service (Postgres-backed JWT + refresh tokens).${NC}"
```bash
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 10
# Notifications Service (Email + SMS + WhatsApp + Webhooks + Retry Queue)
#
# Paste this block after previous blocks in your `all-in-one.sh`.
#
# This service provides:
# - POST /send/email
# - POST /send/sms
# - POST /send/whatsapp
# - GET  /health
# - Internal retry queue using Redis lists
# - Background worker inside same container (async loop)
# - Providers:
#     - SMTP (email)
#     - HTTP provider for SMS (generic)
#     - Meta WhatsApp Cloud API (generic)
# - All CPU-only, lightweight
#
# Feature set:
# - Sender abstraction so you can replace providers later
# - Delivery report ingestion via /webhook/<provider>
# - Automatic retry on provider failure with exponential backoff
# - Status stored in Redis (message:<id>)
#
# This block creates:
#   services/notifications/
#       main.py
#       requirements.txt
#       Dockerfile
#   docker-compose.override.yml entry
#
# ==============================================================================

if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper missing — paste previous blocks first."
  exit 1
fi

create_notifications_service() {
  echo -e "${YELLOW}Creating notifications service...${NC}"
  mkdir -p "$ROOT_DIR/services/notifications"

  # requirements
  _safe_write "$ROOT_DIR/services/notifications/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
python-dotenv>=1.0.0
redis>=4.5.0
aiohttp>=3.9.0
pydantic>=2.0
REQ

  # Dockerfile
  _safe_write "$ROOT_DIR/services/notifications/Dockerfile" <<'DFNOTIFY'
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFNOTIFY

  # main.py
  _safe_write "$ROOT_DIR/services/notifications/main.py" <<'PYNOTIFY'
"""
Notifications Service
 - Email (SMTP)
 - SMS (generic HTTP)
 - WhatsApp (Meta Cloud API)
 - Redis-based retry queue
 - Delivery webhooks

Environmental variables:
 - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
 - SMS_PROVIDER_URL         (expects POST JSON)
 - SMS_API_KEY
 - WHATSAPP_TOKEN
 - WHATSAPP_PHONE_ID        (Cloud API)
 - REDIS_URL=redis://redis:6379/0

Internal Redis keys:
 - queue:notify
 - message:<id>
"""

import os
import json
import uuid
import asyncio
import smtplib
from email.message import EmailMessage
import aiohttp
import redis.asyncio as aioredis

from fastapi import FastAPI, HTTPException, Body, Request
from pydantic import BaseModel, EmailStr

# Env
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASS = os.getenv("SMTP_PASS")

SMS_PROVIDER_URL = os.getenv("SMS_PROVIDER_URL")
SMS_API_KEY = os.getenv("SMS_API_KEY")

WHATSAPP_TOKEN = os.getenv("WHATSAPP_TOKEN")
WHATSAPP_PHONE_ID = os.getenv("WHATSAPP_PHONE_ID")

app = FastAPI(title="Notifications Service")
redis = aioredis.from_url(REDIS_URL, decode_responses=True)

# --------------------------------------------
# Helper models
# --------------------------------------------
class EmailReq(BaseModel):
  to: EmailStr
  subject: str
  body: str
  from_email: EmailStr | None = None

class SMSReq(BaseModel):
  to: str
  message: str

class WhatsAppReq(BaseModel):
  to: str
  message: str

# --------------------------------------------
# Helpers
# --------------------------------------------
async def save_status(msg_id: str, status: dict):
  await redis.set(f"message:{msg_id}", json.dumps(status))

async def queue_retry(payload: dict, delay: int):
  """
  Schedules retry using zset with score = execution_time (epoch seconds)
  """
  retry_time = int(asyncio.get_event_loop().time()) + delay
  await redis.zadd("queue:notify", {json.dumps(payload): retry_time})

# --------------------------------------------
# Providers
# --------------------------------------------
async def send_email_internal(req: EmailReq, msg_id: str):
  msg = EmailMessage()
  msg["From"] = req.from_email or SMTP_USER
  msg["To"] = req.to
  msg["Subject"] = req.subject
  msg.set_content(req.body)

  try:
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
      server.starttls()
      server.login(SMTP_USER, SMTP_PASS)
      server.send_message(msg)
    await save_status(msg_id, {"status": "sent"})
  except Exception as e:
    await save_status(msg_id, {"status": "failed", "error": str(e)})
    raise

async def send_sms_internal(req: SMSReq, msg_id: str):
  if not SMS_PROVIDER_URL:
    raise Exception("SMS_PROVIDER_URL not configured")

  async with aiohttp.ClientSession() as session:
    try:
      r = await session.post(
        SMS_PROVIDER_URL,
        headers={"Authorization": f"Bearer {SMS_API_KEY}"},
        json={"to": req.to, "message": req.message},
        timeout=15,
      )
      if r.status != 200:
        txt = await r.text()
        raise Exception(f"SMS provider error: {r.status} {txt}")
      await save_status(msg_id, {"status": "sent"})
    except Exception as e:
      await save_status(msg_id, {"status": "failed", "error": str(e)})
      raise

async def send_whatsapp_internal(req: WhatsAppReq, msg_id: str):
  if not WHATSAPP_TOKEN or not WHATSAPP_PHONE_ID:
    raise Exception("WhatsApp provider not configured")

  url = f"https://graph.facebook.com/v17.0/{WHATSAPP_PHONE_ID}/messages"

  payload = {
    "messaging_product": "whatsapp",
    "to": req.to,
    "type": "text",
    "text": {"body": req.message},
  }

  headers = {"Authorization": f"Bearer {WHATSAPP_TOKEN}"}

  async with aiohttp.ClientSession() as session:
    try:
      r = await session.post(url, json=payload, headers=headers, timeout=20)
      if r.status != 200:
        txt = await r.text()
        raise Exception(f"WhatsApp error: {r.status} {txt}")
      await save_status(msg_id, {"status": "sent"})
    except Exception as e:
      await save_status(msg_id, {"status": "failed", "error": str(e)})
      raise

# --------------------------------------------
# User-facing API
# --------------------------------------------
@app.get("/health")
async def health():
  try:
    pong = await redis.ping()
    return {"status": "healthy", "redis": pong}
  except Exception as e:
    return {"status": "degraded", "error": str(e)}

@app.post("/send/email")
async def send_email(req: EmailReq):
  msg_id = str(uuid.uuid4())
  try:
    await send_email_internal(req, msg_id)
    return {"id": msg_id, "status": "sent"}
  except Exception as e:
    await queue_retry({"type": "email", "req": req.dict(), "msg_id": msg_id}, delay=10)
    return {"id": msg_id, "status": "queued_retry", "error": str(e)}

@app.post("/send/sms")
async def send_sms(req: SMSReq):
  msg_id = str(uuid.uuid4())
  try:
    await send_sms_internal(req, msg_id)
    return {"id": msg_id, "status": "sent"}
  except Exception as e:
    await queue_retry({"type": "sms", "req": req.dict(), "msg_id": msg_id}, delay=10)
    return {"id": msg_id, "status": "queued_retry", "error": str(e)}

@app.post("/send/whatsapp")
async def send_whatsapp(req: WhatsAppReq):
  msg_id = str(uuid.uuid4())
  try:
    await send_whatsapp_internal(req, msg_id)
    return {"id": msg_id, "status": "sent"}
  except Exception as e:
    await queue_retry({"type": "whatsapp", "req": req.dict(), "msg_id": msg_id}, delay=10)
    return {"id": msg_id, "status": "queued_retry", "error": str(e)}

# --------------------------------------------
# Delivery report webhooks
# --------------------------------------------
@app.post("/webhook/sms")
async def sms_webhook(data: dict = Body(...)):
  # Save whatever provider sends
  msg_id = data.get("id")
  await save_status(msg_id, {"provider": "sms", "webhook": data})
  return {"ok": True}

@app.post("/webhook/whatsapp")
async def whatsapp_webhook(request: Request):
  body = await request.json()
  msg_id = body.get("id")
  await save_status(msg_id, {"provider": "whatsapp", "webhook": body})
  return {"ok": True}

# --------------------------------------------
# Background worker for retry queue
# --------------------------------------------
async def retry_worker():
  """
  Continuously check Redis ZSET queue: queue:notify
  Pop any messages where score (time) <= now.
  Attempt resend with exponential backoff.
  """
  while True:
    try:
      now = int(asyncio.get_event_loop().time())
      # fetch due items
      items = await redis.zrangebyscore("queue:notify", 0, now)
      for item in items:
        await redis.zrem("queue:notify", item)
        payload = json.loads(item)
        msg_type = payload["type"]
        msg_id = payload["msg_id"]
        req = payload["req"]

        try:
          if msg_type == "email":
            await send_email_internal(EmailReq(**req), msg_id)
          elif msg_type == "sms":
            await send_sms_internal(SMSReq(**req), msg_id)
          elif msg_type == "whatsapp":
            await send_whatsapp_internal(WhatsAppReq(**req), msg_id)
        except Exception:
          # exponential backoff: add +20 seconds each retry
          payload.setdefault("retries", 0)
          payload["retries"] += 1
          delay = 20 * payload["retries"]
          await queue_retry(payload, delay=delay)
    except Exception:
      pass

    await asyncio.sleep(2)

@app.on_event("startup")
async def startup_event():
  asyncio.create_task(retry_worker())
PYNOTIFY

  # Compose override
  if [[ -f "$ROOT_DIR/docker-compose.override.yml" ]]; then
    if ! grep -q "notifications:" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  notifications:
    build:
      context: ./services/notifications
      dockerfile: Dockerfile
    container_name: notifications
    ports:
      - "8010:8000"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - SMS_PROVIDER_URL=${SMS_PROVIDER_URL}
      - SMS_API_KEY=${SMS_API_KEY}
      - WHATSAPP_TOKEN=${WHATSAPP_TOKEN}
      - WHATSAPP_PHONE_ID=${WHATSAPP_PHONE_ID}
    depends_on:
      - redis
YAML
      echo -e "${GREEN}✓ notifications added to docker-compose.override.yml${NC}"
    else
      echo -e "${YELLOW}notifications already exists — skipped${NC}"
    fi
  else
    echo "docker-compose.override.yml missing — cannot append notifications."
  fi

  echo -e "${GREEN}✓ Notifications Service created.${NC}"
  echo -e "${BLUE}API:${NC}"
  echo "  POST http://localhost:8010/send/email"
  echo "  POST http://localhost:8010/send/sms"
  echo "  POST http://localhost:8010/send/whatsapp"
  echo "  GET  http://localhost:8010/health"
}

create_notifications_service

echo -e "${GREEN}Block 10 installed: Full Notifications Service (Email + SMS + WhatsApp + Retry queue).${NC}"
```
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 11A
# LLM Engine (CPU-only) using llama-cpp-python (LLaMA 3.2 1B / 3B)
#
# Paste this block after previous blocks in your `all-in-one.sh`.
#
# What this block provides:
#  - services/llm-llama/ with a FastAPI app that (when llama-cpp-python is available)
#    can run completions and chat-like prompts against a local LLaMA-format .bin model.
#  - Endpoints:
#      - GET  /health
#      - POST /v1/completions     { "prompt": "...", "max_tokens": 128, "temperature": 0.2 }
#      - POST /v1/chat/completions { "messages": [{"role":"user","content":"..."}], ... }
#      - POST /v1/embeddings      { "input": "..." }  (only available if model & library support embeddings)
#  - Dockerfile tuned for CPU (installs build deps required to compile llama-cpp-python)
#  - README-like notes written to services/llm-llama/README.md
#  - docker-compose.override.yml entry adding the service on port 8015
#
# IMPORTANT (read before building):
# - You must provide a llama.cpp-compatible model file (.bin) and set the environment variable
#     LLM_MODEL_PATH=/path/to/your/model.bin
#   The container expects the model file to be mounted into the container (e.g. ./data/llm:/models).
#
# - Building llama-cpp-python from pip requires compilers & cmake; the Dockerfile below installs
#   the minimal set of packages to compile it on Debian slim. Builds may take several minutes.
#
# - This block intentionally avoids any GPU/CUDA dependencies — CPU-only.
# ==============================================================================

# ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Block 1..10 first."
  exit 1
fi

create_llm_llama_service() {
  echo -e "${YELLOW}Creating LLM Engine service (llm-llama)...${NC}"
  mkdir -p "$ROOT_DIR/services/llm-llama"

  # requirements
  _safe_write "$ROOT_DIR/services/llm-llama/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
pydantic>=2.0
python-dotenv>=1.0.0
httpx>=0.24.0
# llama-cpp-python is the preferred backend; it will be installed in Dockerfile
llama-cpp-python>=0.1.87
REQ

  # Dockerfile — installs build tools and compiles llama-cpp-python
  _safe_write "$ROOT_DIR/services/llm-llama/Dockerfile" <<'DFLLM'
# LLM (llama-cpp-python) Dockerfile - CPU-only
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps required to build and run llama-cpp-python (cmake, build tools, libomp)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    pkg-config \
    libopenblas-dev \
    libblas-dev \
    liblapack-dev \
    libgomp1 \
    libomp-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# Install python deps including llama-cpp-python (this will compile the native extension)
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# create non-root user
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
DFLLM

  # README (short)
  _safe_write "$ROOT_DIR/services/llm-llama/README.md" <<'MD'
LLM Engine (llama-cpp-python)
-----------------------------

Usage notes:
1. Obtain a LLaMA 3.2 (1B or 3B) or other compatible model in .bin format.
   Place the model under your host folder (for example ./data/llm) and mount it:
     docker-compose run --rm -v $(pwd)/data/llm:/models ...

2. Set env var in your .env:
     LLM_MODEL_PATH=/models/your-model.bin

3. Build & run:
     docker-compose build llm-llama
     docker-compose up -d llm-llama

4. Health:
     GET http://localhost:8015/health

5. Completions:
     POST http://localhost:8015/v1/completions
     Body: { "prompt": "Hello", "max_tokens": 128, "temperature": 0.2 }

6. Chat:
     POST http://localhost:8015/v1/chat/completions
     Body: { "messages": [{"role":"system","content":"You are helpful."},{"role":"user","content":"Say hi"}] }

Important:
 - This service compiles native code when the image is built. If you have prebuilt wheels, use --find-links.
 - For large models, ensure host machine has enough RAM. 3B models will require multiple GBs of RAM.
MD

  # main.py: Llama wrapper server with safe fallbacks
  _safe_write "$ROOT_DIR/services/llm-llama/main.py" <<'PYLLM'
"""
LLM Engine (llama-cpp-python wrapper)

Endpoints:
 - GET  /health
 - POST /v1/completions
 - POST /v1/chat/completions
 - POST /v1/embeddings

Behavior:
 - Tries to import and initialize llama-cpp-python (Llama).
 - If library or model is missing, /health reports model not loaded and model endpoints return 503.
 - create_completion uses a simple prompt-based completion call.
 - chat/completions converts messages -> prompt and calls the same completion path.
 - embeddings: only supported if the Llama instance exposes 'embeddings' or 'embed' methods;
   otherwise returns 501 Not Implemented.
"""

import os
import time
import logging
from typing import Any, Dict, List, Optional
from pathlib import Path
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# Attempt to import llama-cpp-python
try:
    from llama_cpp import Llama
except Exception as e:
    Llama = None
    LLAMA_IMPORT_ERROR = str(e)
else:
    LLAMA_IMPORT_ERROR = None

# config
MODEL_PATH = os.getenv("LLM_MODEL_PATH", os.getenv("LLM_MODEL", "/models/llama.bin"))
MODEL_N_CTX = int(os.getenv("LLM_N_CTX", "2048"))
MODEL_TEMPERATURE = float(os.getenv("LLM_TEMPERATURE", "0.2"))
MODEL_TOP_P = float(os.getenv("LLM_TOP_P", "0.95"))

app = FastAPI(title="LLM Engine (llama-cpp-python)")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("llm-llama")

LLAMA: Optional["Llama"] = None
MODEL_LOADED = False

# Simple lock to prevent concurrent model.load/generation clashes
import asyncio
model_lock = asyncio.Lock()


class CompletionRequest(BaseModel):
    prompt: str
    max_tokens: int = 128
    temperature: float = MODEL_TEMPERATURE
    top_p: float = MODEL_TOP_P
    stop: Optional[List[str]] = None


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    max_tokens: int = 128
    temperature: float = MODEL_TEMPERATURE
    top_p: float = MODEL_TOP_P


class EmbeddingRequest(BaseModel):
    input: str


def init_model():
    global LLAMA, MODEL_LOADED
    if LLAMA is not None:
        return
    if Llama is None:
        logger.warning("llama-cpp-python not available: %s", LLAMA_IMPORT_ERROR)
        MODEL_LOADED = False
        return

    model_file = Path(MODEL_PATH)
    if not model_file.exists():
        logger.warning("Model file not found at %s", MODEL_PATH)
        MODEL_LOADED = False
        return

    try:
        # instantiate Llama with sensible defaults; CPU-only
        LLAMA = Llama(model_path=str(model_file), n_ctx=MODEL_N_CTX)
        MODEL_LOADED = True
        logger.info("LLM model loaded: %s", model_file)
    except Exception as e:
        logger.exception("Failed to load model: %s", e)
        MODEL_LOADED = False


@app.on_event("startup")
def startup_event():
    init_model()


@app.get("/health")
def health():
    return {
        "status": "healthy" if MODEL_LOADED else "model not loaded",
        "model_path": MODEL_PATH,
        "import_error": LLAMA_IMPORT_ERROR or ""
    }


def messages_to_prompt(messages: List[Dict[str, Any]]) -> str:
    """
    Very simple chat->prompt conversion:
      system messages first, then user/assistant alternation.
    This is intentionally minimal; replace with a more robust chat prompt
    schema in production (e.g., role templates).
    """
    pieces = []
    for m in messages:
        role = m.get("role", "user")
        content = m.get("content", "")
        if role == "system":
            pieces.append(f"[SYSTEM]\n{content}\n")
        elif role == "user":
            pieces.append(f"[USER]\n{content}\n")
        else:
            pieces.append(f"[ASSISTANT]\n{content}\n")
    pieces.append("\n[ASSISTANT]\n")  # model to continue as assistant
    return "\n".join(pieces)


@app.post("/v1/completions")
async def completions(req: CompletionRequest):
    if not MODEL_LOADED or LLAMA is None:
        raise HTTPException(status_code=503, detail="Model not loaded or unavailable")

    # run generation under lock to avoid concurrent resource contention
    async with model_lock:
        try:
            # llama-cpp-python exposes call signatures like llm.create_completion or calling the instance.
            # We attempt to call .create_completion first; if missing, call the instance as a function.
            kwargs = dict(prompt=req.prompt, max_tokens=req.max_tokens, temperature=req.temperature, top_p=req.top_p)
            if hasattr(LLAMA, "create_completion"):
                resp = LLAMA.create_completion(**kwargs)
                # typical response: {'id':..., 'choices':[{'text':...}], ...}
                text = ""
                try:
                    text = resp.get("choices", [{}])[0].get("text", "")
                except Exception:
                    text = str(resp)
            else:
                # fallback: call LLAMA(...) — some versions support __call__
                out = LLAMA(req.prompt, max_tokens=req.max_tokens, temperature=req.temperature, top_p=req.top_p)
                # out may be a dict or simple string-like object
                if isinstance(out, dict):
                    text = out.get("choices", [{}])[0].get("text", "")
                else:
                    text = str(out)
            return {"id": f"llm-{int(time.time())}", "object": "text_completion", "choices": [{"text": text}]}
        except Exception as e:
            logger.exception("Generation error")
            raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/chat/completions")
async def chat_completions(req: ChatRequest):
    if not MODEL_LOADED or LLAMA is None:
        raise HTTPException(status_code=503, detail="Model not loaded or unavailable")

    prompt = messages_to_prompt([m.dict() for m in req.messages])
    # reuse completions path
    comp = CompletionRequest(prompt=prompt, max_tokens=req.max_tokens, temperature=req.temperature, top_p=req.top_p)
    return await completions(comp)


@app.post("/v1/embeddings")
async def embeddings(req: EmbeddingRequest):
    """
    Embeddings support depends on the installed llama-cpp-python version and model.
    If LLAMA exposes an embeddings API, attempt to call it; otherwise return 501.
    """
    if not MODEL_LOADED or LLAMA is None:
        raise HTTPException(status_code=503, detail="Model not loaded or unavailable")

    # Attempt to detect an embedding method
    if hasattr(LLAMA, "embeddings") and callable(getattr(LLAMA, "embeddings")):
        async with model_lock:
            try:
                resp = LLAMA.embeddings([req.input])
                # expected format: {'data': [{'embedding':[...]}], ...}
                vec = resp.get("data", [{}])[0].get("embedding", None)
                if vec is None:
                    raise RuntimeError("embeddings returned unexpected format")
                return {"object": "embedding", "data": [{"embedding": vec}]}
            except Exception as e:
                logger.exception("Embedding error")
                raise HTTPException(status_code=500, detail=str(e))
    # Another possible method name
    if hasattr(LLAMA, "embed") and callable(getattr(LLAMA, "embed")):
        async with model_lock:
            try:
                vec = LLAMA.embed(req.input)
                return {"object": "embedding", "data": [{"embedding": vec}]}
            except Exception as e:
                logger.exception("Embedding error")
                raise HTTPException(status_code=500, detail=str(e))

    raise HTTPException(status_code=501, detail="Embedding not supported by this runtime or model")
PYLLM

  # docker-compose.override.yml entry (append or create)
  if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
    if ! grep -q "llm-llama" "$ROOT_DIR/docker-compose.override.yml"; then
      cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'
  llm-llama:
    build:
      context: ./services/llm-llama
      dockerfile: Dockerfile
    container_name: llm-llama
    ports:
      - "8015:8000"
    environment:
      - LLM_MODEL_PATH=${LLM_MODEL_PATH:-/models/llama.bin}
      - LLM_N_CTX=${LLM_N_CTX:-2048}
    volumes:
      - ./data/llm:/models
YAML
      echo -e "${GREEN}✓ llm-llama appended to docker-compose.override.yml${NC}"
    else
      echo -e "${YELLOW}llm-llama already present in docker-compose.override.yml — skipped${NC}"
    fi
  else
    _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  llm-llama:
    build:
      context: ./services/llm-llama
      dockerfile: Dockerfile
    container_name: llm-llama
    ports:
      - "8015:8000"
    environment:
      - LLM_MODEL_PATH=${LLM_MODEL_PATH:-/models/llama.bin}
      - LLM_N_CTX=${LLM_N_CTX:-2048}
    volumes:
      - ./data/llm:/models
YAMLNEW
    echo -e "${GREEN}✓ docker-compose.override.yml created and llm-llama added${NC}"
  fi

  # Create a small helper example for running locally
  _safe_write "$ROOT_DIR/services/llm-llama/run_local_example.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Example: run server locally (requires llama-cpp-python installed and MODEL_PATH set)
export LLM_MODEL_PATH=${LLM_MODEL_PATH:-./data/llm/your-model.bin}
python main.py
SH
  chmod +x "$ROOT_DIR/services/llm-llama/run_local_example.sh"

  echo -e "${GREEN}✓ LLM (llm-llama) service created under services/llm-llama${NC}"
  echo -e "${BLUE}IMPORTANT:${NC} Place your model under ./data/llm and set LLM_MODEL_PATH in .env to /models/your-model.bin"
  echo -e "${BLUE}Build & Run (docker-compose):${NC}"
  echo "  docker-compose build llm-llama"
  echo "  docker-compose up -d llm-llama"
  echo -e "${BLUE}Health: http://localhost:8015/health"
  echo -e "${BLUE}Completions: POST http://localhost:8015/v1/completions"
  echo -e "${BLUE}Chat: POST http://localhost:8015/v1/chat/completions"
  echo -e "${BLUE}Embeddings: POST http://localhost:8015/v1/embeddings (only if supported)"
}

create_llm_llama_service

echo -e "${GREEN}Block 11A installed: LLM Engine (llm-llama) skeleton with llama-cpp-python support.${NC}"
echo -e "${YELLOW}If you want, next block can add: model downloader scripts, automatic quantization hints, or Qdrant integration for embeddings indexing.${NC}"
```bash
# ==============================================================================
# ALL-IN-ONE: AI Platform Superstack — BLOCK 12
# Adds:
#  - Qdrant vector database wiring (docker-compose.override.yml)
#  - Embeddings Indexer service (services/embeddings-indexer)
#      - POST /index   { "id": "...", "texts": ["..."], "metadatas": [{},...] }
#      - POST /search  { "query": "...", "top_k": 5 }
#      - Calls LLM service's /v1/embeddings endpoint (llm-llama) to get vectors
#      - Stores and searches vectors in Qdrant via its HTTP API
#  - Helper script: scripts/model_downloader.sh (instructions + safe download stub)
#  - Notes and quantization hints written to services/llm-llama/QUANTIZE.md
#
# Design assumptions / safety:
#  - Embeddings endpoint must be available at llm-llama:8000/v1/embeddings.
#    If your LLaMA runtime doesn't support embeddings, the indexer will return 501.
#  - Qdrant runs locally inside Docker (no external cloud required).
#  - All services remain CPU-only.
#
# Paste this block right after previous blocks.
# ==============================================================================

# Ensure helper exists
if ! declare -f _safe_write >/dev/null 2>&1; then
  echo "Error: _safe_write helper not found. Paste Blocks 1..11A first."
  exit 1
fi

# --------------------------
# 1) Qdrant compose wiring
# --------------------------
echo -e "${YELLOW}Adding Qdrant to docker-compose.override.yml...${NC}"
if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
  if ! grep -q "qdrant" "$ROOT_DIR/docker-compose.override.yml"; then
    cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'

  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      - "6333:6333"
    volumes:
      - ./data/qdrant:/qdrant/storage
    environment:
      QDRANT__SERVICE__GRPC_PORT: 6334
      QDRANT__STORAGE__PATH: /qdrant/storage
YAML
    echo -e "${GREEN}✓ Qdrant appended to docker-compose.override.yml${NC}"
  else
    echo -e "${YELLOW}qdrant already present in docker-compose.override.yml — skipped${NC}"
  fi
else
  _safe_write "$ROOT_DIR/docker-compose.override.yml" <<'YAMLNEW'
version: '3.9'
services:
  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      - "6333:6333"
    volumes:
      - ./data/qdrant:/qdrant/storage
    environment:
      QDRANT__SERVICE__GRPC_PORT: 6334
      QDRANT__STORAGE__PATH: /qdrant/storage
YAMLNEW
  echo -e "${GREEN}✓ docker-compose.override.yml created with qdrant${NC}"
fi

# --------------------------
# 2) Embeddings Indexer service
# --------------------------
echo -e "${YELLOW}Creating Embeddings Indexer service...${NC}"
mkdir -p "$ROOT_DIR/services/embeddings-indexer"

_safe_write "$ROOT_DIR/services/embeddings-indexer/requirements.txt" <<'REQ'
fastapi>=0.95.0
uvicorn[standard]>=0.21.0
httpx>=0.24.0
pydantic>=2.0
python-dotenv>=1.0.0
REQ

_safe_write "$ROOT_DIR/services/embeddings-indexer/Dockerfile" <<'DFINDEX'
FROM python:3.11-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DFINDEX

# main.py for indexer
_safe_write "$ROOT_DIR/services/embeddings-indexer/main.py" <<'PYINDEX'
"""
Embeddings Indexer (Qdrant + llm-llama)
 - POST /index : index a list of texts (expects llm-llama embeddings)
 - POST /search: search by text query (calls embeddings then qdrant search)
 - GET  /health: checks Qdrant and llm-llama health
Environment:
 - QDRANT_URL (default http://qdrant:6333)
 - LLM_EMBED_URL (default http://llm-llama:8000/v1/embeddings)
Note: If llm-llama does not implement embeddings, this service returns 501.
"""
import os
import logging
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
LLM_EMBED_URL = os.getenv("LLM_EMBED_URL", "http://llm-llama:8000/v1/embeddings")
COLLECTION = os.getenv("QDRANT_COLLECTION", "documents")

app = FastAPI(title="Embeddings Indexer")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("emb-indexer")

class IndexReq(BaseModel):
    id: str
    texts: List[str]
    metadatas: Optional[List[Dict[str, Any]]] = None

class SearchReq(BaseModel):
    query: str
    top_k: int = 5

async def qdrant_create_collection_if_missing():
    # minimal collection creation with vector size unknown until we have an embedding
    async with httpx.AsyncClient() as client:
        info = await client.get(f"{QDRANT_URL}/collections")
        if info.status_code != 200:
            # Qdrant not ready
            raise RuntimeError("Qdrant not responding")
        collections = info.json().get("collections", [])
        if any(c["name"] == COLLECTION for c in collections):
            return True
    return False

async def get_embeddings(texts: List[str]):
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(LLM_EMBED_URL, json={"input": texts})
        if resp.status_code == 200:
            data = resp.json()
            # shape may vary; support single and batched formats
            # expected: {"object":"embedding","data":[{"embedding":[...]}]} or list
            if isinstance(data, dict) and data.get("data"):
                return [d.get("embedding") for d in data["data"]]
            if isinstance(data, list):
                return data
            # fallback if LLM returned {'embedding': [...]}
            if "embedding" in data:
                return [data["embedding"]]
        elif resp.status_code == 501:
            raise HTTPException(status_code=501, detail="Embeddings not supported by LLM runtime")
        else:
            raise HTTPException(status_code=502, detail=f"Embedding provider error: {resp.status_code}: {resp.text}")
    raise HTTPException(status_code=500, detail="Unknown embedding error")

async def qdrant_upsert(points: List[dict]):
    async with httpx.AsyncClient(timeout=30.0) as client:
        url = f"{QDRANT_URL}/collections/{COLLECTION}/points"
        resp = await client.put(url, json={"points": points})
        if resp.status_code not in (200, 201):
            raise HTTPException(status_code=502, detail=f"Qdrant upsert failed: {resp.status_code}: {resp.text}")
        return resp.json()

async def qdrant_search(vector, top_k=5):
    async with httpx.AsyncClient(timeout=30.0) as client:
        url = f"{QDRANT_URL}/collections/{COLLECTION}/points/search"
        payload = {"vector": vector, "top": top_k}
        resp = await client.post(url, json=payload)
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail=f"Qdrant search failed: {resp.status_code}: {resp.text}")
        return resp.json()

@app.get("/health")
async def health():
    # check Qdrant and LLM embed endpoint
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            q = await client.get(f"{QDRANT_URL}/collections")
            llm = await client.get(LLM_EMBED_URL.replace("/v1/embeddings","/health"))
            return {"qdrant": q.status_code==200, "llm_embeddings": llm.status_code==200}
        except Exception as e:
            return {"error": str(e)}

@app.post("/index")
async def index(req: IndexReq):
    # get embeddings for each text
    embeddings = await get_embeddings(req.texts)
    # create collection if missing (naive: create with known vector size)
    if not await qdrant_create_collection_if_missing():
        # create collection based on vector size
        dim = len(embeddings[0])
        async with httpx.AsyncClient() as client:
            create_payload = {
                "vectors": {"size": dim, "distance": "Cosine"},
                "shards": 1
            }
            r = await client.put(f"{QDRANT_URL}/collections/{COLLECTION}", json=create_payload)
            if r.status_code not in (200, 201):
                raise HTTPException(status_code=502, detail=f"Failed to create collection: {r.text}")

    # prepare points for upsert
    points = []
    for i, emb in enumerate(embeddings):
        point_id = f"{req.id}_{i}"
        payload = {"text": req.texts[i], "metadata": (req.metadatas[i] if req.metadatas and i < len(req.metadatas) else {})}
        points.append({"id": point_id, "vector": emb, "payload": payload})

    res = await qdrant_upsert(points)
    return {"status": "ok", "upsert": res}

@app.post("/search")
async def search(req: SearchReq):
    # get embedding for query
    vectors = await get_embeddings([req.query])
    vec = vectors[0]
    res = await qdrant_search(vec, top_k=req.top_k)
    return res
PYINDEX

# Compose override entry for embeddings-indexer
if [ -f "$ROOT_DIR/docker-compose.override.yml" ]; then
  if ! grep -q "embeddings-indexer" "$ROOT_DIR/docker-compose.override.yml"; then
    cat >> "$ROOT_DIR/docker-compose.override.yml" <<'YAML'

  embeddings-indexer:
    build:
      context: ./services/embeddings-indexer
      dockerfile: Dockerfile
    container_name: embeddings-indexer
    ports:
      - "8016:8000"
    environment:
      - QDRANT_URL=http://qdrant:6333
      - LLM_EMBED_URL=http://llm-llama:8000/v1/embeddings
      - QDRANT_COLLECTION=documents
    depends_on:
      - llm-llama
      - qdrant
YAML
    echo -e "${GREEN}✓ embeddings-indexer appended to docker-compose.override.yml${NC}"
  else
    echo -e "${YELLOW}embeddings-indexer already present in docker-compose.override.yml — skipped${NC}"
  fi
fi

# --------------------------
# 3) Helper: model downloader + quantize hints
# --------------------------
mkdir -p "$ROOT_DIR/scripts"
_safe_write "$ROOT_DIR/scripts/model_downloader.sh" <<'SHDOC'
#!/usr/bin/env bash
set -euo pipefail
# Model downloader stub + quantization hints
# Usage:
#   ./scripts/model_downloader.sh --source <url-or-path> --dest ./data/llm/your-model.bin
#
# This script is a safe helper: it does not download large files automatically
# unless you supply a direct URL. It verifies SHA256 if provided.
#
usage(){
  cat <<EOF
Usage: $0 --source <url|path> --dest <dest-path> [--sha256 <hash>]

Example:
  ./scripts/model_downloader.sh --source "https://example.com/llama-3-1b.bin" --dest ./data/llm/llama-3-1b.bin
EOF
  exit 1
}

SRC=""
DEST=""
SHA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SRC="$2"; shift 2;;
    --dest) DEST="$2"; shift 2;;
    --sha256) SHA="$2"; shift 2;;
    *) echo "Unknown $1"; usage;;
  esac
done

if [[ -z "$SRC" || -z "$DEST" ]]; then usage; fi

mkdir -p "$(dirname "$DEST")"

if [[ "$SRC" == http* ]]; then
  echo "Downloading model from $SRC → $DEST (streaming)"
  # use curl streaming
  curl -L --progress-bar "$SRC" -o "$DEST"
else
  echo "Copying local file $SRC → $DEST"
  cp "$SRC" "$DEST"
fi

if [[ -n "$SHA" ]]; then
  echo "Verifying SHA256..."
  calc=$(sha256sum "$DEST" | awk '{print $1}')
  if [[ "$calc" != "$SHA" ]]; then
    echo "SHA mismatch: $calc != $SHA" >&2
    exit 2
  fi
  echo "SHA verified"
fi

echo "Model saved to $DEST"
echo ""
echo "Quantization hints:"
echo " - For llama-cpp, consider converting to GGML Q4_K_M or similar using llama.cpp tools."
echo " - Example: python /path/to/convert script from llama.cpp repo or use quantize tool."
echo " - For 3B models expect multi-GB RAM usage; prefer 1B for low-RAM CPU inference."
SHDOC
chmod +x "$ROOT_DIR/scripts/model_downloader.sh"

# --------------------------
# 4) Quantization notes in LLM folder
# --------------------------
_safe_write "$ROOT_DIR/services/llm-llama/QUANTIZE.md" <<'QH'
Quantization & Model Hints (LLM-LLAMA)
-------------------------------------

Suggestions for CPU-friendly deployment:

1) Prefer smaller models for low-RAM:
   - LLaMA 3.2 1B is a good starting point for CPU-only inference.
   - 3B works but requires significantly more RAM.

2) Use GGML / quantized formats:
   - The llama.cpp tooling provides quantization tools that convert a .bin model
     to smaller GGML files (q4/ q5 formats). These are faster and use less RAM.
   - Typical tools: `convert.py` or `quantize` from the llama.cpp repo.

3) Example quantize flow (host side):
   - Clone llama.cpp and build the quantize utility.
   - Use: `./quantize model.bin model-q4.bin q4_k_m` (options vary by tool)
   - Mount `model-q4.bin` into Docker at /models/llama-q4.bin and set LLM_MODEL_PATH accordingly.

4) Memory & threads:
   - Tune `n_threads` (llama-cpp option) based on host CPU cores.
   - Use small `n_ctx` if you don't need long context windows.

5) Testing locally:
   - Use the `scripts/model_downloader.sh` to fetch or place a model into ./data/llm
   - Update .env: LLM_MODEL_PATH=/models/your-quantized-model.bin
   - Build container and startup.

6) If embeddings are unsupported:
   - Use a small CPU-friendly sentence-transformers model locally on a separate embeddings service.
   - Or use llm-llama's embed() if supported in your build.

QH

echo -e "${GREEN}Block 12 installed: Qdrant + Embeddings Indexer + model_downloader helper + quantize notes.${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "  docker-compose up -d qdrant"
echo "  docker-compose build embeddings-indexer"
echo "  docker-compose up -d embeddings-indexer"
echo -e "${BLUE}Health checks:"
echo "  Qdrant: http://localhost:6333 (API root)"
echo "  Indexer: http://localhost:8016/health"
```
