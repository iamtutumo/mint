# Frontend Services (Docker)

This directory contains two main frontend services running in Docker:
1. **Realtime Transcriber** - A real-time transcription service
2. **Voice Agent** - A voice interaction service

## Prerequisites

- Docker and Docker Compose

## Quick Start

1. Build and start both services:
   ```bash
   docker-compose up --build
   ```

2. Access the services:
   - Realtime Transcriber: http://localhost:3000
   - Voice Agent: http://localhost:3001

## Docker Commands

### Start Services
- Start in foreground:
  ```bash
  docker-compose up --build
  ```

- Start in background (detached mode):
  ```bash
  docker-compose up -d --build
  ```

### Stop Services
- Stop and remove containers:
  ```bash
  docker-compose down
  ```

### View Logs
- Follow logs:
  ```bash
  docker-compose logs -f
  ```

- View logs for a specific service:
  ```bash
  docker-compose logs -f realtime-transcriber
  docker-compose logs -f voice-agent
  ```

### Rebuild Services
- Rebuild a specific service:
  ```bash
  docker-compose up -d --build <service_name>
  ```

## Troubleshooting
- If ports are in use, update the port mappings in `docker-compose.yml`
- Check logs with `docker-compose logs -f`
- For permission issues, ensure Docker has the necessary permissions
