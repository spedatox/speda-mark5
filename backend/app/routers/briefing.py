"""Briefing API router."""

from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth import verify_api_key
from app.schemas import BriefingResponse
from app.services.briefing import BriefingService

router = APIRouter(prefix="/briefing", tags=["briefing"])


@router.get("/today", response_model=BriefingResponse)
async def get_today_briefing(
    timezone: str = Query("Europe/Istanbul", description="User timezone"),
    latitude: Optional[float] = Query(None, description="User's GPS latitude for weather"),
    longitude: Optional[float] = Query(None, description="User's GPS longitude for weather"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get the daily briefing for today.
    
    Returns a structured overview of:
    - Pending and overdue tasks
    - Today's events
    - Pending email drafts
    - Weather (based on user's location if provided)
    - News highlights
    """
    briefing_service = BriefingService(db)
    return await briefing_service.generate_briefing(
        timezone=timezone,
        latitude=latitude,
        longitude=longitude,
    )


@router.get("/today/text")
async def get_today_briefing_text(
    timezone: str = Query("Europe/Istanbul", description="User timezone"),
    latitude: Optional[float] = Query(None, description="User's GPS latitude for weather"),
    longitude: Optional[float] = Query(None, description="User's GPS longitude for weather"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get the daily briefing as formatted text.
    
    This is useful for displaying in chat or sending as a notification.
    """
    briefing_service = BriefingService(db)
    text = await briefing_service.generate_text_briefing(
        timezone=timezone,
        latitude=latitude,
        longitude=longitude,
    )
    return {"briefing": text}
