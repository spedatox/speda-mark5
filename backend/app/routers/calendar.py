"""Calendar API router."""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth import verify_api_key
from app.schemas import (
    EventCreate,
    EventUpdate,
    EventResponse,
    EventConflict,
)
from app.services.calendar import CalendarService

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("", response_model=list[EventResponse])
async def list_events(
    start_date: Optional[datetime] = Query(None, description="Filter events starting from this date"),
    end_date: Optional[datetime] = Query(None, description="Filter events until this date"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List calendar events, optionally within a date range."""
    calendar_service = CalendarService(db)
    events = await calendar_service.list_events(start_date=start_date, end_date=end_date)
    return [EventResponse.model_validate(event) for event in events]


@router.get("/today", response_model=list[EventResponse])
async def list_events_today(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all events for today."""
    calendar_service = CalendarService(db)
    events = await calendar_service.list_events_today()
    return [EventResponse.model_validate(event) for event in events]


@router.get("/week", response_model=list[EventResponse])
async def list_events_week(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all events for the current week."""
    calendar_service = CalendarService(db)
    events = await calendar_service.list_events_week()
    return [EventResponse.model_validate(event) for event in events]


@router.get("/next-slot")
async def get_next_available_slot(
    duration_minutes: int = Query(60, description="Duration needed in minutes"),
    start_from: Optional[datetime] = Query(None, description="Start searching from this time"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Find the next available time slot."""
    calendar_service = CalendarService(db)
    next_slot = await calendar_service.get_next_available_slot(
        duration_minutes=duration_minutes,
        start_from=start_from,
    )
    return {"next_available_slot": next_slot}


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get a specific event by ID."""
    calendar_service = CalendarService(db)
    event = await calendar_service.get_event(event_id)
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )
    
    return EventResponse.model_validate(event)


@router.post("", response_model=dict)
async def create_event(
    event_data: EventCreate,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Create a new calendar event.
    
    Will warn about conflicts but won't block creation.
    """
    calendar_service = CalendarService(db)
    event, action, conflicts = await calendar_service.create_event(event_data)
    
    return {
        "event": EventResponse.model_validate(event),
        "action": action,
        "conflicts": [c.model_dump() for c in conflicts],
    }


@router.patch("/{event_id}", response_model=dict)
async def update_event(
    event_id: int,
    event_data: EventUpdate,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Update an event."""
    calendar_service = CalendarService(db)
    event, action, conflicts = await calendar_service.update_event(event_id, event_data)
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )
    
    return {
        "event": EventResponse.model_validate(event),
        "action": action,
        "conflicts": [c.model_dump() for c in conflicts],
    }


@router.delete("/{event_id}", response_model=dict)
async def delete_event(
    event_id: int,
    confirmed: bool = Query(False, description="Confirm deletion"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Delete an event.
    
    REQUIRES CONFIRMATION - destructive actions are never silent.
    """
    calendar_service = CalendarService(db)
    success, action = await calendar_service.delete_event(event_id, confirmed=confirmed)
    
    return {
        "success": success,
        "action": action,
    }
