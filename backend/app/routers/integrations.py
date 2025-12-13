"""Integrations Router - External service endpoints for calendar, mail, weather, news."""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.services.google_calendar import GoogleCalendarService
from app.services.google_tasks import GoogleTasksService
from app.services.imap_mail import ImapMailService
from app.services.weather import WeatherService
from app.services.news import NewsService


router = APIRouter(prefix="/api/integrations", tags=["Integrations"])


# ==================== Google Calendar ====================

@router.get("/calendar/list")
async def list_calendars():
    """List all Google calendars."""
    try:
        service = GoogleCalendarService()
        calendars = await service.list_calendars()
        return {"calendars": calendars}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.get("/calendar/events")
async def get_calendar_events(
    calendar_id: str = "primary",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    max_results: int = 50,
):
    """Get events from Google Calendar."""
    try:
        service = GoogleCalendarService()
        
        start = datetime.fromisoformat(start_date) if start_date else None
        end = datetime.fromisoformat(end_date) if end_date else None
        
        events = await service.get_events(calendar_id, start, end, max_results)
        return {"events": events}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.get("/calendar/today")
async def get_today_events(calendar_id: str = "primary"):
    """Get today's events from Google Calendar."""
    try:
        service = GoogleCalendarService()
        events = await service.get_today_events(calendar_id)
        return {"events": events}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/calendar/events")
async def create_calendar_event(
    summary: str,
    start_time: str,
    end_time: str,
    description: Optional[str] = None,
    location: Optional[str] = None,
    calendar_id: str = "primary",
):
    """Create a new Google Calendar event."""
    try:
        service = GoogleCalendarService()
        event = await service.create_event(
            summary=summary,
            start_time=datetime.fromisoformat(start_time),
            end_time=datetime.fromisoformat(end_time),
            description=description,
            location=location,
            calendar_id=calendar_id,
        )
        return {"event": event}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# ==================== Google Tasks ====================

@router.get("/tasks/lists")
async def list_task_lists():
    """List all Google Tasks lists."""
    try:
        service = GoogleTasksService()
        lists = await service.list_task_lists()
        return {"task_lists": lists}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.get("/tasks")
async def get_tasks(
    task_list_id: str = "@default",
    show_completed: bool = False,
    max_results: int = 100,
):
    """Get tasks from Google Tasks."""
    try:
        service = GoogleTasksService()
        tasks = await service.get_tasks(task_list_id, show_completed, max_results)
        return {"tasks": tasks or []}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/tasks")
async def create_task(
    title: str,
    notes: Optional[str] = None,
    due_date: Optional[str] = None,
    task_list_id: str = "@default",
):
    """Create a new Google Task."""
    try:
        service = GoogleTasksService()
        task = await service.create_task(
            title=title,
            notes=notes,
            due_date=datetime.fromisoformat(due_date) if due_date else None,
            task_list_id=task_list_id,
        )
        return {"task": task}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/tasks/{task_id}/complete")
async def complete_task(
    task_id: str,
    task_list_id: str = "@default",
):
    """Complete a Google Task."""
    try:
        service = GoogleTasksService()
        task = await service.complete_task(task_id, task_list_id)
        return {"task": task}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# ==================== Email (IMAP/SMTP) ====================

@router.get("/mail/status")
async def get_mail_status():
    """Check if mail is configured."""
    service = ImapMailService()
    return {"configured": service.is_configured()}


@router.get("/mail/folders")
async def get_mail_folders():
    """Get available mail folders."""
    try:
        service = ImapMailService()
        folders = await service.list_folders()
        return {"folders": folders}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/mail/messages")
async def get_mail_messages(
    folder: str = "INBOX",
    limit: int = 25,
    unread_only: bool = False,
):
    """Get email messages via IMAP."""
    try:
        service = ImapMailService()
        messages = await service.list_messages(folder, limit, unread_only)
        return {"messages": messages}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/mail/messages/{message_id}")
async def get_mail_message(message_id: str, folder: str = "INBOX"):
    """Get a specific email message."""
    try:
        service = ImapMailService()
        message = await service.get_message(message_id, folder)
        return {"message": message}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/mail/send")
async def send_mail(
    to: list[str],
    subject: str,
    body: str,
    cc: Optional[list[str]] = None,
    is_html: bool = False,
):
    """Send an email via SMTP."""
    try:
        service = ImapMailService()
        await service.send_message(to, subject, body, cc, is_html)
        return {"status": "success", "message": "Email sent"}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/mail/unread-count")
async def get_unread_count(folder: str = "INBOX"):
    """Get unread email count."""
    try:
        service = ImapMailService()
        count = await service.get_unread_count(folder)
        return {"unread_count": count}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== Weather ====================

@router.get("/weather/current")
async def get_current_weather(
    city: Optional[str] = None,
    units: str = "metric",
):
    """Get current weather."""
    service = WeatherService()
    weather = await service.get_current_weather(city, units)
    
    if weather is None:
        raise HTTPException(status_code=503, detail="Weather service unavailable or not configured")
    
    return weather


@router.get("/weather/forecast")
async def get_weather_forecast(
    city: Optional[str] = None,
    units: str = "metric",
    days: int = 5,
):
    """Get weather forecast."""
    service = WeatherService()
    forecast = await service.get_forecast(city, units, days)
    
    if forecast is None:
        raise HTTPException(status_code=503, detail="Weather service unavailable or not configured")
    
    return {"forecast": forecast}


# ==================== News ====================

@router.get("/news/headlines")
async def get_news_headlines(
    country: Optional[str] = None,
    category: Optional[str] = None,
    query: Optional[str] = None,
    page_size: int = 10,
):
    """Get top news headlines."""
    service = NewsService()
    headlines = await service.get_top_headlines(country, category, query, page_size)
    
    if headlines is None:
        raise HTTPException(status_code=503, detail="News service unavailable or not configured")
    
    return {"articles": headlines}


@router.get("/news/search")
async def search_news(
    query: str,
    language: str = "en",
    sort_by: str = "publishedAt",
    page_size: int = 10,
):
    """Search news articles."""
    service = NewsService()
    articles = await service.search_news(query, language, sort_by, page_size)
    
    if articles is None:
        raise HTTPException(status_code=503, detail="News service unavailable or not configured")
    
    return {"articles": articles}
