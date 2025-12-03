#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   MINT Frontend Setup Verification${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check Docker
echo -e "${YELLOW}Checking dependencies...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker installed: $(docker --version)"
else
    echo -e "${RED}✗${NC} Docker not found"
fi

if command -v docker-compose &> /dev/null || command -v docker compose &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose installed"
else
    echo -e "${RED}✗${NC} Docker Compose not found"
fi

if command -v node &> /dev/null; then
    echo -e "${GREEN}✓${NC} Node.js installed: $(node --version)"
else
    echo -e "${RED}✗${NC} Node.js not found"
fi

if command -v pnpm &> /dev/null; then
    echo -e "${GREEN}✓${NC} pnpm installed: $(pnpm --version)"
else
    echo -e "${YELLOW}⚠${NC} pnpm not found (will be installed by npm)"
fi

# Check files
echo -e "\n${YELLOW}Checking project files...${NC}"

files=(
    "docker-compose.yml:Main Docker Compose"
    "docker-compose.frontend.yml:Frontend services"
    "build-frontend-all.sh:Frontend build script"
    "deploy-frontend.sh:Deployment menu"
    "frontend/realtime-transcriber/Dockerfile.prod:Realtime Transcriber image"
    "frontend/voice-agent/Dockerfile:Voice Agent image"
    "frontend/realtime-transcriber/package.json:Realtime Transcriber deps"
    "frontend/voice-agent/package.json:Voice Agent deps"
    "services/gateway/Caddyfile:Gateway config"
    "FRONTEND_SETUP.md:Setup documentation"
    "FRONTEND_FIX_SUMMARY.md:Fix documentation"
)

for file_check in "${files[@]}"; do
    IFS=':' read -r file desc <<< "$file_check"
    if [ -f "$file" ] || [ -f "/workspaces/mint/$file" ]; then
        echo -e "${GREEN}✓${NC} $desc"
    else
        echo -e "${RED}✗${NC} $file - MISSING!"
    fi
done

# Check Next.js apps structure
echo -e "\n${YELLOW}Checking Next.js applications...${NC}"

for app in realtime-transcriber voice-agent; do
    app_dir="frontend/$app"
    if [ -d "$app_dir" ]; then
        echo -e "${GREEN}✓${NC} $app found"
        if [ -f "$app_dir/package.json" ]; then
            echo -e "  ${GREEN}✓${NC} package.json present"
        fi
        if [ -f "$app_dir/app/page.tsx" ] || [ -f "$app_dir/app/layout.tsx" ]; then
            echo -e "  ${GREEN}✓${NC} Next.js app directory present"
        fi
    else
        echo -e "${RED}✗${NC} $app not found"
    fi
done

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Setup Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}Frontend Applications:${NC}"
echo -e "  • Realtime Transcriber → Port 3001"
echo -e "  • Voice Agent → Port 3002"
echo -e "  • PWA → Port 3003"
echo -e "  • API Gateway → Port 80"

echo -e "\n${GREEN}Quick Start:${NC}"
echo -e "  1. ./build-frontend-all.sh"
echo -e "  2. docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d"

echo -e "\n${GREEN}Or use interactive menu:${NC}"
echo -e "  ./deploy-frontend.sh"

echo -e "\n${BLUE}========================================${NC}"
