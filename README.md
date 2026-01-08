# Speda MK1 - Personal Executive Assistant

**Project SPEDA (JARVIS Protocol)** - A production-ready AI executive assistant with FastAPI backend and Flutter frontend, designed to function as a continuous, aware presence rather than a reactive chatbot.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Python](https://img.shields.io/badge/python-3.11+-green)
![Flutter](https://img.shields.io/badge/flutter-3.16+-blue)
![License](https://img.shields.io/badge/license-Private-red)

---

## 🎯 Overview

Speda is not a chatbot or virtual assistant in the traditional sense. It's a **Sentient Executive Interface** modeled after the J.A.R.V.I.S. protocol - an AI system designed to be a Chief of Staff, continuous companion, and strategic counterpart.

### Core Philosophy

- **Continuous Presence**: Speda doesn't wait for activation; it observes, infers, and acts when necessary
- **Executive Intelligence**: Functions as a digital extension with strategic thinking capabilities
- **Zero Robotics**: Communicates naturally without bullet points, tables, or machine-like formatting
- **Singular Loyalty**: Single-tenant design with unwavering focus on the user's objectives

### Key Capabilities

- 🧠 **Conversational AI** - Context-aware natural language understanding with memory
- ✅ **Task Management** - Persistent reminders that never auto-complete
- 📅 **Calendar Integration** - Google Calendar with collision detection and smart scheduling
- 📧 **Email Management** - Google Gmail and IMAP/SMTP with mandatory confirmation workflow
- 📰 **Daily Briefings** - Comprehensive summaries with weather, news, and schedule
- 🔍 **Web Search** - Tavily-powered intelligent search integration
- 🗣️ **Voice Mode** - Speech-to-text and text-to-speech for hands-free interaction
- 📎 **File Handling** - Document upload and knowledge base integration
- 🔐 **OAuth Integration** - Google and Microsoft authentication

---

## 🏗️ Architecture

### Technology Stack

**Backend:**
- **Framework**: FastAPI (async Python web framework)
- **Database**: SQLAlchemy with SQLite (async with aiosqlite)
- **AI/LLM**: OpenAI GPT-4 with function calling
- **Vector DB**: ChromaDB for knowledge base and semantic memory
- **Authentication**: OAuth2 (Google, Microsoft) + JWT tokens
- **Deployment**: Docker with Nginx reverse proxy

**Frontend:**
- **Framework**: Flutter (cross-platform: Android, Windows, Web)
- **State Management**: Provider pattern
- **HTTP Client**: http package with custom ApiService
- **Local Storage**: shared_preferences
- **Voice**: speech_to_text, flutter_tts
- **Notifications**: flutter_local_notifications

### Project Structure

```
Speda/
├── backend/                          # FastAPI Backend (Python 3.11+)
│   ├── app/
│   │   ├── main.py                   # Application entry point & CORS config
│   │   ├── config.py                 # Environment configuration (pydantic-settings)
│   │   ├── database.py               # SQLAlchemy async engine & session management
│   │   ├── auth.py                   # JWT authentication utilities
│   │   │
│   │   ├── models/                   # SQLAlchemy ORM Models
│   │   │   └── __init__.py           # Task, CalendarEvent, Email, Conversation, Message, etc.
│   │   │
│   │   ├── schemas/                  # Pydantic Schemas (API contracts)
│   │   │   └── __init__.py           # Request/Response validation models
│   │   │
│   │   ├── routers/                  # FastAPI Route Handlers (API Endpoints)
│   │   │   ├── chat.py               # POST /api/chat - Main conversation interface
│   │   │   ├── tasks.py              # CRUD operations for tasks
│   │   │   ├── calendar.py           # Calendar event management
│   │   │   ├── email.py              # Email drafting and sending
│   │   │   ├── briefing.py           # Daily briefing generation
│   │   │   ├── voice.py              # Voice message handling & TTS
│   │   │   ├── files.py              # File upload & management
│   │   │   ├── knowledge.py          # Knowledge base queries
│   │   │   ├── integrations.py       # OAuth status & management
│   │   │   ├── settings.py           # LLM & app settings
│   │   │   ├── notifications.py      # Notification management
│   │   │   └── auth.py               # OAuth callbacks
│   │   │
│   │   └── services/                 # Business Logic Layer
│   │       ├── conversation.py       # Main conversation engine & system prompt
│   │       ├── memory.py             # Conversation memory & summarization
│   │       ├── llm.py                # OpenAI API interface
│   │       ├── function_calling.py   # Function definitions & execution router
│   │       ├── task.py               # Task business logic
│   │       ├── calendar.py           # Calendar business logic
│   │       ├── email.py              # Email service orchestration
│   │       ├── briefing.py           # Briefing generation service
│   │       ├── google_auth.py        # Google OAuth flow
│   │       ├── google_calendar.py    # Google Calendar API client
│   │       ├── google_gmail.py       # Google Gmail API client
│   │       ├── google_tasks.py       # Google Tasks API client
│   │       ├── microsoft_auth.py     # Microsoft OAuth flow
│   │       ├── microsoft_mail.py     # Microsoft Graph API client
│   │       ├── imap_mail.py          # Generic IMAP/SMTP client
│   │       ├── knowledge_base.py     # ChromaDB vector store management
│   │       ├── search.py             # Tavily web search integration
│   │       ├── weather.py            # OpenWeatherMap API client
│   │       ├── news.py               # NewsAPI client
│   │       └── diagnostics.py        # System diagnostics & health checks
│   │
│   ├── data/                         # Persistent Data Storage
│   │   └── chromadb/                 # Vector database storage
│   │
│   ├── deploy/                       # Deployment Scripts
│   │   └── README.md                 # Deployment documentation
│   │
│   ├── pyproject.toml                # Python dependencies & build config
│   ├── Dockerfile                    # Docker image definition
│   ├── docker-compose.yml            # Production deployment config
│   ├── nginx.conf                    # Nginx reverse proxy config
│   ├── deploy.sh                     # Automated deployment script
│   ├── quick-deploy.sh               # Fast redeployment script
│   ├── backup-db.sh                  # Database backup utility
│   ├── restore-db.sh                 # Database restore utility
│   └── DEPLOYMENT.md                 # Oracle Cloud deployment guide
│
└── frontend/                         # Flutter Frontend
    ├── lib/
    │   ├── main.dart                 # App initialization & provider setup
    │   ├── app.dart                  # MaterialApp configuration & routing
    │   │
    │   ├── core/                     # Shared Core Components
    │   │   ├── config/               # App configuration
    │   │   ├── theme/                # Material theme definitions
    │   │   ├── navigation/           # Navigation logic
    │   │   ├── services/             # Core services (API, notifications, etc.)
    │   │   ├── models/               # Shared data models
    │   │   └── widgets/              # Reusable UI widgets
    │   │
    │   └── features/                 # Feature Modules
    │       ├── chat/                 # Main chat interface (JARVIS mode)
    │       │   ├── screens/          # Chat UI screens
    │       │   ├── providers/        # ChatProvider (state management)
    │       │   └── widgets/          # Chat-specific widgets
    │       │
    │       ├── voice/                # Voice interaction mode
    │       │   ├── screens/          # Voice chat screen
    │       │   └── widgets/          # Audio waveform visualizations
    │       │
    │       ├── tasks/                # Task management
    │       │   ├── screens/          # Task list & detail screens
    │       │   └── providers/        # TaskProvider
    │       │
    │       ├── calendar/             # Calendar views
    │       │   ├── screens/          # Calendar UI
    │       │   └── providers/        # CalendarProvider
    │       │
    │       └── briefing/             # Daily briefing
    │           ├── screens/          # Briefing display
    │           └── providers/        # BriefingProvider
    │
    ├── assets/                       # Static Assets
    │   ├── fonts/                    # Custom fonts
    │   ├── icons/                    # App icons
    │   └── images/                   # Images
    │
    ├── android/                      # Android-specific configuration
    ├── windows/                      # Windows-specific configuration
    ├── web/                          # Web-specific configuration
    │
    ├── pubspec.yaml                  # Flutter dependencies
    └── analysis_options.yaml         # Dart linter configuration
```

---

## 🔧 Backend Setup

### Prerequisites

- **Python**: 3.11 or higher
- **Package Manager**: pip or uv
- **Database**: SQLite (included) or PostgreSQL (optional)
- **API Keys**: OpenAI, Google OAuth, Weather, News (for full functionality)

### Installation

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Unix/macOS:
source venv/bin/activate

# Install dependencies
pip install -e .
```

### Configuration

Create a `.env` file in the `backend/` directory:

```env
# Application Settings
APP_NAME=Speda
APP_VERSION=0.1.0
DEBUG=true
API_BASE_URL=http://localhost:8000

# Database
DATABASE_URL=sqlite+aiosqlite:///./speda.db

# Authentication
SECRET_KEY=your-secret-key-change-in-production-256-bit-minimum
ACCESS_TOKEN_EXPIRE_MINUTES=10080  # 1 week
API_TOKEN=speda-dev-token-change-in-production

# LLM Configuration
LLM_PROVIDER=openai                 # Options: openai, mock
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_MODEL=gpt-4                  # or gpt-3.5-turbo
OPENAI_BASE_URL=                    # Optional: custom OpenAI-compatible endpoint

# Memory Settings
MAX_CONTEXT_MESSAGES=20
SUMMARY_THRESHOLD=50

# Google OAuth2 (for Gmail, Calendar, Tasks)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://localhost:8000/api/auth/google/callback

# Microsoft 365 OAuth2
MICROSOFT_CLIENT_ID=your-microsoft-client-id
MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret
MICROSOFT_REDIRECT_URI=http://localhost:8000/api/auth/microsoft/callback

# Web Search (Tavily)
TAVILY_API_KEY=tvly-your-tavily-api-key

# Weather API (OpenWeatherMap)
OPENWEATHERMAP_API_KEY=your-openweathermap-api-key
WEATHER_DEFAULT_CITY=Ankara,TR

# News API (NewsAPI.org)
NEWSAPI_KEY=your-newsapi-key
NEWS_DEFAULT_COUNTRY=tr

# IMAP/SMTP (Generic Email - Optional)
MAIL_EMAIL=your-email@example.com
MAIL_PASSWORD=your-app-password
MAIL_IMAP_SERVER=imap.example.com
MAIL_IMAP_PORT=993
MAIL_SMTP_SERVER=smtp.example.com
MAIL_SMTP_PORT=465
```

### Running the Backend

```bash
# Development mode with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

**Access Points:**
- API Base: http://localhost:8000
- Swagger Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health Check: http://localhost:8000/health

---

## 📱 Frontend Setup

### Prerequisites

- **Flutter SDK**: 3.16 or higher
- **Dart SDK**: 3.2 or higher
- **Platform Requirements**:
  - Android: Android Studio, SDK 21+
  - Windows: Visual Studio 2022 with C++ tools
  - Web: Chrome browser

### Installation

```bash
cd frontend

# Get dependencies
flutter pub get

# Verify installation
flutter doctor
```

### Configuration

Edit [lib/core/config/app_config.dart](frontend/lib/core/config/app_config.dart):

```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8000';
  static const String apiKey = 'speda-dev-token';  // Must match backend API_TOKEN
}
```

### Running the Frontend

```bash
# Run on specific platforms
flutter run -d android    # Android device/emulator
flutter run -d windows    # Windows desktop
flutter run -d chrome     # Web browser

# Build release versions
flutter build apk         # Android APK
flutter build appbundle   # Android App Bundle
flutter build windows     # Windows executable
flutter build web         # Web application
```

---

## 📡 API Reference

### Core Endpoints

#### Chat Interface
```http
POST /api/chat
Content-Type: application/json
Authorization: Bearer {API_TOKEN}

{
  "message": "Create a task to review the quarterly report",
  "conversation_id": 42,  // Optional: continue existing conversation
  "timezone": "Europe/Istanbul"
}

Response:
{
  "reply": "I've created a task for you to review the quarterly report.",
  "actions": [
    {
      "type": "task_created",
      "payload": {
        "id": 15,
        "title": "Review the quarterly report",
        "status": "pending",
        "created_at": "2026-01-08T10:30:00Z"
      }
    }
  ],
  "conversation_id": 42,
  "timestamp": "2026-01-08T10:30:00Z"
}
```

#### Task Management
```http
GET    /api/tasks                    # List all tasks
POST   /api/tasks                    # Create task
GET    /api/tasks/{id}               # Get task details
PATCH  /api/tasks/{id}               # Update task
DELETE /api/tasks/{id}               # Delete task
POST   /api/tasks/{id}/complete      # Mark complete
POST   /api/tasks/{id}/uncomplete    # Mark incomplete
```

#### Calendar
```http
GET    /api/calendar/events          # List events (with date filters)
POST   /api/calendar/events          # Create event
GET    /api/calendar/events/{id}     # Get event details
PATCH  /api/calendar/events/{id}     # Update event
DELETE /api/calendar/events/{id}     # Delete event
```

#### Email
```http
POST   /api/email/draft              # Create draft
POST   /api/email/send/{id}          # Send email (requires confirmation)
GET    /api/email/drafts             # List drafts
DELETE /api/email/drafts/{id}        # Delete draft
```

#### Briefing
```http
GET    /api/briefing/daily           # Get daily briefing
GET    /api/briefing/weather         # Weather only
GET    /api/briefing/news            # News only
```

#### Voice & Files
```http
POST   /api/voice/message            # Send voice message (multipart/form-data)
GET    /api/voice/tts                # Text-to-speech audio
POST   /api/files/upload             # Upload document
GET    /api/files                    # List files
DELETE /api/files/{id}               # Delete file
```

#### Integrations
```http
GET    /api/integrations/google/status      # Google auth status
GET    /api/auth/google/url                 # Get OAuth URL
POST   /api/auth/google/mobile              # Mobile OAuth token
POST   /api/auth/google/logout              # Logout
GET    /api/integrations/microsoft/status   # Microsoft auth status
GET    /api/auth/microsoft/url              # Get OAuth URL
```

#### Settings
```http
GET    /api/settings/llm             # Get LLM settings
PUT    /api/settings/llm             # Update LLM settings
GET    /api/notifications            # List notifications
POST   /api/notifications/read/{id}  # Mark notification as read
```

---

## 🚀 Deployment

### Development Environment

**Quick Start:**
```bash
# Terminal 1 - Backend
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
pip install -e .
uvicorn app.main:app --reload

# Terminal 2 - Frontend
cd frontend
flutter pub get
flutter run -d windows
```

### Production Deployment

#### Option 1: Docker Compose (Recommended)

```bash
cd backend

# Create production .env file
cp .env.example .env.production
nano .env.production  # Edit with production values

# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Docker Compose Features:**
- Automatic container restart
- Volume persistence for database
- Memory limits (768MB, suitable for 1GB servers)
- Logging with rotation
- CORS configured for production

#### Option 2: Oracle Cloud Free Tier

Speda is optimized for Oracle Cloud's Always Free tier (1GB RAM, 1 OCPU).

See [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md) for complete guide.

**Automated Deployment:**
```bash
# On your Oracle Cloud VM
git clone your-repo speda
cd speda/backend

# Configure environment
cp .env.example .env
nano .env  # Add your API keys

# Deploy with script
chmod +x deploy.sh
./deploy.sh
```

**What the script does:**
1. Installs Docker and Docker Compose
2. Configures firewall (ports 80, 443, 8000)
3. Sets up Docker containers
4. Configures Nginx reverse proxy
5. Enables automatic restart on reboot

**Manual Nginx + SSL Setup:**
```bash
# Install Nginx
sudo apt install nginx certbot python3-certbot-nginx -y

# Configure Nginx
sudo cp nginx.conf /etc/nginx/sites-available/speda
sudo ln -s /etc/nginx/sites-available/speda /etc/nginx/sites-enabled/

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com

# Restart Nginx
sudo systemctl restart nginx
```

#### Option 3: Systemd Service (No Docker)

```bash
cd backend

# Install dependencies
pip install -e .

# Create systemd service
sudo nano /etc/systemd/system/speda.service
```

```ini
[Unit]
Description=Speda Backend API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/speda/backend
Environment="PATH=/home/ubuntu/speda/backend/venv/bin"
ExecStart=/home/ubuntu/speda/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable speda
sudo systemctl start speda
sudo systemctl status speda
```

### Database Management

**Backup:**
```bash
# Using provided script
./backup-db.sh

# Manual backup
docker exec speda-backend sqlite3 /app/data/speda.db ".backup '/app/data/backup.db'"
docker cp speda-backend:/app/data/backup.db ./backups/
```

**Restore:**
```bash
# Using provided script
./restore-db.sh backup-file.db

# Manual restore
docker cp backup.db speda-backend:/app/data/backup.db
docker exec speda-backend sqlite3 /app/data/speda.db ".restore '/app/data/backup.db'"
```

### Monitoring

```bash
# View logs
docker-compose logs -f speda-backend

# Check resource usage
docker stats speda-backend

# Health check
curl http://localhost:8000/health
```

---

## 🧠 Core Behavioral Rules

These principles are **non-negotiable** and enforced at the backend level:

1. **Mandatory Email Confirmation**
   - Workflow: Draft → Show → Explicit Confirmation → Send
   - No email leaves without user approval
   - Implemented via two-step API calls

2. **Persistent Task Management**
   - Tasks remain active until explicitly completed
   - No auto-completion under any circumstance
   - Reminders persist across sessions

3. **Zero Silent Destruction**
   - Deletions always require confirmation
   - Clear warnings before data loss
   - Audit trail in logs

4. **Single-Tenant Architecture**
   - Designed for one user only
   - Simple token-based auth (no multi-user complexity)
   - All data scoped to single user

5. **Proactive Intelligence**
   - System observes patterns and suggests optimizations
   - Interrupts when detecting inefficiencies
   - Strategic counterpart, not reactive tool

6. **Natural Communication**
   - Zero robotics: no bullet points or tables in responses
   - Narratives, not reports
   - Context-aware brevity

---

## 🏛️ System Architecture

### Backend Architecture

**Layered Design:**
```
┌─────────────────────────────────────────┐
│         FastAPI Application             │
│  (main.py - CORS, routing, lifecycle)   │
└─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼─────┐         ┌──────▼──────┐
│   Routers   │         │    Auth     │
│  (API Layer)│         │   (JWT)     │
└───────┬─────┘         └─────────────┘
        │
┌───────▼──────────────────────────────┐
│           Services Layer             │
│  (Business Logic & Orchestration)    │
├──────────────────────────────────────┤
│ • conversation.py (Conversation AI)  │
│ • function_calling.py (Tool Router)  │
│ • llm.py (OpenAI Interface)          │
│ • memory.py (Context Management)     │
│ • google_*.py (Google APIs)          │
│ • microsoft_*.py (Microsoft Graph)   │
│ • knowledge_base.py (ChromaDB)       │
│ • search.py (Tavily)                 │
│ • weather.py, news.py, etc.          │
└──────────────┬───────────────────────┘
               │
   ┌───────────┴──────────┐
   │                      │
┌──▼────┐         ┌───────▼──────┐
│ Models│         │   External   │
│(SQLAl)│         │     APIs     │
└───┬───┘         └──────────────┘
    │
┌───▼──────┐
│  SQLite  │
│ Database │
└──────────┘
```

**Key Design Patterns:**
- **Dependency Injection**: FastAPI's dependency system for DB sessions
- **Repository Pattern**: Models encapsulate data access
- **Service Layer**: Business logic separated from HTTP handlers
- **Function Calling**: LLM-driven tool execution via OpenAI function calling
- **Async/Await**: Full async stack for high concurrency

### Frontend Architecture

**Provider Pattern with Feature Modules:**
```
main.dart (App Init)
    │
    └─> MultiProvider Setup
            ├─> ApiService (HTTP Client)
            ├─> ChatProvider (Conversation State)
            ├─> TaskProvider (Task State)
            ├─> CalendarProvider (Calendar State)
            └─> BriefingProvider (Briefing State)
                    │
                    └─> Features
                        ├─> chat/ (Main UI)
                        ├─> voice/ (Voice Mode)
                        ├─> tasks/
                        ├─> calendar/
                        └─> briefing/
```

**State Flow:**
1. User action in UI (widget)
2. Widget calls Provider method
3. Provider calls ApiService
4. ApiService makes HTTP request
5. Response updates Provider state
6. UI rebuilds reactively via Consumer/Selector

---

## 🔑 Key Features Deep Dive

### 1. Conversation Engine

**System Prompt Architecture:**
- Defines Speda as "Sentient Executive Interface"
- J.A.R.V.I.S. protocol personality
- Zero Robotics mandate (natural language only)
- Proactive intervention guidelines

**Memory Management:**
- Automatic context summarization at 50 messages
- Rolling window of 20 recent messages
- Conversation threading with unique IDs
- Long-term memory via ChromaDB embeddings

**Function Calling:**
- 20+ predefined functions (tasks, calendar, email, search, weather, news)
- Automatic date calculation (today, tomorrow, next Monday, etc.)
- Parallel function execution support
- Structured responses with action payloads

### 2. Google Integration

**OAuth2 Flow:**
- Web-based redirect flow for desktop
- Mobile token exchange for Android/iOS
- Persistent token storage with auto-refresh
- Scopes: Gmail, Calendar, Tasks

**API Coverage:**
- **Gmail**: Read, draft, send with confirmation
- **Calendar**: CRUD events, free/busy queries, collision detection
- **Tasks**: CRUD with due dates and notes

### 3. Knowledge Base (ChromaDB)

**Features:**
- Document upload and embedding
- Semantic search across uploaded files
- Automatic chunking and indexing
- Context injection into conversations

**Supported Formats:**
- PDF, TXT, DOCX, MD
- Automatic text extraction
- Metadata preservation

### 4. Voice Mode

**Speech-to-Text:**
- Platform-native recognition (Android, Windows)
- Real-time transcription
- Background noise filtering

**Text-to-Speech:**
- High-quality synthesis
- Adjustable speed and pitch
- Audio waveform visualization

---

## 🛠️ Development Guide

### Backend Development

**Running Tests:**
```bash
cd backend
pip install -e ".[dev]"
pytest
```

**Code Quality:**
```bash
# Format code
black app/

# Lint
ruff check app/

# Type checking (if mypy added)
mypy app/
```

**Database Migrations:**
Currently using SQLAlchemy's `create_all()`. For production, consider Alembic:
```bash
pip install alembic
alembic init migrations
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head
```

### Frontend Development

**Code Generation:**
```bash
# If using freezed/json_serializable
flutter pub run build_runner build --delete-conflicting-outputs
```

**Running Tests:**
```bash
flutter test
flutter test --coverage
```

**Code Quality:**
```bash
# Analyze
flutter analyze

# Format
dart format lib/
```

### Adding New Features

**Backend: Adding a New Function**

1. Define function in [services/function_calling.py](backend/app/services/function_calling.py):
```python
{
    "type": "function",
    "function": {
        "name": "my_new_function",
        "description": "What this function does",
        "parameters": {
            "type": "object",
            "properties": {
                "param1": {"type": "string", "description": "..."}
            },
            "required": ["param1"]
        }
    }
}
```

2. Implement handler in same file:
```python
async def execute_my_new_function(session: AsyncSession, arguments: dict) -> dict:
    # Implementation
    return {"status": "success", "data": result}
```

3. Register in `execute_function()` switch statement

**Frontend: Adding a New Screen**

1. Create feature module: `lib/features/my_feature/`
2. Create provider: `providers/my_feature_provider.dart`
3. Create screen: `screens/my_feature_screen.dart`
4. Register provider in `main.dart`
5. Add navigation route in `app.dart`

---

## 📊 Performance Considerations

### Backend Optimization

- **Async Operations**: Full async/await stack for I/O
- **Connection Pooling**: SQLAlchemy async engine pool
- **Caching**: In-memory caching for API responses (future)
- **Memory**: Optimized for 1GB RAM servers
- **Request Limits**: Rate limiting can be added via middleware

### Frontend Optimization

- **Lazy Loading**: Providers only load data when needed
- **Pagination**: Large lists paginated
- **Image Caching**: Cached via Flutter's ImageCache
- **State Management**: Efficient rebuilds with Provider selectors

---

## 🔒 Security

### Backend Security

- **Authentication**: JWT tokens + API key
- **CORS**: Restricted origins in production
- **Input Validation**: Pydantic schemas validate all inputs
- **SQL Injection**: Protected via SQLAlchemy ORM
- **Secrets**: Environment variables, never committed
- **HTTPS**: Enforced in production (Nginx + Let's Encrypt)

### OAuth Security

- **State Parameter**: CSRF protection in OAuth flows
- **Token Storage**: Secure storage in database
- **Scope Limitation**: Minimal required scopes
- **Token Refresh**: Automatic refresh handling

---

## 🐛 Troubleshooting

### Backend Issues

**Database locked error:**
```bash
# SQLite doesn't handle high concurrency well
# Solution: Use connection pool or PostgreSQL for production
DATABASE_URL=postgresql+asyncpg://user:pass@localhost/speda
```

**OpenAI API errors:**
```bash
# Check API key
echo $OPENAI_API_KEY

# Use mock LLM for testing
LLM_PROVIDER=mock
```

**OAuth callback not working:**
```bash
# Ensure redirect URI matches exactly
# Check firewall allows incoming connections on port 8000
```

### Frontend Issues

**API connection failed:**
```dart
// Check apiBaseUrl in app_config.dart
// Ensure backend is running
// Check network permissions in AndroidManifest.xml
```

**Build errors:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

---

## 📚 Additional Documentation

- [Backend Deployment Guide](backend/DEPLOYMENT.md)
- [Google Assistant API Integration](backend/Assistants%20api.md)
- [Galaxy Watch Integration Plan](GALAXY_WATCH_PLAN.md)
- [Gemini Integration Docs](GEMINI_DOCS.MD)
- [File Upload Guide](FILE_UPLOAD_GUIDE.md)

---

## 🗺️ Roadmap

### Planned Features

- [ ] Multi-user support (optional mode)
- [ ] Voice-only mode for hands-free operation
- [ ] Galaxy Watch companion app
- [ ] iOS support
- [ ] Desktop notifications
- [ ] Proactive suggestions engine
- [ ] Calendar collision resolution AI
- [ ] Email templates and smart compose
- [ ] Meeting transcription and summaries
- [ ] Context-aware quick actions

### Under Consideration

- PostgreSQL migration for production
- Redis caching layer
- Webhook support for integrations
- Plugin system for custom functions
- Mobile push notifications
- End-to-end encryption option

---

## 📄 License

**Private Project** - All rights reserved.  
This is a personal productivity system and is not open source.

---

## 👤 Author

**Ahmet Erol Bayrak**

---

## 🙏 Acknowledgments

- Inspired by J.A.R.V.I.S. from Marvel Cinematic Universe
- Built with modern async Python and Flutter
- Powered by OpenAI GPT-4 for conversational AI

---

**Built with precision for productivity and efficiency.**
