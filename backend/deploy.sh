#!/bin/bash
# Speda Backend - Oracle Cloud Deployment Script
# Run this on your Oracle Free Tier server

set -e

echo "🚀 Speda Backend Deployment Script"
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please don't run as root. Run as a regular user with sudo access.${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}🐳 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo -e "${GREEN}Docker installed! Please log out and back in, then run this script again.${NC}"
    exit 0
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}🐳 Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create project directory
PROJECT_DIR="$HOME/speda-backend"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo -e "${YELLOW}📁 Project directory: $PROJECT_DIR${NC}"

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please create .env file with your configuration:"
    echo "  nano $PROJECT_DIR/.env"
    echo ""
    echo "Required variables:"
    echo "  SECRET_KEY=your-secret-key"
    echo "  API_TOKEN=your-api-token"
    echo "  OPENAI_API_KEY=sk-..."
    echo "  GOOGLE_CLIENT_ID=..."
    echo "  GOOGLE_CLIENT_SECRET=..."
    echo "  GOOGLE_REDIRECT_URI=https://your-domain/api/auth/google/callback"
    exit 1
fi

# Stop existing container if running
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null || true

# Clean up dangling images and containers
echo -e "${YELLOW}🧹 Cleaning up old resources...${NC}"
docker system prune -f 2>/dev/null || true

# Pull or build
echo -e "${YELLOW}🔨 Building Docker image...${NC}"
docker-compose build --no-cache

# Start container
echo -e "${YELLOW}🚀 Starting Speda Backend...${NC}"
docker-compose up -d --force-recreate

# Wait for health check
echo -e "${YELLOW}⏳ Waiting for service to be healthy...${NC}"
sleep 10

# Check if running
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Speda Backend is running!${NC}"
    echo ""
    echo "📊 Container Status:"
    docker-compose ps
    echo ""
    echo "📋 Logs (last 20 lines):"
    docker-compose logs --tail=20
    echo ""
    echo -e "${GREEN}🎉 Deployment complete!${NC}"
    echo ""
    echo "Your API is available at: http://$(curl -s ifconfig.me):8000"
    echo "Health check: http://$(curl -s ifconfig.me):8000/health"
    echo ""
    echo "Useful commands:"
    echo "  View logs:     docker-compose logs -f"
    echo "  Restart:       docker-compose restart"
    echo "  Stop:          docker-compose down"
    echo "  Update:        git pull && docker-compose up -d --build"
else
    echo -e "${RED}❌ Container failed to start. Check logs:${NC}"
    docker-compose logs
    exit 1
fi
