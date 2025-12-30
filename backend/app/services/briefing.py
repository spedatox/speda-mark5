"""Briefing Service - Daily summary generator."""

from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.task import TaskService
from app.services.calendar import CalendarService
from app.services.email import EmailService
from app.services.google_calendar import GoogleCalendarService
from app.services.google_tasks import GoogleTasksService
from app.services.google_auth import GoogleAuthService
from app.services.google_gmail import GoogleGmailService
from app.schemas import (
    BriefingResponse,
    BriefingTask,
    BriefingEvent,
    BriefingEmail,
    BriefingInboxEmail,
    WeatherInfo,
)
from app.models import TaskStatus, EmailStatus


class BriefingService:
    """Service for generating daily briefings.
    
    Provides a comprehensive overview of:
    - Pending and overdue tasks from Google Tasks
    - Today's events from Google Calendar
    - Pending emails
    - Weather (if configured)
    - News (mocked for now)
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self.task_service = TaskService(db)
        self.calendar_service = CalendarService(db)
        self.email_service = EmailService(db)
        self.google_auth_service = GoogleAuthService()
        self.google_calendar_service = GoogleCalendarService()
        self.google_tasks_service = GoogleTasksService()
        self.google_gmail_service = GoogleGmailService()

    async def generate_briefing(
        self,
        timezone: str = "Europe/Istanbul",
    ) -> BriefingResponse:
        """Generate the daily briefing."""
        now = datetime.utcnow()

        # Check if Google is authenticated
        is_google_authenticated = self.google_auth_service.is_authenticated()
        print(f"[BRIEFING] Google authenticated: {is_google_authenticated}")

        # Fetch tasks from Google Tasks if authenticated
        google_tasks = []
        if is_google_authenticated:
            try:
                google_tasks = await self.google_tasks_service.get_tasks(show_completed=False)
                print(f"[BRIEFING] Fetched {len(google_tasks)} Google Tasks")
            except Exception as e:
                print(f"[BRIEFING] Could not fetch Google Tasks: {e}")

        # Get local tasks as fallback
        pending_tasks = await self.task_service.list_pending_tasks()
        overdue_tasks = await self.task_service.list_overdue_tasks()
        print(f"[BRIEFING] Local tasks: {len(pending_tasks)} pending, {len(overdue_tasks)} overdue")

        # Fetch today's events from Google Calendar if authenticated
        google_events = []
        if is_google_authenticated:
            try:
                google_events = await self.google_calendar_service.get_today_events()
                print(f"[BRIEFING] Fetched {len(google_events)} Google Calendar events")
            except Exception as e:
                print(f"[BRIEFING] Could not fetch Google Calendar events: {e}")

        # Get local events as fallback
        events_today = await self.calendar_service.list_events_today()
        print(f"[BRIEFING] Local events: {len(events_today)}")

        # Fetch important Gmail messages
        important_gmail_messages = []
        if is_google_authenticated:
            try:
                important_gmail_messages = await self.google_gmail_service.get_important_messages(
                    max_results=5,
                    unread_only=True,
                )
                print(f"[BRIEFING] Fetched {len(important_gmail_messages)} important Gmail messages")
            except Exception as e:
                print(f"[BRIEFING] Could not fetch Gmail messages: {e}")

        # Get pending emails
        pending_emails = await self.email_service.list_pending_drafts()

        # Generate greeting based on time
        greeting = self._generate_greeting(now, timezone)

        # Get weather (mocked for now)
        weather = await self._get_weather()

        # Get news (mocked for now)
        news = await self._get_news()

        # Convert Google Tasks to BriefingTask format
        tasks_from_google = []
        overdue_from_google = []
        for task in google_tasks:
            due_date_str = task.get("due")
            due_date = None
            is_overdue = False
            
            if due_date_str:
                try:
                    due_date = datetime.fromisoformat(due_date_str.replace("Z", "+00:00"))
                    is_overdue = due_date < now
                except:
                    pass
            
            briefing_task = BriefingTask(
                id=hash(task.get("id", "")),  # Use hash since Google IDs are strings
                title=task.get("title", "Untitled Task"),
                due_date=due_date,
                is_overdue=is_overdue,
            )
            
            if is_overdue:
                overdue_from_google.append(briefing_task)
            else:
                tasks_from_google.append(briefing_task)

        # Convert Google Calendar events to BriefingEvent format
        events_from_google = []
        for event in google_events:
            start = event.get("start", {})
            end = event.get("end", {})
            
            start_time = None
            end_time = None
            
            # Handle both dateTime and date formats
            if "dateTime" in start:
                start_time = datetime.fromisoformat(start["dateTime"].replace("Z", "+00:00"))
            elif "date" in start:
                start_time = datetime.fromisoformat(start["date"])
                
            if "dateTime" in end:
                end_time = datetime.fromisoformat(end["dateTime"].replace("Z", "+00:00"))
            elif "date" in end:
                end_time = datetime.fromisoformat(end["date"])
            
            if start_time:  # Only add if we have at least a start time
                events_from_google.append(BriefingEvent(
                    id=hash(event.get("id", "")),
                    title=event.get("summary", "No Title"),
                    start_time=start_time,
                    end_time=end_time,
                    location=event.get("location"),
                ))

        # Combine Google data with local data
        all_pending_tasks = tasks_from_google + [
            BriefingTask(
                id=task.id,
                title=task.title,
                due_date=task.due_date,
                is_overdue=False,
            )
            for task in pending_tasks
            if task not in overdue_tasks
        ]
        
        all_overdue_tasks = overdue_from_google + [
            BriefingTask(
                id=task.id,
                title=task.title,
                due_date=task.due_date,
                is_overdue=True,
            )
            for task in overdue_tasks
        ]
        
        all_events = events_from_google + [
            BriefingEvent(
                id=event.id,
                title=event.title,
                start_time=event.start_time,
                end_time=event.end_time,
                location=event.location,
            )
            for event in events_today
        ]
        
        # Sort events by start time
        all_events.sort(key=lambda e: e.start_time)
        
        print(f"[BRIEFING] Final counts - Events: {len(all_events)}, Pending tasks: {len(all_pending_tasks)}, Overdue tasks: {len(all_overdue_tasks)}")

        return BriefingResponse(
            date=now,
            greeting=greeting,
            tasks_pending=all_pending_tasks,
            tasks_overdue=all_overdue_tasks,
            events_today=all_events,
            pending_emails=[
                BriefingEmail(
                    id=email.id,
                    subject=email.subject,
                    status=EmailStatus(email.status.value),
                )
                for email in pending_emails
            ],
            important_emails=[
                BriefingInboxEmail(
                    id=email.get("id", ""),
                    subject=email.get("subject", "Untitled"),
                    sender=(
                        (email.get("from") or {}).get("name")
                        or (email.get("from") or {}).get("address")
                        or email.get("from")
                    ),
                    snippet=email.get("snippet"),
                    received_at=email.get("received_at"),
                    is_unread=bool(email.get("is_unread")),
                    is_important=bool(email.get("is_important")),
                )
                for email in important_gmail_messages
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

        if briefing.important_emails:
            lines.append(f"Gmail inbox highlights ({len(briefing.important_emails)}):")
            for email in briefing.important_emails:
                sender = email.sender or 'Unknown sender'
                time_str = email.received_at.strftime('%H:%M') if email.received_at else ''
                status = 'unread' if email.is_unread else 'read'
                time_part = f" at {time_str}" if time_str else ''
                lines.append(f"  - {sender}: {email.subject} [{status}{time_part}]")
            lines.append('')

        # Weather
        if briefing.weather:
            w = briefing.weather
            lines.append(f"🌤️ **Weather in {w.location}:** {w.temperature}°C, {w.condition} (H: {w.high}°C, L: {w.low}°C)")
            lines.append("")

        return "\n".join(lines)
