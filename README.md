# Speda - Personal Executive Assistant

A production-ready personal executive assistant with a FastAPI backend and Flutter frontend.

## Overview

Speda is designed to be a **real personal assistant**, not a generic chatbot. It handles:

- **Conversation Logic** - Natural language understanding with context
- **Task Management** - Persistent reminders that never auto-complete
- **Calendar** - Event management with collision awareness
- **Email** - Draft and send with mandatory confirmation
- **Daily Briefings** - Comprehensive daily summaries

## Project Structure

```
Speda/
├── backend/                 # FastAPI Backend
│   ├── app/
│   │   ├── main.py         # Application entry point
│   │   ├── config.py       # Configuration settings
│   │   ├── database.py     # Database setup
│   │   ├── auth.py         # Authentication
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── services/       # Business logic
│   │   │   ├── conversation.py
│   │   │   ├── memory.py
│   │   │   ├── task.py
│   │   │   ├── calendar.py
│   │   │   ├── email.py
│   │   │   ├── briefing.py
│   │   │   └── llm.py
│   │   └── routers/        # API endpoints
│   │       ├── chat.py
│   │       ├── tasks.py
│   │       ├── calendar.py
│   │       ├── email.py
│   │       └── briefing.py
│   ├── pyproject.toml
│   └── .env.example
│
└── frontend/               # Flutter Frontend
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart
    │   ├── core/
    │   │   ├── config/
    │   │   ├── theme/
    │   │   ├── navigation/
    │   │   ├── services/
    │   │   ├── models/
    │   │   └── widgets/
    │   └── features/
    │       ├── chat/
    │       ├── tasks/
    │       ├── calendar/
    │       └── briefing/
    └── pubspec.yaml
```

## Core Behavioral Rules

These rules are **non-negotiable** and enforced in the backend:

1. **Never send emails without explicit user confirmation**
   - Draft → Show → Ask confirmation → Only then send

2. **Reminders are persistent**
   - Tasks stay active until user explicitly marks them done
   - Nothing auto-completes

3. **No silent destructive actions**
   - Deleting tasks, events, or data always requires confirmation

4. **Single-tenant design**
   - One user only, with simple token authentication

## Backend Setup

### Requirements

- Python 3.11+
- pip or uv for package management

### Installation

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -e .

# Copy environment file
cp .env.example .env
```

### Configuration

Edit `.env` to configure:

```env
# Use mock LLM for development (no API key needed)
LLM_PROVIDER=mock

# Or use OpenAI
LLM_PROVIDER=openai
OPENAI_API_KEY=your-key-here

# Change the API token for security
API_TOKEN=your-secure-token
```

### Running the Backend

```bash
# Development mode with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or directly
python -m app.main
```

API documentation available at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/chat` | Send a message to Speda |
| GET | `/tasks` | List all tasks |
| POST | `/tasks` | Create a new task |
| PATCH | `/tasks/{id}` | Update a task |
| POST | `/tasks/{id}/complete` | Mark task complete |
| GET | `/calendar` | List events |
| POST | `/calendar` | Create event |
| POST | `/email/draft` | Draft an email |
| POST | `/email/send` | Send email (requires confirmation) |
| GET | `/briefing/today` | Get daily briefing |

### Communication Protocol

**Request:**
```json
{
  "message": "Create a task to review the report",
  "timezone": "Europe/Istanbul"
}
```

**Response:**
```json
{
  "reply": "I've created a task for you to review the report.",
  "actions": [
    {
      "type": "task_created",
      "payload": {
        "id": 1,
        "title": "Review the report",
        "status": "pending"
      }
    }
  ],
  "conversation_id": 42
}
```

## Frontend Setup

### Requirements

- Flutter 3.16+
- Dart 3.2+

### Installation

```bash
cd frontend

# Get dependencies
flutter pub get
```

### Configuration

Edit `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8000';
  static const String apiKey = 'your-api-token';
}
```

### Running the Frontend

```bash
# Run on connected device/emulator
flutter run

# Run on web
flutter run -d chrome

# Run on specific platform
flutter run -d windows
flutter run -d macos
```

## Features

### Chat Screen (Primary Interface)
- Natural conversation with Speda
- Quick action chips for common tasks
- Action cards for task/event creation
- Typing indicator during processing

### Tasks Screen
- View pending and overdue tasks
- Mark tasks complete (with confirmation)
- Delete tasks (with confirmation)
- Add new tasks with due dates

### Calendar Screen
- Daily event view
- Navigate between days
- Create new events

### Briefing Screen
- Daily summary at a glance
- Weather information (mocked)
- Overdue tasks highlight
- Today's events
- Pending emails

## Adding Integrations

The system is designed for easy extension:

### Adding a Real LLM

1. Edit `backend/app/services/llm.py`
2. Implement `LLMService` interface
3. Update `get_llm_service()` factory

### Adding Real Email

1. Edit `backend/app/services/email.py`
2. Implement `_send_email_actual()` method
3. Configure SMTP in `.env`

### Adding Real Calendar (Google Calendar)

1. Create new service in `backend/app/services/`
2. Implement OAuth2 flow
3. Update calendar endpoints to use real API

### Adding Weather API

1. Get API key from weatherapi.com or similar
2. Edit `backend/app/services/briefing.py`
3. Implement `_get_weather()` method

## Security Notes

- Change `API_TOKEN` and `SECRET_KEY` in production
- Use HTTPS in production
- Consider adding rate limiting
- Implement proper OAuth2 for external services

## Architecture Principles

1. **Clean separation** - Services don't know about HTTP
2. **Async everywhere** - Non-blocking I/O
3. **Repository pattern** - Database abstraction
4. **Single responsibility** - Each service does one thing
5. **Type safety** - Pydantic schemas and type hints

## Assistant Personality

Speda is configured with this identity:

- **Name:** Speda
- **Role:** Personal executive assistant
- **Language:** Turkish if user writes Turkish, otherwise English
- **Style:** Clear, structured, efficient, slightly playful but never cheesy
- **Thinking:** Systems architect, critical thinker, mentor

## License

Private project - all rights reserved.

---

**Built for daily use by its creator. Designed for extension, not completeness.**
