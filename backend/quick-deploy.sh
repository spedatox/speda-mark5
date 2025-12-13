#!/bin/bash
# ================================================
# SPEDA BACKEND - ONE-CLICK DEPLOY SCRIPT
# Run this on your Oracle Cloud Ubuntu server
# ================================================

set -e

echo "🚀 SPEDA Backend Deployment"
echo "============================"

# Update system
echo "📦 Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "⚠️  Docker installed! Please logout and login again, then re-run this script."
    exit 0
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create project directory
mkdir -p ~/speda
cd ~/speda

# Clone repository
if [ ! -d ".git" ]; then
    echo "📥 Cloning repository..."
    git clone https://github.com/spedatox/speda.git .
else
    echo "📥 Pulling latest changes..."
    git pull origin main
fi

cd backend

# Check for .env file
if [ ! -f ".env" ]; then
    echo ""
    echo "⚠️  .env file not found!"
    echo ""
    echo "Please create .env with your API keys:"
    echo "---------------------------------------"
    cat << 'EOF'
# Required
SECRET_KEY=your-random-secret-key-here
API_TOKEN=your-api-token-for-mobile
OPENAI_API_KEY=sk-your-openai-key

# Google OAuth (for Calendar & Tasks)
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-secret
GOOGLE_REDIRECT_URI=http://YOUR-SERVER-IP:8000/api/auth/google/callback

# Optional
OPENWEATHERMAP_API_KEY=your-weather-key
NEWSAPI_KEY=your-news-key
EOF
    echo "---------------------------------------"
    echo ""
    echo "Run: nano .env"
    echo "Then run this script again."
    exit 1
fi

# Open firewall ports
echo "🔥 Configuring firewall..."
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT 2>/dev/null || true
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true

# Build and run
echo "🔨 Building Docker image..."
docker-compose build

echo "🚀 Starting SPEDA..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# Wait for startup
echo "⏳ Waiting for startup..."
sleep 10

# Check status
if docker-compose ps | grep -q "Up"; then
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo ""
    echo "✅ SPEDA is running!"
    echo ""
    echo "🌐 API URL: http://$PUBLIC_IP:8000"
    echo "❤️  Health:  http://$PUBLIC_IP:8000/health"
    echo "📖 Docs:    http://$PUBLIC_IP:8000/docs"
    echo ""
    echo "📱 Update your Flutter app config with:"
    echo "   apiBaseUrl = 'http://$PUBLIC_IP:8000'"
    echo ""
    echo "📋 Useful commands:"
    echo "   Logs:    cd ~/speda/backend && docker-compose logs -f"
    echo "   Restart: cd ~/speda/backend && docker-compose restart"
    echo "   Stop:    cd ~/speda/backend && docker-compose down"
else
    echo "❌ Failed to start. Check logs:"
    docker-compose logs
    exit 1
fi
