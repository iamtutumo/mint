# Frontend Applications Setup Guide

## Overview

The frontend infrastructure now includes **3 separate applications**:

1. **Realtime Transcriber** - Speech-to-text transcription application (Next.js)
   - Location: `/frontend/realtime-transcriber`
   - Port: 3001 (via Docker) or directly on 3000 when running locally
   
2. **Voice Agent** - Voice conversation agent (Next.js)
   - Location: `/frontend/voice-agent`
   - Port: 3002 (via Docker) or directly on 3000 when running locally
   
3. **PWA (React)** - Progressive Web App
   - Location: `/services/pwa`
   - Port: 3003 (via Docker)

## Building and Running

### Option 1: Build All at Once (Recommended)

```bash
# Build the updated frontend script (includes all three apps)
./build-frontend-all.sh

# Run with Docker Compose
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d
```

### Option 2: Build Locally for Development

```bash
# Build individual apps for development

# Realtime Transcriber
cd frontend/realtime-transcriber
pnpm install
pnpm run dev  # Runs on http://localhost:3000

# In another terminal - Voice Agent
cd frontend/voice-agent
pnpm install
pnpm run dev  # Runs on http://localhost:3000 (or next available port)

# In another terminal - PWA
cd services/pwa
npm install
npm start  # Runs on http://localhost:3000 (or next available port)
```

### Option 3: Build Only What You Changed

```bash
# Build just Realtime Transcriber
cd frontend/realtime-transcriber
pnpm build

# Build just Voice Agent
cd frontend/voice-agent
pnpm build

# Build just PWA
cd services/pwa
npm run build
```

## Docker Compose Deployment

### Full Stack Deployment
```bash
# Navigate to project root
cd /workspaces/mint

# Build frontend apps
./build-frontend-all.sh

# Deploy with Docker Compose
# This combines the main compose file and the frontend compose file
docker compose \
  -f docker-compose.yml \
  -f docker-compose.frontend.yml \
  up -d
```

### What Gets Deployed
- **Realtime Transcriber**: http://localhost:3001
- **Voice Agent**: http://localhost:3002
- **PWA**: http://localhost:3003
- **API Gateway**: http://localhost:80
- **All microservices**: Available via API Gateway

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f realtime-transcriber
docker compose logs -f voice-agent
docker compose logs -f pwa

# Combine both compose files for full logs
docker compose \
  -f docker-compose.yml \
  -f docker-compose.frontend.yml \
  logs -f
```

## Gateway Routing

The gateway (Caddy reverse proxy) automatically routes traffic:

- **http://localhost/** → Realtime Transcriber (default)
- **http://localhost:3001/** → Realtime Transcriber (direct)
- **http://localhost:3002/** → Voice Agent (direct)
- **http://localhost:3003/** → PWA (direct)
- **http://localhost:80/transcriber** → Realtime Transcriber
- **http://localhost:80/voice-agent** → Voice Agent
- **http://localhost:80/pwa** → PWA
- **http://localhost:80/api/** → API Gateway
- **http://localhost:80/ws/** → WebSocket connections

## Environment Variables

### Realtime Transcriber
No environment variables needed by default. Connects to:
- API: `http://localhost:80/api`
- WebSocket: `ws://localhost:80/ws`

### Voice Agent
No environment variables needed by default. Connects to:
- API: `http://localhost:80/api`
- WebSocket: `ws://localhost:80/ws`
- ElevenLabs: `http://localhost:8010`

### PWA
Located in `.env` file in `/services/pwa/`:
```
REACT_APP_API_URL=/api
REACT_APP_WS_URL=ws://${window.location.host}/ws
```

## File Structure

