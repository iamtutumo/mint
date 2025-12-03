#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the root directory of the project
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Node.js and npm
install_nodejs() {
    echo -e "\n${BLUE}=== Installing Node.js and npm ===${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt-get; then
            echo -e "${YELLOW}Detected Debian/Ubuntu system. Installing Node.js...${NC}"
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command_exists yum; then
            echo -e "${YELLOW}Detected RHEL/CentOS system. Installing Node.js...${NC}"
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
        else
            echo -e "${RED}Unsupported Linux distribution${NC}"
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            echo -e "${YELLOW}Detected macOS with Homebrew. Installing Node.js...${NC}"
            brew install node@18
        fi
    else
        echo -e "${RED}Unsupported operating system${NC}"
        return 1
    fi

    if command_exists node && command_exists npm; then
        echo -e "${GREEN}✓ Node.js $(node -v) and npm $(npm -v) installed${NC}"
        return 0
    else
        echo -e "${RED}Failed to install Node.js and npm${NC}"
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
echo -e "\n${BLUE}=== Installing Global Packages ===${NC}"
for pkg in pnpm yarn typescript; do
    if ! npm list -g "$pkg" >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing global package: $pkg${NC}"
        npm install -g "$pkg" || echo -e "${YELLOW}Warning: Failed to install $pkg${NC}"
    else
        echo -e "${GREEN}✓ $pkg is installed${NC}"
    fi
done

# Function to build a Next.js app
build_nextjs_app() {
    local app_dir=$1
    local app_name=$2
    
    echo -e "\n${BLUE}=== Building $app_name ===${NC}"
    
    if [ ! -d "$app_dir" ]; then
        echo -e "${RED}Error: Directory not found: $app_dir${NC}"
        return 1
    fi
    
    cd "$app_dir" || return 1
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        echo -e "${RED}Error: package.json not found in $app_dir${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Installing dependencies for $app_name...${NC}"
    if [ -f "pnpm-lock.yaml" ]; then
        pnpm install --frozen-lockfile || {
            echo -e "${RED}Error installing dependencies with pnpm${NC}"
            return 1
        }
    else
        npm install || {
            echo -e "${RED}Error installing dependencies with npm${NC}"
            return 1
        }
    fi
    
    echo -e "${YELLOW}Building $app_name...${NC}"
    npm run build || {
        echo -e "${RED}Error building $app_name${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ Successfully built $app_name${NC}"
    return 0
}

# Function to build PWA React app
build_pwa() {
    local frontend_dir="$ROOT_DIR/services/pwa"
    
    echo -e "\n${BLUE}=== Building PWA (React) ===${NC}"
    
    mkdir -p "$frontend_dir"
    
    if [ ! -d "$frontend_dir" ]; then
        echo -e "${YELLOW}Creating PWA directory...${NC}"
        mkdir -p "$frontend_dir"
    fi
    
    cd "$frontend_dir" || return 1
    
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}Initializing new React project...${NC}"
        npx create-react-app . --template typescript || {
            echo -e "${YELLOW}create-react-app failed, trying Vite...${NC}"
            npm create vite@latest . -- --template react-ts || {
                echo -e "${RED}Error creating React app${NC}"
                return 1
            }
        }
    fi
    
    echo -e "${YELLOW}Installing PWA dependencies...${NC}"
    npm install --legacy-peer-deps || {
        echo -e "${RED}Error installing PWA dependencies${NC}"
        return 1
    }
    
    # Create .env file if needed
    if [ ! -f ".env" ]; then
        cat > ".env" << 'EOL'
REACT_APP_API_URL=/api
REACT_APP_WS_URL=ws://${window.location.host}/ws
REACT_APP_ENV=development
REACT_APP_VERSION=1.0.0
EOL
    fi
    
    echo -e "${YELLOW}Building PWA...${NC}"
    npm run build || {
        echo -e "${RED}Error building PWA${NC}"
        return 1
    }
    
    # Prepare dist directory
    mkdir -p "$frontend_dir/dist"
    if [ -d "build" ]; then
        cp -r build/* "$frontend_dir/dist/" 2>/dev/null || true
    fi
    if [ -d "dist" ]; then
        cp -r dist/* "$frontend_dir/dist/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Successfully built PWA${NC}"
    return 0
}

# Build all frontends
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Building All Frontend Applications${NC}"
echo -e "${BLUE}========================================${NC}"

# Build Next.js apps
build_nextjs_app "$ROOT_DIR/frontend/realtime-transcriber" "Realtime Transcriber" || {
    echo -e "${RED}✗ Failed to build Realtime Transcriber${NC}"
}

build_nextjs_app "$ROOT_DIR/frontend/voice-agent" "Voice Agent" || {
    echo -e "${RED}✗ Failed to build Voice Agent${NC}"
}

# Build PWA
build_pwa || {
    echo -e "${RED}✗ Failed to build PWA${NC}"
}

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   Frontend Build Process Completed!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Application Endpoints:${NC}"
echo -e "  • Realtime Transcriber: http://localhost:3001"
echo -e "  • Voice Agent: http://localhost:3002"
echo -e "  • PWA: http://localhost:3000"
echo -e "  • API Gateway: http://localhost:80"
echo -e "\n${YELLOW}To start with Docker Compose:${NC}"
echo -e "  docker compose up -d"
