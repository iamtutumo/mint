# WhatsApp Shop

A full-stack e-commerce application with WhatsApp integration, built with React, Node.js, and various backend services.

## Prerequisites

- Docker and Docker Compose installed on your system
- Node.js (for local development without Docker)
- npm or yarn (for local development without Docker)

## Project Structure

- `frontend/` - React application
- `backend/` - Node.js/Express API server
- `ai/` - AI and machine learning components
- `automation/` - n8n workflows for automation

## Docker Setup

### Building and Running with Docker Compose

1. Clone the repository (if you haven't already):
   ```bash
   git clone <repository-url>
   cd whatsapp-shop
   ```

2. Start all services:
   ```bash
   docker-compose up --build
   ```

3. The application will be available at:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - MinIO Console: http://localhost:9001 (username: minioadmin, password: minioadmin)
   - Qdrant: http://localhost:6333

### Services

- **Frontend**: React application (port 3000)
- **Backend**: Node.js/Express API (port 8000)
- **PostgreSQL**: Database (port 5432)
- **Redis**: Caching and sessions (port 6379)
- **MinIO**: Object storage (port 9000)
- **Qdrant**: Vector search (port 6333)
- **Celery**: Task queue
- **n8n**: Workflow automation (if enabled)

## Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
# Frontend
VITE_API_URL=http://localhost:8000/api

# Backend
POSTGRES_SERVER=db
POSTGRES_USER=mercury
POSTGRES_PASSWORD=mercury_password
POSTGRES_DB=mercury_commerce
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=mercury_access
MINIO_SECRET_KEY=mercury_secret
QDRANT_HOST=qdrant
QDRANT_PORT=6333
REDIS_URL=redis://redis:6379/0
```

## Troubleshooting

- If you encounter port conflicts, check which services are already running on the required ports.
- If the frontend can't connect to the backend, ensure the backend is running and the `VITE_API_URL` is correctly set.
- For database issues, check the PostgreSQL logs with `docker-compose logs db`.

