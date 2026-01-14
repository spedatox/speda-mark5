# S.P.E.D.A.

**Specialized Personal Executive Digital Assistant**

<p align="center">
  <img src="frontend/assets/icons/speda_logo.png" alt="S.P.E.D.A." width="120" />
</p>

<p align="center">
  <em>Your AI-powered digital Chief of Staff – Just like J.A.R.V.I.S.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/python-3.11+-green" alt="Python">
  <img src="https://img.shields.io/badge/flutter-3.16+-blue" alt="Flutter">
  <img src="https://img.shields.io/badge/AI-GPT--4-purple" alt="AI">
</p>

---

## What is S.P.E.D.A.?

S.P.E.D.A. is not a chatbot. It's your **digital executive assistant** – a continuous, aware presence that manages your calendar, tasks, emails, and daily briefings with proactive intelligence.

### ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🧠 **Conversational AI** | Natural language interface with context memory |
| 📍 **Location Awareness** | Knows where you are for contextual responses |
| 📅 **Calendar Management** | Google Calendar integration with smart scheduling |
| ✅ **Task Management** | Persistent reminders that never forget |
| 📧 **Email Drafting** | Gmail integration with mandatory confirmation |
| 🌤️ **Daily Briefing** | Weather, schedule, tasks, and news at a glance |
| 🗣️ **Voice Mode** | Hands-free interaction with TTS/STT |
| 📎 **Image Upload** | Attach images and ask questions about them |
| 🔍 **Web Search** | Tavily-powered intelligent search |

---

## 🖼️ Screenshots

<table>
<tr>
<td><strong>Chat Interface</strong></td>
<td><strong>History Drawer</strong></td>
<td><strong>Daily Briefing</strong></td>
</tr>
<tr>
<td><img src="docs/screenshots/chat.png" width="200"/></td>
<td><img src="docs/screenshots/drawer.png" width="200"/></td>
<td><img src="docs/screenshots/briefing.png" width="200"/></td>
</tr>
</table>

---

## 🚀 Quick Start

### Prerequisites

- **Python** 3.11+
- **Flutter** 3.16+
- **API Keys**: OpenAI, Google OAuth (optional: Weather, News, Tavily)

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -e .

# Configure environment
cp .env.example .env
# Edit .env with your API keys

# Run server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d windows  # or -d android, -d chrome
```

---

## ⚙️ Configuration

Create `backend/.env`:

```env
# Required
OPENAI_API_KEY=sk-your-key
API_TOKEN=your-secure-token
SECRET_KEY=your-256-bit-secret

# Google Integration (Optional)
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-secret
GOOGLE_REDIRECT_URI=http://localhost:8000/api/auth/google/callback

# Weather & News (Optional)
OPENWEATHERMAP_API_KEY=your-key
NEWSAPI_KEY=your-key
TAVILY_API_KEY=your-key
```

Update `frontend/lib/core/config/app_config.dart`:

```dart
static const String cloudBackendUrl = 'http://YOUR_SERVER_IP:8000';
static const String cloudApiKey = 'your-secure-token';
```

---

## 🏗️ Architecture

```
S.P.E.D.A.
├── backend/                 # FastAPI (Python)
│   ├── app/
│   │   ├── routers/         # API endpoints
│   │   ├── services/        # Business logic
│   │   └── models/          # Database models
│   └── Dockerfile
│
└── frontend/                # Flutter (Dart)
    └── lib/
        ├── core/            # Shared components
        └── features/        # Feature modules
            ├── chat/        # Main chat interface
            ├── voice/       # Voice interaction
            ├── tasks/       # Task management
            ├── calendar/    # Calendar views
            └── briefing/    # Daily briefing
```

---

## 🌐 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/chat` | POST | Main conversation interface |
| `/api/chat/stream` | POST | Streaming conversation |
| `/api/tasks` | GET/POST | Task management |
| `/api/calendar/events` | GET/POST | Calendar events |
| `/api/briefing/today` | GET | Daily briefing with weather |
| `/api/voice/tts` | POST | Text-to-speech |
| `/health` | GET | Health check |

Full API docs: `http://localhost:8000/docs`

---

## 🚢 Deployment

### Docker (Recommended)

```bash
cd backend
docker-compose up -d
```

### Oracle Cloud Free Tier

See [DEPLOYMENT.md](backend/DEPLOYMENT.md) for complete guide.

---

## 🎨 Design Philosophy

1. **Gemini-Style UI** – Clean, modern interface inspired by Google Gemini
2. **Two-Row Input** – Text field on top, action buttons below
3. **Drawer Navigation** – All screens accessible via hamburger menu
4. **Location Aware** – Weather and context based on your location
5. **No Robotics** – Natural language, no bullet points or tables in responses

---

## 🔧 Tech Stack

**Backend:**
- FastAPI + SQLAlchemy (async)
- OpenAI GPT-4 with Function Calling
- ChromaDB for vector storage
- Google OAuth2 + Gmail/Calendar APIs

**Frontend:**
- Flutter 3.16+ (Android, Windows, Web)
- Provider state management
- Geolocator for location services
- flutter_markdown for rich text

---

## 📝 License

Private project. All rights reserved.

---

## 👤 Author

**Ahmet Erol Bayrak** (Spedatox)

---

<p align="center">
  <strong>S.P.E.D.A.</strong> – Specialized Personal Executive Digital Assistant
  <br>
  <em>"Good morning, sir. I've prepared your briefing."</em>
</p>
