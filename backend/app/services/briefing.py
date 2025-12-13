"""Briefing Service - Daily summary generator."""

from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.task import TaskService
from app.services.calendar import CalendarService
from app.services.email import EmailService
from app.schemas import (
    BriefingResponse,
    BriefingTask,
    BriefingEvent,
    BriefingEmail,
    WeatherInfo,
)
from app.models import TaskStatus, EmailStatus


class BriefingService:
    """Service for generating daily briefings.
    
    Provides a comprehensive overview of:
    - Pending and overdue tasks
    - Today's events
    - Pending emails
    - Weather (if configured)
    - News (mocked for now)
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self.task_service = TaskService(db)
        self.calendar_service = CalendarService(db)
        self.email_service = EmailService(db)

    async def generate_briefing(
        self,
        timezone: str = "Europe/Istanbul",
    ) -> BriefingResponse:
        """Generate the daily briefing."""
        now = datetime.utcnow()

        # Get tasks
        pending_tasks = await self.task_service.list_pending_tasks()
        overdue_tasks = await self.task_service.list_overdue_tasks()

        # Get today's events
        events_today = await self.calendar_service.list_events_today()

        # Get pending emails
        pending_emails = await self.email_service.list_pending_drafts()

        # Generate greeting based on time
        greeting = self._generate_greeting(now, timezone)

        # Get weather (mocked for now)
        weather = await self._get_weather()

        # Get news (mocked for now)
        news = await self._get_news()

        return BriefingResponse(
            date=now,
            greeting=greeting,
            tasks_pending=[
                BriefingTask(
                    id=task.id,
                    title=task.title,
                    due_date=task.due_date,
                    is_overdue=False,
                )
                for task in pending_tasks
                if task not in overdue_tasks
            ],
            tasks_overdue=[
                BriefingTask(
                    id=task.id,
                    title=task.title,
                    due_date=task.due_date,
                    is_overdue=True,
                )
                for task in overdue_tasks
            ],
            events_today=[
                BriefingEvent(
                    id=event.id,
                    title=event.title,
                    start_time=event.start_time,
                    end_time=event.end_time,
                    location=event.location,
                )
                for event in events_today
            ],
            pending_emails=[
                BriefingEmail(
                    id=email.id,
                    subject=email.subject,
                    status=EmailStatus(email.status.value),
                )
                for email in pending_emails
            ],
            weather=weather,
            news_summary=news,
        )

    def _generate_greeting(self, now: datetime, timezone: str) -> str:
        """Generate a time-appropriate greeting."""
        # Simple hour-based greeting (ignoring timezone for now)
        hour = now.hour

        if hour < 6:
            time_greeting = "Good night"
            turkish_greeting = "İyi geceler"
        elif hour < 12:
            time_greeting = "Good morning"
            turkish_greeting = "Günaydın"
        elif hour < 17:
            time_greeting = "Good afternoon"
            turkish_greeting = "İyi öğlenler"
        elif hour < 21:
            time_greeting = "Good evening"
            turkish_greeting = "İyi akşamlar"
        else:
            time_greeting = "Good evening"
            turkish_greeting = "İyi akşamlar"

        # Check if Turkish timezone
        if "Istanbul" in timezone or "Turkey" in timezone:
            return f"{turkish_greeting}! İşte bugünkü özetin."

        return f"{time_greeting}! Here's your briefing for today."

    async def _get_weather(self) -> Optional[WeatherInfo]:
        """Get weather information.
        
        This is a mock implementation. Replace with real weather API.
        """
        from app.config import get_settings
        settings = get_settings()

        if not settings.weather_api_key:
            # Return mock weather
            return WeatherInfo(
                temperature=18.0,
                condition="Partly Cloudy",
                high=22.0,
                low=14.0,
                location="Istanbul",
            )

        # Real implementation would go here
        # import httpx
        # async with httpx.AsyncClient() as client:
        #     response = await client.get(
        #         f"https://api.weatherapi.com/v1/current.json",
        #         params={"key": settings.weather_api_key, "q": "Istanbul"}
        #     )
        #     data = response.json()
        #     ...

        return None

    async def _get_news(self) -> Optional[list[str]]:
        """Get news headlines.
        
        This is a mock implementation. Replace with real news API.
        """
        # Mock news headlines
        return [
            "Technology sector shows strong growth",
            "New developments in AI research",
            "Local events scheduled for the weekend",
        ]

    async def generate_text_briefing(
        self,
        timezone: str = "Europe/Istanbul",
    ) -> str:
        """Generate a text-formatted briefing for chat responses."""
        briefing = await self.generate_briefing(timezone)

        lines = [briefing.greeting, ""]

        # Overdue tasks (highlight these)
        if briefing.tasks_overdue:
            lines.append("⚠️ **Overdue Tasks:**")
            for task in briefing.tasks_overdue:
                due = task.due_date.strftime("%b %d") if task.due_date else "no date"
                lines.append(f"  • {task.title} (due: {due})")
            lines.append("")

        # Today's events
        if briefing.events_today:
            lines.append("📅 **Today's Events:**")
            for event in briefing.events_today:
                time_str = event.start_time.strftime("%H:%M")
                location = f" @ {event.location}" if event.location else ""
                lines.append(f"  • {time_str} - {event.title}{location}")
            lines.append("")
        else:
            lines.append("📅 No events scheduled for today.")
            lines.append("")

        # Pending tasks
        if briefing.tasks_pending:
            lines.append(f"📋 **Pending Tasks:** ({len(briefing.tasks_pending)})")
            for task in briefing.tasks_pending[:5]:  # Show top 5
                due = f" (due: {task.due_date.strftime('%b %d')})" if task.due_date else ""
                lines.append(f"  • {task.title}{due}")
            if len(briefing.tasks_pending) > 5:
                lines.append(f"  ... and {len(briefing.tasks_pending) - 5} more")
            lines.append("")

        # Pending emails
        if briefing.pending_emails:
            lines.append(f"✉️ **Pending Email Drafts:** ({len(briefing.pending_emails)})")
            for email in briefing.pending_emails:
                lines.append(f"  • {email.subject}")
            lines.append("")

        # Weather
        if briefing.weather:
            w = briefing.weather
            lines.append(f"🌤️ **Weather in {w.location}:** {w.temperature}°C, {w.condition} (H: {w.high}°C, L: {w.low}°C)")
            lines.append("")

        return "\n".join(lines)