```
frontend/
├── realtime-transcriber/
│   ├── Dockerfile.prod          # Production build
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── app/
│   │   ├── page.tsx             # Main page
│   │   └── realtime-transcriber-01/
│   │       └── page.tsx         # Transcriber page
│   ├── components/              # React components
│   ├── hooks/                   # Custom hooks
│   └── lib/                     # Utilities
│
├── voice-agent/
│   ├── Dockerfile               # Production build
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── app/
│   │   ├── page.tsx             # Main page
│   │   └── voice-chat/
│   │       └── page.tsx         # Voice chat page
│   ├── components/              # React components
│   └── lib/                     # Utilities
│
services/
├── pwa/
│   ├── Dockerfile               # Nginx-based deployment
│   ├── package.json
│   ├── nginx/
│   │   └── default.conf         # Nginx config
│   └── src/                     # React app source
```

## Troubleshooting

### Port Already in Use
If you see "port already in use" errors:
```bash
# Find process using the port
lsof -i :3000
lsof -i :3001
lsof -i :3002

# Kill the process
kill -9 <PID>

# Or stop all Docker containers
docker compose down -f docker-compose.yml -f docker-compose.frontend.yml
```

### Build Fails
If a build fails:
```bash
# Clean build
rm -rf frontend/realtime-transcriber/.next
rm -rf frontend/voice-agent/.next
rm -rf services/pwa/build

# Rebuild
./build-frontend-all.sh
```

### Apps Show Default React Page
This was the original issue. The fix:
1. Ensure you're using the updated docker-compose files:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d
   ```
2. Wait for services to start (check with `docker compose ps`)
3. Access the correct port:
   - Realtime Transcriber: http://localhost:3001
   - Voice Agent: http://localhost:3002

### Container Won't Start
```bash
# Check logs
docker logs realtime-transcriber
docker logs voice-agent

# Rebuild without cache
docker compose build --no-cache realtime-transcriber
docker compose build --no-cache voice-agent
```

## Development Tips

### Hot Reload (Local Development)
Next.js provides hot reload out of the box:
```bash
cd frontend/realtime-transcriber
pnpm run dev
# App auto-reloads when you save files
```

### Debugging
Use Next.js debug mode:
```bash
# In development
DEBUG=* pnpm run dev

# Or add to next.config.js
module.exports = {
  logging: {
    fetches: {
      fullUrl: true,
    },
  },
}
```

### Building for Production
```bash
cd frontend/realtime-transcriber
pnpm build

# Test production build locally
pnpm start  # Starts on port 3000
```

## Performance Optimization

### Next.js Output Standalone
Both Next.js apps use `output: 'standalone'` in `next.config.mjs` which:
- Reduces Docker image size
- Improves startup time
- Only includes necessary files

### Dockerfile Optimization
- Multi-stage builds (builder + runner)
- Layer caching
- Production-only dependencies
- Non-root user execution

### Reverse Proxy Caching
The Caddy gateway can cache responses:
- Automatically caches HTTP responses
- Configurable cache headers
- WebSocket pass-through for real-time features

## API Integration

Both Next.js apps automatically connect to the API gateway:

### In Components
```typescript
// Use relative paths - gateway handles routing
const response = await fetch('/api/endpoint');

// WebSocket connections
const ws = new WebSocket('ws://' + window.location.host + '/ws/channel');
```

### Backend Service Endpoints
- Document Service: `http://documents-service:8008`
- OCR Service: `http://ocr-service:8000`
- ASR Service: `http://asr-service:8000`
- TTS Service: `http://tts-service:8000`
- LLM Service: `http://llm-engine:8000`
- ElevenLabs Service: `http://elevenlabs-service:8000`

## Production Deployment

For production deployment:

1. **Update environment**:
   ```bash
   NODE_ENV=production
   NEXT_PUBLIC_API_URL=https://yourdomain.com/api
   ```

2. **Build optimized images**:
   ```bash
   docker build -f frontend/realtime-transcriber/Dockerfile.prod \
     -t your-registry/realtime-transcriber:latest \
     ./frontend/realtime-transcriber
   ```

3. **Use production compose**:
   ```bash
   docker compose -f docker-compose.prod.yml \
     -f docker-compose.frontend.prod.yml \
     up -d
   ```

4. **Enable HTTPS** in Caddyfile:
   ```
   example.com {
       # Caddy auto-provisions SSL certificates
   }
   ```
