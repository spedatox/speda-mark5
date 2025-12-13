# Speda Backend Deployment Files

## Files Overview

| File | Purpose |
|------|---------|
| `Dockerfile` | Production Docker image (optimized for 1GB RAM) |
| `docker-compose.yml` | Container orchestration with environment variables |
| `.env.production` | Production environment template |
| `deploy.sh` | Automated deployment script for Ubuntu |
| `nginx.conf` | Nginx reverse proxy config with SSL |
| `DEPLOYMENT.md` | Detailed deployment guide |

## Quick Deploy

```bash
# 1. SSH to your Oracle Cloud server
ssh ubuntu@your-server-ip

# 2. Clone or upload the project
git clone your-repo
cd speda/backend

# 3. Configure environment
cp .env.production .env
nano .env  # Add your API keys

# 4. Run deploy script
chmod +x deploy.sh
./deploy.sh
```

## Environment Variables

Required:
- `SECRET_KEY` - Random string for JWT signing
- `API_TOKEN` - API key for mobile apps
- `OPENAI_API_KEY` - OpenAI API key

Optional:
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` - For Calendar sync
- `OPENWEATHERMAP_API_KEY` - For weather
- `NEWSAPI_KEY` - For news
