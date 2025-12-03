# AI Platform Superstack

A comprehensive AI platform with multiple microservices for document processing, voice interaction, and more.

## Prerequisites

- Docker and Docker Compose
- Node.js 18+ and npm
- Python 3.9+

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ready
   ```

2. **Set up environment variables**
   - The setup script will automatically create a `.env` file with default values if it doesn't exist
   - For production, review and update the generated `.env` file with your specific configuration

3. **Build and start services**
   ```bash
   # Make scripts executable
   chmod +x "All in one.sh" build-frontend.sh
   
   # Build and start all services
   ./"All in one.sh"
   ```

4. **Access the application**
   - **Realtime Transcriber**: http://localhost:3001
   - **Voice Agent**: http://localhost:3002
   - **PWA**: http://localhost:3003
   - **API Gateway**: http://localhost:80
   - **MinIO Console**: http://localhost:9001

## Frontend Applications

This project includes **3 separate frontend applications**:

1. **Realtime Transcriber** (http://localhost:3001) - Real-time speech-to-text with language selection
2. **Voice Agent** (http://localhost:3002) - Voice-based conversational AI agent
3. **PWA** (http://localhost:3003) - Progressive Web App with multiple features

For detailed frontend setup and deployment instructions, see [FRONTEND_SETUP.md](./FRONTEND_SETUP.md).

## Service Endpoints

### Core Services
- **Authentication Service**
  - `POST /api/auth/register` - User registration
  - `POST /api/auth/login` - User login
  - `POST /api/auth/refresh` - Refresh access token

- **Document Service**
  - `POST /api/documents/upload` - Upload a document
  - `GET /api/documents` - List all documents
  - `GET /api/documents/{id}` - Get document by ID

- **OCR Service**
  - `POST /api/ocr/process` - Process image to text
  - `GET /api/ocr/status/{task_id}` - Check OCR status

- **Voice Services**
  - `POST /api/tts` - Text to Speech conversion
  - `POST /api/stt` - Speech to Text conversion
  - `WS /ws/voice` - WebSocket for real-time voice

### AI Services
- **LLM Service**
  - `POST /api/llm/chat` - Chat with LLM
  - `POST /api/llm/generate` - Generate text

- **ElevenLabs Integration**
  - `POST /api/elevenlabs/tts` - High-quality TTS
  - `GET /api/elevenlabs/voices` - List available voices

## Environment Variables

The setup script automatically generates a `.env` file with secure defaults. For production, you should review and update these values.

### Frontend Variables (REACT_APP_*)
These variables are used by the React frontend and are embedded during build time:

- `REACT_APP_API_URL` - Base URL for API requests (default: `/api`)
- `REACT_APP_WS_URL` - WebSocket URL (default: `ws://${window.location.host}/ws`)
- `REACT_APP_ENV` - Environment (development/production)
- `REACT_APP_VERSION` - Application version
- `REACT_APP_AUTH_SERVICE_URL` - Authentication service URL
- `REACT_APP_DOCUMENTS_SERVICE_URL` - Document service URL
- `REACT_APP_OCR_SERVICE_URL` - OCR service URL
- `REACT_APP_ASR_SERVICE_URL` - Speech-to-text service URL
- `REACT_APP_TTS_SERVICE_URL` - Text-to-speech service URL
- `REACT_APP_VOICE_SERVICE_URL` - Voice service URL
- `REACT_APP_LLM_SERVICE_URL` - LLM service URL
- `REACT_APP_ENABLE_ANALYTICS` - Enable analytics (true/false)
- `REACT_APP_ENABLE_LOGGING` - Enable debug logging (true/false)

### Backend Variables
These variables are used by the backend services:

#### Authentication
- `JWT_SECRET` - Secret key for JWT tokens
- `MAGIC_LINK_EXPIRY` - Magic link expiration in seconds (default: 900)
- `OTP_EXPIRY` - OTP expiration in seconds (default: 300)

#### Database
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password
- `POSTGRES_DB` - Database name
- `DATABASE_URL` - Full database connection URL
- `REDIS_URL` - Redis connection URL

#### Storage
- `MINIO_ROOT_USER` - MinIO root username
- `MINIO_ROOT_PASSWORD` - MinIO root password
- `MINIO_ACCESS_KEY` - MinIO access key
- `MINIO_SECRET_KEY` - MinIO secret key
- `MINIO_BUCKET` - Default bucket name

#### Email
- `SMTP_HOST` - SMTP server host
- `SMTP_PORT` - SMTP server port
- `SMTP_USER` - SMTP username
- `SMTP_PASS` - SMTP password
- `SMTP_FROM` - Sender email address
- `SMTP_SECURE` - Use TLS (true/false)

#### AI Services
- `OLLAMA_URL` - Ollama service URL
- `OLLAMA_MODEL` - Default Ollama model
- `STT_MODEL` - Speech-to-text model
- `STT_LANGUAGE` - Language for speech recognition
- `STT_DEVICE` - Device for processing (cpu/cuda)
- `TTS_PROVIDER` - Text-to-speech provider
- `TTS_VOICE` - Voice ID for TTS
- `TTS_MODEL` - TTS model name
- `LLM_PROVIDER` - LLM provider (ollama, etc.)
- `LLM_MODEL` - LLM model name
- `LLM_TEMPERATURE` - Sampling temperature
- `LLM_MAX_TOKENS` - Maximum tokens to generate

#### Service URLs
- `AUTH_SERVICE_URL` - Authentication service
- `DOCUMENTS_SERVICE_URL` - Document service
- `OCR_SERVICE_URL` - OCR service
- `ASR_SERVICE_URL` - Speech recognition service
- `TTS_SERVICE_URL` - Text-to-speech service
- `VOICE_SERVICE_URL` - Voice service
- `DOCGEN_SERVICE_URL` - Document generation service
- `DOCSIGN_SERVICE_URL` - Document signing service
- `RULES_SERVICE_URL` - Rules engine service
- `LLM_SERVICE_URL` - LLM service
- `ELEVENLABS_SERVICE_URL` - ElevenLabs service URL

## Development

### Building the Frontend
```bash
./build-frontend.sh
```

### Running Tests
```bash
# Run all tests
docker compose run --rm test

# Run specific test suite
docker compose run --rm test pytest path/to/test_file.py
```

## Deployment

### Production
1. Set `NODE_ENV=production` in `.env`
2. Update `CORS_ALLOWED_ORIGINS` with your production domain
3. Set `REQUIRE_HTTPS=true` for production
4. Run with production compose file:
   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```

## Troubleshooting

### Common Issues
- **Port conflicts**: Ensure required ports (80, 443, 3000, 9000, 9001) are available
- **Permission issues**: Run `chmod +x *.sh` to make scripts executable
- **Docker issues**: Try rebuilding containers with `docker compose build --no-cache`

### Viewing Logs
```bash
# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f service_name
```

## License


