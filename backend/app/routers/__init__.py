"""API Routers module."""

from app.routers.chat import router as chat_router
from app.routers.tasks import router as tasks_router
from app.routers.calendar import router as calendar_router
from app.routers.email import router as email_router
from app.routers.briefing import router as briefing_router
from app.routers.auth import router as auth_router
from app.routers.integrations import router as integrations_router
from app.routers.settings import router as settings_router
from app.routers.notifications import router as notifications_router

__all__ = [
    "chat_router",
    "tasks_router",
    "calendar_router",
    "email_router",
    "briefing_router",
    "auth_router",
    "integrations_router",
    "settings_router",
    "notifications_router",
]
