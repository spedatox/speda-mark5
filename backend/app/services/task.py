"""Task Service - Persistent task and reminder management."""

from datetime import datetime
from typing import Optional

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Task, TaskStatus
from app.schemas import TaskCreate, TaskUpdate, TaskResponse, Action, ActionType


class TaskService:
    """Service for managing tasks and reminders.
    
    IMPORTANT: Tasks are persistent and never auto-complete.
    They remain active until the user explicitly marks them done.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_task(self, task_data: TaskCreate) -> tuple[Task, Action]:
        """Create a new task.
        
        Returns the task and an action for the frontend.
        """
        task = Task(
            title=task_data.title,
            notes=task_data.notes,
            due_date=task_data.due_date,
            status=TaskStatus.PENDING,
        )
        self.db.add(task)
        await self.db.flush()
        await self.db.refresh(task)

        action = Action(
            type=ActionType.TASK_CREATED,
            payload=TaskResponse.model_validate(task).model_dump(mode="json"),
            message=f"Task created: {task.title}",
        )

        return task, action

    async def get_task(self, task_id: int) -> Optional[Task]:
        """Get a task by ID."""
        result = await self.db.execute(
            select(Task).where(Task.id == task_id)
        )
        return result.scalar_one_or_none()

    async def list_tasks(
        self,
        status: Optional[TaskStatus] = None,
        include_completed: bool = False,
    ) -> list[Task]:
        """List all tasks, optionally filtered by status."""
        query = select(Task).order_by(Task.due_date.asc().nulls_last(), Task.created_at.desc())

        if status:
            query = query.where(Task.status == status)
        elif not include_completed:
            query = query.where(Task.status == TaskStatus.PENDING)

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_pending_tasks(self) -> list[Task]:
        """List all pending (not completed) tasks."""
        return await self.list_tasks(status=TaskStatus.PENDING)

    async def list_overdue_tasks(self) -> list[Task]:
        """List all overdue tasks."""
        now = datetime.utcnow()
        result = await self.db.execute(
            select(Task)
            .where(
                Task.status == TaskStatus.PENDING,
                Task.due_date.isnot(None),
                Task.due_date < now,
            )
            .order_by(Task.due_date.asc())
        )
        return list(result.scalars().all())

    async def list_due_soon(self, hours: int = 24) -> list[Task]:
        """List tasks due within the specified hours."""
        from datetime import timedelta

        now = datetime.utcnow()
        deadline = now + timedelta(hours=hours)

        result = await self.db.execute(
            select(Task)
            .where(
                Task.status == TaskStatus.PENDING,
                Task.due_date.isnot(None),
                Task.due_date >= now,
                Task.due_date <= deadline,
            )
            .order_by(Task.due_date.asc())
        )
        return list(result.scalars().all())

    async def update_task(
        self,
        task_id: int,
        task_data: TaskUpdate,
    ) -> tuple[Optional[Task], Optional[Action]]:
        """Update a task.
        
        Returns the updated task and an action for the frontend.
        """
        task = await self.get_task(task_id)
        if not task:
            return None, None

        update_data = task_data.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(task, field, value)

        task.updated_at = datetime.utcnow()
        await self.db.flush()
        await self.db.refresh(task)

        action = Action(
            type=ActionType.TASK_UPDATED,
            payload=TaskResponse.model_validate(task).model_dump(mode="json"),
            message=f"Task updated: {task.title}",
        )

        return task, action

    async def complete_task(
        self,
        task_id: int,
        confirmed: bool = True,
    ) -> tuple[Optional[Task], Optional[Action]]:
        """Mark a task as completed.
        
        Requires explicit confirmation - tasks never auto-complete.
        """
        if not confirmed:
            return None, Action(
                type=ActionType.CONFIRMATION_REQUIRED,
                payload={"task_id": task_id, "action": "complete"},
                message="Please confirm you want to complete this task.",
            )

        task = await self.get_task(task_id)
        if not task:
            return None, None

        task.status = TaskStatus.COMPLETED
        task.updated_at = datetime.utcnow()
        await self.db.flush()
        await self.db.refresh(task)

        action = Action(
            type=ActionType.TASK_COMPLETED,
            payload=TaskResponse.model_validate(task).model_dump(mode="json"),
            message=f"Task completed: {task.title}",
        )

        return task, action

    async def delete_task(
        self,
        task_id: int,
        confirmed: bool = False,
    ) -> tuple[bool, Action]:
        """Delete a task.
        
        REQUIRES CONFIRMATION - Never delete silently.
        """
        task = await self.get_task(task_id)
        if not task:
            return False, Action(
                type=ActionType.ERROR,
                payload={"task_id": task_id},
                message="Task not found.",
            )

        if not confirmed:
            return False, Action(
                type=ActionType.CONFIRMATION_REQUIRED,
                payload={
                    "task_id": task_id,
                    "action": "delete",
                    "title": task.title,
                },
                message=f"Are you sure you want to delete the task '{task.title}'? This cannot be undone.",
            )

        await self.db.delete(task)
        await self.db.flush()

        return True, Action(
            type=ActionType.TASK_DELETED,
            payload={"task_id": task_id},
            message=f"Task deleted: {task.title}",
        )

    async def reopen_task(self, task_id: int) -> tuple[Optional[Task], Optional[Action]]:
        """Reopen a completed task."""
        task = await self.get_task(task_id)
        if not task:
            return None, None

        task.status = TaskStatus.PENDING
        task.updated_at = datetime.utcnow()
        await self.db.flush()
        await self.db.refresh(task)

        action = Action(
            type=ActionType.TASK_UPDATED,
            payload=TaskResponse.model_validate(task).model_dump(mode="json"),
            message=f"Task reopened: {task.title}",
        )

        return task, action
