"""Google Calendar Service - Fetch and manage Google Calendar events."""

import asyncio
from datetime import datetime, timedelta
from typing import Optional

from googleapiclient.discovery import build

from app.services.google_auth import GoogleAuthService


class GoogleCalendarService:
    """Service for interacting with Google Calendar API."""

    def __init__(self):
        self.auth_service = GoogleAuthService()

    def _get_service(self):
        """Get authenticated Calendar API service."""
        credentials = self.auth_service.get_credentials()
        if not credentials:
            raise ValueError("Not authenticated with Google. Please authorize first.")
        return build("calendar", "v3", credentials=credentials)

    def _list_calendars_sync(self) -> list[dict]:
        """Synchronous version of list_calendars."""
        service = self._get_service()
        calendar_list = service.calendarList().list().execute()
        return calendar_list.get("items", [])

    async def list_calendars(self) -> list[dict]:
        """List all calendars the user has access to."""
        return await asyncio.to_thread(self._list_calendars_sync)

    def _get_events_sync(
        self,
        calendar_id: str = "primary",
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        max_results: int = 50,
    ) -> list[dict]:
        """Synchronous version of get_events."""
        service = self._get_service()
        
        if start_date is None:
            start_date = datetime.utcnow()
        if end_date is None:
            end_date = start_date + timedelta(days=7)

        events_result = service.events().list(
            calendarId=calendar_id,
            timeMin=start_date.isoformat() + "Z",
            timeMax=end_date.isoformat() + "Z",
            maxResults=max_results,
            singleEvents=True,
            orderBy="startTime",
        ).execute()
        
        return events_result.get("items", [])

    async def get_events(
        self,
        calendar_id: str = "primary",
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        max_results: int = 50,
    ) -> list[dict]:
        """Get events from a calendar.
        
        Args:
            calendar_id: Calendar ID (default: "primary" for the user's main calendar)
            start_date: Start of time range (default: now)
            end_date: End of time range (default: 7 days from now)
            max_results: Maximum number of events to return
            
        Returns:
            List of event dictionaries
        """
        return await asyncio.to_thread(
            self._get_events_sync, calendar_id, start_date, end_date, max_results
        )

    async def get_today_events(self, calendar_id: str = "primary") -> list[dict]:
        """Get all events for today."""
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow = today + timedelta(days=1)
        return await self.get_events(calendar_id, today, tomorrow)

    def _create_event_sync(
        self,
        summary: str,
        start_time: datetime,
        end_time: datetime,
        description: Optional[str] = None,
        location: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Synchronous version of create_event."""
        service = self._get_service()
        
        event = {
            "summary": summary,
            "start": {
                "dateTime": start_time.isoformat(),
                "timeZone": "Europe/Istanbul",
            },
            "end": {
                "dateTime": end_time.isoformat(),
                "timeZone": "Europe/Istanbul",
            },
        }
        
        if description:
            event["description"] = description
        if location:
            event["location"] = location

        created_event = service.events().insert(
            calendarId=calendar_id,
            body=event,
        ).execute()
        
        return created_event

    async def create_event(
        self,
        summary: str,
        start_time: datetime,
        end_time: datetime,
        description: Optional[str] = None,
        location: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Create a new calendar event.
        
        Args:
            summary: Event title
            start_time: Event start time
            end_time: Event end time
            description: Event description (optional)
            location: Event location (optional)
            calendar_id: Calendar to add event to
            
        Returns:
            Created event dictionary
        """
        return await asyncio.to_thread(
            self._create_event_sync, summary, start_time, end_time, description, location, calendar_id
        )

    def _delete_event_sync(
        self,
        event_id: str,
        calendar_id: str = "primary",
    ) -> None:
        """Synchronous version of delete_event."""
        service = self._get_service()
        service.events().delete(
            calendarId=calendar_id,
            eventId=event_id,
        ).execute()

    async def delete_event(
        self,
        event_id: str,
        calendar_id: str = "primary",
    ) -> None:
        """Delete a calendar event."""
        await asyncio.to_thread(self._delete_event_sync, event_id, calendar_id)

    def _update_event_sync(
        self,
        event_id: str,
        summary: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        description: Optional[str] = None,
        location: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Synchronous version of update_event."""
        service = self._get_service()
        
        # Get existing event
        event = service.events().get(
            calendarId=calendar_id,
            eventId=event_id,
        ).execute()
        
        # Update fields
        if summary:
            event["summary"] = summary
        if start_time:
            event["start"] = {
                "dateTime": start_time.isoformat(),
                "timeZone": "Europe/Istanbul",
            }
        if end_time:
            event["end"] = {
                "dateTime": end_time.isoformat(),
                "timeZone": "Europe/Istanbul",
            }
        if description:
            event["description"] = description
        if location:
            event["location"] = location

        updated_event = service.events().update(
            calendarId=calendar_id,
            eventId=event_id,
            body=event,
        ).execute()
        
        return updated_event

    async def update_event(
        self,
        event_id: str,
        summary: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        description: Optional[str] = None,
        location: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Update an existing calendar event."""
        return await asyncio.to_thread(
            self._update_event_sync, event_id, summary, start_time, end_time, description, location, calendar_id
        )
