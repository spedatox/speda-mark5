"""Realtime notifications via Server-Sent Events."""

from __future__ import annotations

import asyncio
import json
from datetime import datetime

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import verify_api_key
from app.database import get_db
from app.services.task import TaskService


router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/stream")
async def notification_stream(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Stream notification events (overdue and soon-due tasks)."""
    task_service = TaskService(db)

    async def event_generator():
        while True:
            overdue = await task_service.list_overdue_tasks()
            due_soon = await task_service.list_due_soon(hours=6)

            payload = []
            for task in overdue:
                payload.append(
                    {
                        "id": task.id,
                        "title": task.title,
                        "due_date": task.due_date.isoformat() if task.due_date else None,
                        "status": "overdue",
                    }
                )
            for task in due_soon:
                # Avoid duplicates if already in overdue
                if task not in overdue:
                    payload.append(
                        {
                            "id": task.id,
                            "title": task.title,
                            "due_date": task.due_date.isoformat() if task.due_date else None,
                            "status": "due_soon",
                        }
                    )

            if payload:
                yield "data: " + json.dumps(
                    {
                        "type": "reminder",
                        "timestamp": datetime.utcnow().isoformat(),
                        "items": payload,
                    }
                ) + "\n\n"
            else:
                # heartbeat to keep connection alive
                yield "data: {\"type\": \"heartbeat\"}\n\n"

            await asyncio.sleep(30)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
