# Speda Backend

FastAPI backend for Speda Personal Executive Assistant.

## Setup

```bash
pip install -e .
cp .env.example .env
# Edit .env with your configuration
uvicorn app.main:app --reload
```

## API

- `POST /api/chat` - Send message to assistant
- `GET /api/tasks` - List tasks
- `POST /api/tasks` - Create task
- `GET /api/calendar/events` - List events
- `GET /api/briefing/daily` - Get daily briefing
