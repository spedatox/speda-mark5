"""Google Tasks Service - Fetch and manage Google Tasks."""

import asyncio
from datetime import datetime
from typing import Optional

from googleapiclient.discovery import build

from app.services.google_auth import GoogleAuthService


class GoogleTasksService:
    """Service for interacting with Google Tasks API."""

    def __init__(self):
        self.auth_service = GoogleAuthService()

    def _get_service(self):
        """Get authenticated Tasks API service."""
        credentials = self.auth_service.get_credentials()
        if not credentials:
            raise ValueError("Not authenticated with Google. Please authorize first.")
        return build("tasks", "v1", credentials=credentials)

    def _list_task_lists_sync(self) -> list[dict]:
        """Synchronous version of list_task_lists."""
        service = self._get_service()
        result = service.tasklists().list().execute()
        return result.get("items", [])

    async def list_task_lists(self) -> list[dict]:
        """List all task lists."""
        return await asyncio.to_thread(self._list_task_lists_sync)

    def _get_tasks_sync(
        self,
        task_list_id: str = "@default",
        show_completed: bool = False,
        max_results: int = 100,
    ) -> list[dict]:
        """Synchronous version of get_tasks."""
        service = self._get_service()
        
        result = service.tasks().list(
            tasklist=task_list_id,
            showCompleted=show_completed,
            maxResults=max_results,
        ).execute()
        
        return result.get("items", [])

    async def get_tasks(
        self,
        task_list_id: str = "@default",
        show_completed: bool = False,
        max_results: int = 100,
    ) -> list[dict]:
        """Get tasks from a task list.
        
        Args:
            task_list_id: Task list ID (default: "@default" for the primary list)
            show_completed: Whether to include completed tasks
            max_results: Maximum number of tasks to return
            
        Returns:
            List of task dictionaries
        """
        return await asyncio.to_thread(
            self._get_tasks_sync, task_list_id, show_completed, max_results
        )

    def _create_task_sync(
        self,
        title: str,
        notes: Optional[str] = None,
        due_date: Optional[datetime] = None,
        task_list_id: str = "@default",
    ) -> dict:
        """Synchronous version of create_task."""
        service = self._get_service()
        
        task = {"title": title}
        
        if notes:
            task["notes"] = notes
        if due_date:
            # Google Tasks API expects RFC 3339 format for due date
            task["due"] = due_date.strftime("%Y-%m-%dT00:00:00.000Z")

        created_task = service.tasks().insert(
            tasklist=task_list_id,
            body=task,
        ).execute()
        
        return created_task

    async def create_task(
        self,
        title: str,
        notes: Optional[str] = None,
        due_date: Optional[datetime] = None,
        task_list_id: str = "@default",
    ) -> dict:
        """Create a new task.
        
        Args:
            title: Task title
            notes: Task notes/description (optional)
            due_date: Task due date (optional)
            task_list_id: Task list to add task to
            
        Returns:
            Created task dictionary
        """
        return await asyncio.to_thread(
            self._create_task_sync, title, notes, due_date, task_list_id
        )

    def _complete_task_sync(
        self,
        task_id: str,
        task_list_id: str = "@default",
    ) -> dict:
        """Synchronous version of complete_task."""
        service = self._get_service()
        
        task = service.tasks().get(
            tasklist=task_list_id,
            task=task_id,
        ).execute()
        
        task["status"] = "completed"
        
        updated_task = service.tasks().update(
            tasklist=task_list_id,
            task=task_id,
            body=task,
        ).execute()
        
        return updated_task

    async def complete_task(
        self,
        task_id: str,
        task_list_id: str = "@default",
    ) -> dict:
        """Mark a task as completed."""
        return await asyncio.to_thread(self._complete_task_sync, task_id, task_list_id)

    def _delete_task_sync(
        self,
        task_id: str,
        task_list_id: str = "@default",
    ) -> None:
        """Synchronous version of delete_task."""
        service = self._get_service()
        service.tasks().delete(
            tasklist=task_list_id,
            task=task_id,
        ).execute()

    async def delete_task(
        self,
        task_id: str,
        task_list_id: str = "@default",
    ) -> None:
        """Delete a task."""
        await asyncio.to_thread(self._delete_task_sync, task_id, task_list_id)

    def _update_task_sync(
        self,
        task_id: str,
        title: Optional[str] = None,
        notes: Optional[str] = None,
        due_date: Optional[datetime] = None,
        task_list_id: str = "@default",
    ) -> dict:
        """Synchronous version of update_task."""
        service = self._get_service()
        
        # Get existing task
        task = service.tasks().get(
            tasklist=task_list_id,
            task=task_id,
        ).execute()
        
        # Update fields
        if title:
            task["title"] = title
        if notes:
            task["notes"] = notes
        if due_date:
            task["due"] = due_date.strftime("%Y-%m-%dT00:00:00.000Z")

        updated_task = service.tasks().update(
            tasklist=task_list_id,
            task=task_id,
            body=task,
        ).execute()
        
        return updated_task

    async def update_task(
        self,
        task_id: str,
        title: Optional[str] = None,
        notes: Optional[str] = None,
        due_date: Optional[datetime] = None,
        task_list_id: str = "@default",
    ) -> dict:
        """Update an existing task."""
        return await asyncio.to_thread(
            self._update_task_sync, task_id, title, notes, due_date, task_list_id
        )
