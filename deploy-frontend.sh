#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   MINT AI Platform - Frontend Deploy${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get the root directory
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}\n"

# Check current docker compose v
docker_compose_version=$(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null | head -1)
echo -e "${BLUE}Using:${NC} $docker_compose_version\n"

# Determine compose command (v1 vs v2)
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

# Show status of containers
show_status() {
    echo -e "\n${BLUE}Service Status:${NC}"
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml ps
}

# Show logs
show_logs() {
    echo -e "\n${YELLOW}Showing logs... (Press Ctrl+C to stop)${NC}\n"
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml logs -f
}

# Show menu
show_menu() {
    echo -e "\n${BLUE}=== MINT Frontend Deployment Menu ===${NC}"
    echo -e "1. ${YELLOW}Build Frontend Apps${NC}"
    echo -e "2. ${YELLOW}Start Services${NC}"
    echo -e "3. ${YELLOW}Stop Services${NC}"
    echo -e "4. ${YELLOW}Rebuild & Restart${NC}"
    echo -e "5. ${YELLOW}View Service Status${NC}"
    echo -e "6. ${YELLOW}View Logs${NC}"
    echo -e "7. ${YELLOW}Show Access URLs${NC}"
    echo -e "8. ${RED}Destroy Services${NC}"
    echo -e "0. ${RED}Exit${NC}\n"
    read -p "Select option (0-8): " choice
}

# Build frontend
build_frontend() {
    echo -e "\n${YELLOW}Building frontend applications...${NC}"
    bash "$ROOT_DIR/build-frontend-all.sh"
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Frontend build successful${NC}"
    else
        echo -e "\n${RED}✗ Frontend build failed${NC}"
        return 1
    fi
}

# Start services
start_services() {
    echo -e "\n${YELLOW}Starting Docker services...${NC}"
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml up -d
    
    sleep 3
    echo -e "\n${GREEN}✓ Services started${NC}"
    show_status
}

# Stop services
stop_services() {
    echo -e "\n${YELLOW}Stopping Docker services...${NC}"
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml stop
    echo -e "\n${GREEN}✓ Services stopped${NC}"
}

# Rebuild and restart
rebuild_restart() {
    echo -e "\n${YELLOW}Rebuilding and restarting services...${NC}"
    build_frontend
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml up -d --force-recreate
    sleep 5
    echo -e "\n${GREEN}✓ Services rebuilt and restarted${NC}"
    show_status
}

# Destroy services
destroy_services() {
    echo -e "\n${RED}⚠ This will remove all containers and volumes!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "\n${YELLOW}Destroying services...${NC}"
        $COMPOSE_CMD -f docker-compose.yml -f docker-compose.frontend.yml down -v
        echo -e "\n${GREEN}✓ Services destroyed${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
}

# Show access URLs
show_urls() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   Access URLs${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "\n${GREEN}Frontend Applications:${NC}"
    echo -e "  • Realtime Transcriber: ${YELLOW}http://localhost:3001${NC}"
    echo -e "  • Voice Agent:          ${YELLOW}http://localhost:3002${NC}"
    echo -e "  • PWA:                  ${YELLOW}http://localhost:3003${NC}"
    echo -e "\n${GREEN}Infrastructure:${NC}"
    echo -e "  • API Gateway:          ${YELLOW}http://localhost:80${NC}"
    echo -e "  • MinIO Console:        ${YELLOW}http://localhost:9001${NC}"
    echo -e "  • Weaviate:             ${YELLOW}http://localhost:8081${NC}"
    echo -e "  • Ollama:               ${YELLOW}http://localhost:11434${NC}"
    echo -e "\n${GREEN}Gateway Routing:${NC}"
    echo -e "  • Default (/):          ${YELLOW}http://localhost/ (→ Realtime Transcriber)${NC}"
    echo -e "  • API:                  ${YELLOW}http://localhost/api/...${NC}"
    echo -e "  • WebSocket:            ${YELLOW}ws://localhost/ws/...${NC}"
    echo -e "\n"
}

# Main loop
cd "$ROOT_DIR"

while true; do
    show_menu
    
    case $choice in
        1)
            build_frontend
            ;;
        2)
            start_services
            ;;
        3)
            stop_services
            ;;
        4)
            rebuild_restart
            ;;
        5)
            show_status
            ;;
        6)
            show_logs
            ;;
        7)
            show_urls
            ;;
        8)
            destroy_services
            ;;
        0)
            echo -e "\n${YELLOW}Exiting...${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option. Please select 0-8.${NC}"
            ;;
    esac
done
