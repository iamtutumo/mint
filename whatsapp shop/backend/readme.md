# Mercury Commerce Platform - Backend

WhatsApp-first AI Commerce & Operations Platform

## Quick Start

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 15+
- MinIO
- Qdrant
- Ollama

### Setup

1. **Clone and navigate**
```bash
cd backend/mercury-core
```

2. **Create environment file**
```bash
cp .env.example .env
# Edit .env with your credentials
```

3. **Start services with Docker Compose**
```bash
docker-compose up -d
```

4. **Pull Ollama models**
```bash
docker exec mercury-ollama ollama pull llama3.1:8b
docker exec mercury-ollama ollama pull nomic-embed-text
```

5. **Access services**
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- MinIO Console: http://localhost:9001
- Qdrant Dashboard: http://localhost:6333/dashboard

## Architecture

### Core Components
- **FastAPI Backend**: REST API with async support
- **PostgreSQL**: Relational database for orders, products, accounting
- **MinIO**: Object storage for PDFs, documents, digital products
- **Qdrant**: Vector database for product search
- **Ollama**: Local LLM for command parsing

### Key Features
- ✅ FSM-controlled order lifecycle
- ✅ Double-entry accounting
- ✅ Inventory management
- ✅ PDF document generation with password protection
- ✅ Natural language command parsing
- ✅ WhatsApp integration ready
- ✅ Owner authentication via phone numbers
- ✅ Superuser password for critical operations

## API Endpoints

### Orders
- `POST /api/v1/orders/` - Create order
- `GET /api/v1/orders/{order_number}` - Get order
- `PUT /api/v1/orders/{order_number}/status` - Update status (owner)
- `GET /api/v1/orders/customer/{customer_id}` - List customer orders

### Products
- `POST /api/v1/products/` - Create product (owner)
- `GET /api/v1/products/` - List products
- `GET /api/v1/products/{id}` - Get product
- `PUT /api/v1/products/{id}` - Update product (owner)

### Inventory
- `POST /api/v1/inventory/movement` - Record movement (owner)
- `POST /api/v1/inventory/purchase` - Record purchase (owner)
- `POST /api/v1/inventory/adjust` - Adjust stock (superuser)

### Accounting
- `POST /api/v1/transactions/` - Create journal entry (owner)
- `POST /api/v1/transactions/expense` - Record expense (owner)
- `POST /api/v1/transactions/transfer` - Transfer funds (owner)
- `GET /api/v1/accounts/balance/{id}` - Get account balance

### Documents
- `POST /api/v1/documents/invoice/{order_id}` - Generate invoice
- `POST /api/v1/documents/receipt/{payment_id}` - Generate receipt
- `GET /api/v1/documents/{doc_number}` - Get document

### Webhooks
- `POST /api/v1/webhooks/whatsapp-owner` - Owner commands
- `POST /api/v1/webhooks/whatsapp-customer` - Customer queries

## Owner Commands (via WhatsApp)

### Order Management
```
Change order ORD-20240101-ABC123 to dispatched
Mark order ORD-20240101-ABC123 as completed
Cancel order ORD-20240101-ABC123
```

### Accounting
```
Add expense fuel 50000 cash
Record electricity bill 80000 bank
Transfer 200000 from cash to bank
```

### Inventory
```
Check stock for sugar
What's the inventory level for flour?
Add purchase 100 bags sugar at 5000 each
```

### Reports
```
Generate sales report for today
Show profit and loss this month
Give me inventory report
```

## Authentication

### Owner Authentication
Add authorized phone numbers to `.env`:
```env
OWNER_PHONE_NUMBERS=+256700000000,+256700000001
```

Send requests with header:
```
X-Phone-Number: +256700000000
```

### Superuser Operations
For critical operations (inventory adjustments, account overrides):
```
X-Phone-Number: +256700000000
X-Superuser-Password: your-superuser-password
```

## Database Schema

### Core Tables
- `users` - Customers and owners
- `products` - Physical, digital, service products
- `orders` - Order management with FSM
- `order_items` - Line items
- `inventory_movements` - Stock tracking
- `accounts` - Chart of accounts
- `transactions` - Journal entries
- `documents` - Generated PDFs
- `bookings` - Service appointments
- `payments` - Payment records

## FSM States

### Orders
```
draft → pending_payment → payment_submitted → confirmed → 
processing → dispatched → completed
```

### Bookings
```
pending → confirmed → completed
```

## Development

### Run locally
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Run tests
```bash
pytest tests/
```

### Database migrations
```bash
alembic revision --autogenerate -m "description"
alembic upgrade head
```

## Docker Optimization

Following strict Docker best practices:
- ✅ Multi-stage builds
- ✅ Minimal base images (python:3.11-slim)
- ✅ Non-root user execution
- ✅ Read-only filesystem where possible
- ✅ Health checks on all services
- ✅ Resource limits enforced
- ✅ Log rotation configured
- ✅ Named volumes (no anonymous)

## Security

- Phone number authentication for owners
- Superuser password for critical operations
- Password-protected PDFs
- Audit logging for all state changes
- No secrets in images
- Environment-based configuration

## Integration with n8n

Configure n8n webhook endpoint:
```env
N8N_WEBHOOK_URL=http://localhost:5678/webhook
```

n8n workflows will call Mercury API endpoints for:
- Order notifications
- Payment confirmations
- Document delivery
- Customer surveys

## Monitoring

Check service health:
```bash
curl http://localhost:8000/health
```

View logs:
```bash
docker logs mercury-api
```

## Production Deployment

1. Use secrets management (not .env)
2. Enable HTTPS/TLS
3. Set up proper backups for PostgreSQL
4. Configure MinIO with replication
5. Set resource limits appropriately
6. Enable log aggregation
7. Set up monitoring and alerts

## Support

For issues or questions, check:
- API documentation: http://localhost:8000/docs
- Logs: `docker logs mercury-api`
- Database: Connect via PostgreSQL client