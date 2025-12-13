"""Calendar Service - Event management with collision awareness."""

from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import CalendarEvent
from app.schemas import EventCreate, EventUpdate, EventResponse, EventConflict, Action, ActionType


class CalendarService:
    """Service for managing calendar events.
    
    Features collision awareness - warns but doesn't block.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_event(
        self,
        event_data: EventCreate,
    ) -> tuple[CalendarEvent, Action, list[EventConflict]]:
        """Create a new calendar event.
        
        Returns the event, an action for the frontend, and any conflicts found.
        """
        # Check for conflicts first
        conflicts = await self._check_conflicts(
            event_data.start_time,
            event_data.end_time,
        )

        event = CalendarEvent(
            title=event_data.title,
            description=event_data.description,
            start_time=event_data.start_time,
            end_time=event_data.end_time,
            location=event_data.location,
            all_day=event_data.all_day,
        )
        self.db.add(event)
        await self.db.flush()
        await self.db.refresh(event)

        # Build action message with conflict warning if applicable
        message = f"Event created: {event.title}"
        if conflicts:
            conflict_titles = [c.conflicting_event.title for c in conflicts]
            message += f" (Warning: overlaps with {', '.join(conflict_titles)})"

        action = Action(
            type=ActionType.EVENT_CREATED,
            payload={
                "event": EventResponse.model_validate(event).model_dump(mode="json"),
                "conflicts": [c.model_dump(mode="json") for c in conflicts],
            },
            message=message,
        )

        return event, action, conflicts

    async def get_event(self, event_id: int) -> Optional[CalendarEvent]:
        """Get an event by ID."""
        result = await self.db.execute(
            select(CalendarEvent).where(CalendarEvent.id == event_id)
        )
        return result.scalar_one_or_none()

    async def list_events(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> list[CalendarEvent]:
        """List events, optionally within a date range."""
        query = select(CalendarEvent).order_by(CalendarEvent.start_time.asc())

        if start_date and end_date:
            query = query.where(
                and_(
                    CalendarEvent.start_time >= start_date,
                    CalendarEvent.start_time <= end_date,
                )
            )
        elif start_date:
            query = query.where(CalendarEvent.start_time >= start_date)
        elif end_date:
            query = query.where(CalendarEvent.start_time <= end_date)

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_events_today(self) -> list[CalendarEvent]:
        """List all events for today."""
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow = today + timedelta(days=1)
        return await self.list_events(start_date=today, end_date=tomorrow)

    async def list_events_week(self) -> list[CalendarEvent]:
        """List all events for the current week."""
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        week_end = today + timedelta(days=7)
        return await self.list_events(start_date=today, end_date=week_end)

    async def update_event(
        self,
        event_id: int,
        event_data: EventUpdate,
    ) -> tuple[Optional[CalendarEvent], Optional[Action], list[EventConflict]]:
        """Update an event.
        
        Returns the updated event, action, and any new conflicts.
        """
        event = await self.get_event(event_id)
        if not event:
            return None, None, []

        update_data = event_data.model_dump(exclude_unset=True)

        # Check for conflicts if times are being updated
        conflicts = []
        new_start = update_data.get("start_time", event.start_time)
        new_end = update_data.get("end_time", event.end_time)

        if "start_time" in update_data or "end_time" in update_data:
            conflicts = await self._check_conflicts(
                new_start, new_end, exclude_id=event_id
            )

        for field, value in update_data.items():
            setattr(event, field, value)

        event.updated_at = datetime.utcnow()
        await self.db.flush()
        await self.db.refresh(event)

        message = f"Event updated: {event.title}"
        if conflicts:
            conflict_titles = [c.conflicting_event.title for c in conflicts]
            message += f" (Warning: overlaps with {', '.join(conflict_titles)})"

        action = Action(
            type=ActionType.EVENT_UPDATED,
            payload={
                "event": EventResponse.model_validate(event).model_dump(mode="json"),
                "conflicts": [c.model_dump(mode="json") for c in conflicts],
            },
            message=message,
        )

        return event, action, conflicts

    async def delete_event(
        self,
        event_id: int,
        confirmed: bool = False,
    ) -> tuple[bool, Action]:
        """Delete an event.
        
        REQUIRES CONFIRMATION - Never delete silently.
        """
        event = await self.get_event(event_id)
        if not event:
            return False, Action(
                type=ActionType.ERROR,
                payload={"event_id": event_id},
                message="Event not found.",
            )

        if not confirmed:
            return False, Action(
                type=ActionType.CONFIRMATION_REQUIRED,
                payload={
                    "event_id": event_id,
                    "action": "delete",
                    "title": event.title,
                    "start_time": event.start_time.isoformat(),
                },
                message=f"Are you sure you want to delete the event '{event.title}'? This cannot be undone.",
            )

        await self.db.delete(event)
        await self.db.flush()

        return True, Action(
            type=ActionType.EVENT_DELETED,
            payload={"event_id": event_id},
            message=f"Event deleted: {event.title}",
        )

    async def _check_conflicts(
        self,
        start_time: datetime,
        end_time: datetime,
        exclude_id: Optional[int] = None,
    ) -> list[EventConflict]:
        """Check for overlapping events.
        
        Two events overlap if:
        - Event A starts before Event B ends AND
        - Event A ends after Event B starts
        """
        query = select(CalendarEvent).where(
            and_(
                CalendarEvent.start_time < end_time,
                CalendarEvent.end_time > start_time,
            )
        )

        if exclude_id:
            query = query.where(CalendarEvent.id != exclude_id)

        result = await self.db.execute(query)
        conflicting_events = result.scalars().all()

        conflicts = []
        for event in conflicting_events:
            conflicts.append(
                EventConflict(
                    conflicting_event=EventResponse.model_validate(event),
                    message=f"Overlaps with '{event.title}' ({event.start_time.strftime('%H:%M')} - {event.end_time.strftime('%H:%M')})",
                )
            )

        return conflicts

    async def get_next_available_slot(
        self,
        duration_minutes: int = 60,
        start_from: Optional[datetime] = None,
    ) -> datetime:
        """Find the next available time slot of specified duration."""
        if not start_from:
            start_from = datetime.utcnow()

        # Round up to next 30-minute mark
        if start_from.minute % 30 != 0:
            start_from = start_from.replace(
                minute=(start_from.minute // 30 + 1) * 30 % 60,
                second=0,
                microsecond=0,
            )
            if start_from.minute == 0:
                start_from = start_from + timedelta(hours=1)

        # Get events from now
        events = await self.list_events(start_date=start_from)

        if not events:
            return start_from

        # Find a gap
        current_time = start_from
        duration = timedelta(minutes=duration_minutes)

        for event in events:
            # If there's enough time before this event
            if event.start_time - current_time >= duration:
                return current_time
            # Move current time to after this event
            if event.end_time > current_time:
                current_time = event.end_time

        # After all events
        return current_time
