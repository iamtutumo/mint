#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the root directory of the project
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# IMPORTANT: This script now builds both Next.js frontend apps:
# 1. Realtime Transcriber (frontend/realtime-transcriber)
# 2. Voice Agent (frontend/voice-agent)
# 
# These will be served on:
# - Realtime Transcriber: http://localhost:3001
# - Voice Agent: http://localhost:3002
# 
# Use with Docker Compose:
#   docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d
# ============================================

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Node.js and npm
install_nodejs() {
    echo -e "\n${BLUE}=== Installing Node.js and npm ===${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt-get; then
            # Debian/Ubuntu
            echo -e "${YELLOW}Detected Debian/Ubuntu system. Installing Node.js...${NC}"
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command_exists yum; then
            # RHEL/CentOS
            echo -e "${YELLOW}Detected RHEL/CentOS system. Installing Node.js...${NC}"
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
        else
            echo -e "${RED}Unsupported Linux distribution. Please install Node.js manually.${NC}"
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            echo -e "${YELLOW}Detected macOS with Homebrew. Installing Node.js...${NC}"
            brew install node@18
            echo 'export PATH="/usr/local/opt/node@18/bin:$PATH"' >> ~/.zshrc
            source ~/.zshrc
        else
            echo -e "${YELLOW}Installing Node.js using installer...${NC}"
            curl -o node-installer.pkg https://nodejs.org/dist/v18.17.1/node-v18.17.1.pkg
            sudo installer -pkg node-installer.pkg -target /
            rm node-installer.pkg
        fi
    else
        echo -e "${RED}Unsupported operating system. Please install Node.js manually.${NC}
Visit https://nodejs.org/ to download and install Node.js"
        return 1
    fi

    # Verify installation
    if command_exists node && command_exists npm; then
        echo -e "${GREEN}✓ Node.js $(node -v) and npm $(npm -v) installed successfully${NC}"
        return 0
    else
        echo -e "${RED}Failed to install Node.js and npm. Please install them manually.${NC}"
        return 1
    fi
}

# Check and install Node.js if needed
if ! command_exists node || ! command_exists npm; then
    echo -e "${YELLOW}Node.js and/or npm not found. Installing...${NC}"
    install_nodejs || exit 1
else
    echo -e "${GREEN}✓ Node.js $(node -v) and npm $(npm -v) are already installed${NC}"
fi

# Install required global packages
REQUIRED_GLOBAL_PKGS=("yarn" "pnpm" "typescript")
for pkg in "${REQUIRED_GLOBAL_PKGS[@]}"; do
    if ! npm list -g "$pkg" &>/dev/null; then
        echo -e "${YELLOW}Installing global package: $pkg${NC}"
        npm install -g "$pkg" || echo -e "${YELLOW}Warning: Failed to install $pkg globally${NC}"
    else
        echo -e "${GREEN}✓ $pkg is already installed globally${NC}"
    fi
done

# Ensure frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${YELLOW}Creating PWA directory at $FRONTEND_DIR...${NC}"
    mkdir -p "$FRONTEND_DIR"
fi

# Function to build the PWA application
build_pwa() {
    echo -e "\n${BLUE}=== Building PWA ===${NC}"
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        echo -e "${YELLOW}Creating PWA directory...${NC}"
        mkdir -p "$FRONTEND_DIR"
    fi
    
    cd "$FRONTEND_DIR" || {
        echo -e "${RED}Error: Could not access PWA directory${NC}"
        return 1
    }
    
    # Initialize project if package.json doesn't exist
    if [ ! -f "package.json" ]; then
        if [ "$(ls -A "$FRONTEND_DIR" 2>/dev/null)" ]; then
            echo -e "${YELLOW}Directory is not empty. Cleaning existing contents...${NC}"
            cd "$ROOT_DIR" && rm -rf "$FRONTEND_DIR" && mkdir -p "$FRONTEND_DIR" && cd "$FRONTEND_DIR" || {
                echo -e "${RED}Error resetting PWA directory${NC}"
                return 1
            }
        fi
        echo -e "${YELLOW}Initializing new React project...${NC}"
        npx create-react-app . --template typescript || {
            echo -e "${YELLOW}create-react-app failed, trying Vite (react-ts)...${NC}"
            npm create vite@latest . -- --template react-ts || {
                echo -e "${RED}Error creating frontend project${NC}"
                return 1
            }
        }
    fi
    
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install --legacy-peer-deps || {
        echo -e "${RED}Error installing dependencies${NC}"
        return 1
    }
    
    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}Creating .env file...${NC}"
        cat > ".env" << 'EOL'
# Frontend Environment Variables
REACT_APP_API_URL=/api
REACT_APP_WS_URL=ws://${window.location.host}/ws
REACT_APP_ENV=development
REACT_APP_VERSION=1.0.0

# Backend Service URLs
REACT_APP_AUTH_SERVICE_URL=${AUTH_SERVICE_URL:-http://localhost:8001}
REACT_APP_DOCUMENTS_SERVICE_URL=${DOCUMENTS_SERVICE_URL:-http://localhost:8008}
REACT_APP_OCR_SERVICE_URL=${OCR_SERVICE_URL:-http://localhost:8001}
REACT_APP_ASR_SERVICE_URL=${ASR_SERVICE_URL:-http://localhost:8002}
REACT_APP_TTS_SERVICE_URL=${TTS_SERVICE_URL:-http://localhost:8003}
REACT_APP_VOICE_SERVICE_URL=${VOICE_SERVICE_URL:-http://localhost:8004}
REACT_APP_LLM_SERVICE_URL=${LLM_SERVICE_URL:-http://localhost:8080}

# Feature Flags
REACT_APP_ENABLE_ANALYTICS=false
REACT_APP_ENABLE_LOGGING=true
EOL
    fi
    
    echo -e "${YELLOW}Building application...${NC}"
    npm run build || {
        echo -e "${RED}Error building PWA${NC}"
        return 1
    }
    
    # Ensure the dist directory exists and is properly set up for Nginx
    echo -e "${YELLOW}Preparing distribution files...${NC}"
    mkdir -p "$DIST_DIR"
    SRC_DIR="build"
    if [ -d "dist" ]; then SRC_DIR="dist"; fi
    cp -r "$SRC_DIR"/* "$DIST_DIR/"
    
    # Create Nginx configuration
    echo -e "${YELLOW}Creating Nginx configuration...${NC}"
    mkdir -p "$FRONTEND_DIR/nginx"
    cat > "$FRONTEND_DIR/nginx/default.conf" << 'NGINX_CONF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api/ {
        proxy_pass http://gateway/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket support
    location /ws/ {
        proxy_pass http://gateway/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Error pages
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
NGINX_CONF

    # Create Dockerfile for the PWA
    echo -e "${YELLOW}Creating Dockerfile...${NC}"
    cat > "$FRONTEND_DIR/Dockerfile" << 'DOCKERFILE'
# Build stage
FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
DOCKERFILE

    echo -e "${GREEN}✓ Successfully built PWA${NC}"
}

# Source environment variables if .env exists
if [ -f "$ROOT_DIR/.env" ]; then
    echo -e "${BLUE}Loading environment variables...${NC}"
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

# Build the PWA
build_pwa

echo -e "\n${GREEN}Frontend build process completed!${NC}"
echo -e "\nTo start the development servers:"
echo -e "1. For PWA:"
echo -e "   cd $FRONTEND_DIR && npm run start"
echo -e "   (Available at http://localhost:3000)"
echo -e "   (Available at http://localhost:3001)"
