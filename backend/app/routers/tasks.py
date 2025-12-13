"""Tasks API router."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth import verify_api_key
from app.schemas import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    TaskStatus,
    Action,
)
from app.services.task import TaskService

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=list[TaskResponse])
async def list_tasks(
    status: Optional[TaskStatus] = Query(None, description="Filter by status"),
    include_completed: bool = Query(False, description="Include completed tasks"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all tasks, optionally filtered by status."""
    task_service = TaskService(db)
    
    if status:
        tasks = await task_service.list_tasks(status=status)
    else:
        tasks = await task_service.list_tasks(include_completed=include_completed)
    
    return [TaskResponse.model_validate(task) for task in tasks]


@router.get("/pending", response_model=list[TaskResponse])
async def list_pending_tasks(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all pending tasks."""
    task_service = TaskService(db)
    tasks = await task_service.list_pending_tasks()
    return [TaskResponse.model_validate(task) for task in tasks]


@router.get("/overdue", response_model=list[TaskResponse])
async def list_overdue_tasks(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all overdue tasks."""
    task_service = TaskService(db)
    tasks = await task_service.list_overdue_tasks()
    return [TaskResponse.model_validate(task) for task in tasks]


@router.get("/due-soon", response_model=list[TaskResponse])
async def list_tasks_due_soon(
    hours: int = Query(24, description="Hours from now"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List tasks due within specified hours."""
    task_service = TaskService(db)
    tasks = await task_service.list_due_soon(hours=hours)
    return [TaskResponse.model_validate(task) for task in tasks]


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get a specific task by ID."""
    task_service = TaskService(db)
    task = await task_service.get_task(task_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    return TaskResponse.model_validate(task)


@router.post("", response_model=dict)
async def create_task(
    task_data: TaskCreate,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Create a new task."""
    task_service = TaskService(db)
    task, action = await task_service.create_task(task_data)
    
    return {
        "task": TaskResponse.model_validate(task),
        "action": action,
    }


@router.patch("/{task_id}", response_model=dict)
async def update_task(
    task_id: int,
    task_data: TaskUpdate,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Update a task."""
    task_service = TaskService(db)
    task, action = await task_service.update_task(task_id, task_data)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    return {
        "task": TaskResponse.model_validate(task),
        "action": action,
    }


@router.post("/{task_id}/complete", response_model=dict)
async def complete_task(
    task_id: int,
    confirmed: bool = Query(True, description="Confirm completion"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Mark a task as completed.
    
    Tasks never auto-complete - this requires explicit user action.
    """
    task_service = TaskService(db)
    task, action = await task_service.complete_task(task_id, confirmed=confirmed)
    
    if not task and action:
        # Confirmation required
        return {"task": None, "action": action}
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    return {
        "task": TaskResponse.model_validate(task),
        "action": action,
    }


@router.post("/{task_id}/reopen", response_model=dict)
async def reopen_task(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Reopen a completed task."""
    task_service = TaskService(db)
    task, action = await task_service.reopen_task(task_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    return {
        "task": TaskResponse.model_validate(task),
        "action": action,
    }


@router.delete("/{task_id}", response_model=dict)
async def delete_task(
    task_id: int,
    confirmed: bool = Query(False, description="Confirm deletion"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Delete a task.
    
    REQUIRES CONFIRMATION - destructive actions are never silent.
    """
    task_service = TaskService(db)
    success, action = await task_service.delete_task(task_id, confirmed=confirmed)
    
    return {
        "success": success,
        "action": action,
    }
