# Speda Backend - Oracle Cloud Deployment Guide

## Prerequisites

1. Oracle Cloud Free Tier account
2. A VM instance (1GB RAM, 1 OCPU is enough)
3. Domain name (optional, for HTTPS)

## Quick Start

### 1. Create Oracle Cloud VM

1. Go to Oracle Cloud Console
2. Create a new Compute Instance:
   - Image: Ubuntu 22.04 (or Canonical Ubuntu)
   - Shape: VM.Standard.E2.1.Micro (Always Free)
   - Add SSH key for access

3. Configure Security List (Networking):
   - Allow ingress on port 22 (SSH)
   - Allow ingress on port 80 (HTTP)
   - Allow ingress on port 443 (HTTPS)
   - Allow ingress on port 8000 (API - optional, for testing)

### 2. Connect to Server

```bash
ssh -i your-key.pem ubuntu@your-server-ip
```

### 3. Upload Project Files

Option A: Git Clone (recommended)
```bash
git clone https://github.com/your-repo/speda.git
cd speda/backend
```

Option B: SCP Upload
```bash
# From your local machine
scp -i your-key.pem -r backend/ ubuntu@your-server-ip:~/speda-backend/
```

### 4. Configure Environment

```bash
cd ~/speda-backend
cp .env.production .env
nano .env
```

Fill in your values:
```env
SECRET_KEY=generate-secure-random-string
API_TOKEN=your-mobile-app-api-token
OPENAI_API_KEY=sk-your-key
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-secret
GOOGLE_REDIRECT_URI=https://your-domain.com/api/auth/google/callback
OPENWEATHERMAP_API_KEY=your-key
NEWSAPI_KEY=your-key
```

### 5. Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

## HTTPS Setup (Recommended)

### Option 1: Cloudflare (Easiest)

1. Add your domain to Cloudflare
2. Point DNS to Oracle Cloud IP
3. Enable "Full" SSL mode
4. Cloudflare will handle HTTPS

### Option 2: Let's Encrypt with Nginx

```bash
# Install Nginx
sudo apt install nginx -y

# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Copy nginx config
sudo cp nginx.conf /etc/nginx/sites-available/speda
sudo ln -s /etc/nginx/sites-available/speda /etc/nginx/sites-enabled/

# Edit config with your domain
sudo nano /etc/nginx/sites-available/speda

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Restart Nginx
sudo systemctl restart nginx
```

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Restart service
docker-compose restart

# Stop service
docker-compose down

# Update and restart
git pull
docker-compose up -d --build

# Check resource usage
docker stats

# Backup database
docker cp speda-backend:/app/data/speda.db ./backup-$(date +%Y%m%d).db
```

## Mobile App Configuration

After deployment, update `lib/core/config/app_config.dart`:

```dart
static String get apiBaseUrl {
  if (kDebugMode) {
    return 'http://localhost:8000';
  }
  return 'https://your-actual-domain.com';  // Your server URL
}
```

## Firewall Configuration (Oracle Cloud)

Oracle Cloud requires both Security List AND iptables rules:

```bash
# Allow HTTP
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT

# Allow HTTPS
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Allow API port (for testing)
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8000 -j ACCEPT

# Save rules
sudo netfilter-persistent save
```

## Troubleshooting

### Container won't start
```bash
docker-compose logs
```

### Out of memory
The config is optimized for 1GB RAM, but if issues occur:
```bash
# Add swap
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Port not accessible
Check Oracle Cloud Security List AND iptables rules.

## Security Checklist

- [ ] Changed SECRET_KEY from default
- [ ] Changed API_TOKEN from default  
- [ ] HTTPS enabled (via Cloudflare or Let's Encrypt)
- [ ] Firewall configured (only needed ports open)
- [ ] Regular backups configured
