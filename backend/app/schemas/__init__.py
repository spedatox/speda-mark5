"""Pydantic schemas for API request/response validation."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


# Enums
class TaskStatus(str, Enum):
    """Task status."""

    PENDING = "pending"
    COMPLETED = "completed"


class EmailStatus(str, Enum):
    """Email status."""

    DRAFT = "draft"
    PENDING_CONFIRMATION = "pending_confirmation"
    SENT = "sent"
    FAILED = "failed"


class Mailbox(str, Enum):
    """Mailbox types."""

    PERSONAL = "personal"
    UNIVERSITY = "university"
    WORK = "work"


class ActionType(str, Enum):
    """Types of actions that can be returned to the frontend."""

    TASK_CREATED = "task_created"
    TASK_UPDATED = "task_updated"
    TASK_COMPLETED = "task_completed"
    TASK_DELETED = "task_deleted"
    EVENT_CREATED = "event_created"
    EVENT_UPDATED = "event_updated"
    EVENT_DELETED = "event_deleted"
    EMAIL_DRAFTED = "email_drafted"
    EMAIL_SENT = "email_sent"
    CONFIRMATION_REQUIRED = "confirmation_required"
    ERROR = "error"


# Base schemas
class BaseSchema(BaseModel):
    """Base schema with common configuration."""

    model_config = ConfigDict(from_attributes=True)


# Task schemas
class TaskCreate(BaseModel):
    """Schema for creating a task."""

    title: str = Field(..., min_length=1, max_length=500)
    notes: Optional[str] = Field(None, max_length=5000)
    due_date: Optional[datetime] = None


class TaskUpdate(BaseModel):
    """Schema for updating a task."""

    title: Optional[str] = Field(None, min_length=1, max_length=500)
    notes: Optional[str] = Field(None, max_length=5000)
    due_date: Optional[datetime] = None
    status: Optional[TaskStatus] = None


class TaskResponse(BaseSchema):
    """Schema for task response."""

    id: int
    title: str
    notes: Optional[str]
    due_date: Optional[datetime]
    status: TaskStatus
    created_at: datetime
    updated_at: datetime


# Calendar schemas
class EventCreate(BaseModel):
    """Schema for creating a calendar event."""

    title: str = Field(..., min_length=1, max_length=500)
    description: Optional[str] = Field(None, max_length=5000)
    start_time: datetime
    end_time: datetime
    location: Optional[str] = Field(None, max_length=500)
    all_day: bool = False


class EventUpdate(BaseModel):
    """Schema for updating a calendar event."""

    title: Optional[str] = Field(None, min_length=1, max_length=500)
    description: Optional[str] = Field(None, max_length=5000)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = Field(None, max_length=500)
    all_day: Optional[bool] = None


class EventResponse(BaseSchema):
    """Schema for calendar event response."""

    id: int
    title: str
    description: Optional[str]
    start_time: datetime
    end_time: datetime
    location: Optional[str]
    all_day: bool
    created_at: datetime
    updated_at: datetime


class EventConflict(BaseModel):
    """Schema for event conflict warning."""

    conflicting_event: EventResponse
    message: str


# Email schemas
class EmailDraft(BaseModel):
    """Schema for drafting an email."""

    mailbox: Mailbox = Mailbox.PERSONAL
    to_address: str = Field(..., min_length=1, max_length=500)
    cc_address: Optional[str] = Field(None, max_length=1000)
    subject: str = Field(..., min_length=1, max_length=500)
    body: str = Field(..., min_length=1)


class EmailSend(BaseModel):
    """Schema for sending an email (requires confirmation)."""

    email_id: int
    confirmed: bool = Field(..., description="User must explicitly confirm sending")


class EmailResponse(BaseSchema):
    """Schema for email response."""

    id: int
    mailbox: Mailbox
    to_address: str
    cc_address: Optional[str]
    subject: str
    body: str
    status: EmailStatus
    confirmation_required: bool
    sent_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime


# Chat schemas
class ChatRequest(BaseModel):
    """Schema for chat request from frontend."""

    message: str = Field(..., min_length=1, max_length=10000)
    timezone: str = Field(default="Europe/Istanbul")
    images: list[str] = Field(default_factory=list, description="List of base64 encoded images")


class Action(BaseModel):
    """Schema for an action returned to the frontend."""

    type: ActionType
    payload: dict[str, Any] = Field(default_factory=dict)
    message: Optional[str] = None


class ChatResponse(BaseModel):
    """Schema for chat response to frontend."""

    reply: str
    actions: list[Action] = Field(default_factory=list)
    conversation_id: int


# Briefing schemas
class BriefingTask(BaseModel):
    """Task summary for briefing."""

    id: int
    title: str
    due_date: Optional[datetime]
    is_overdue: bool = False


class BriefingEvent(BaseModel):
    """Event summary for briefing."""

    id: int
    title: str
    start_time: datetime
    end_time: datetime
    location: Optional[str]


class BriefingEmail(BaseModel):
    """Email summary for briefing."""

    id: int
    subject: str
    status: EmailStatus


class BriefingInboxEmail(BaseModel):
    """Inbox email summary for briefing."""

    id: str
    subject: str
    sender: Optional[str] = None
    snippet: Optional[str] = None
    received_at: Optional[datetime] = None
    is_unread: bool = False
    is_important: bool = False


class WeatherInfo(BaseModel):
    """Weather information for briefing."""

    temperature: float
    condition: str
    high: float
    low: float
    location: str


class BriefingResponse(BaseModel):
    """Schema for daily briefing response."""

    date: datetime
    greeting: str
    tasks_pending: list[BriefingTask]
    tasks_overdue: list[BriefingTask]
    events_today: list[BriefingEvent]
    pending_emails: list[BriefingEmail]
    important_emails: list[BriefingInboxEmail] = Field(default_factory=list)
    weather: Optional[WeatherInfo] = None
    news_summary: Optional[list[str]] = None


# Confirmation schemas
class ConfirmationRequest(BaseModel):
    """Schema for confirmation requests."""

    action_type: str
    action_id: int
    confirmed: bool
    reason: Optional[str] = None


# Memory schemas
class MemoryCreate(BaseModel):
    """Schema for creating a memory."""

    category: str = Field(..., min_length=1, max_length=100)
    key: str = Field(..., min_length=1, max_length=200)
    value: str = Field(..., min_length=1)
    importance: int = Field(default=5, ge=1, le=10)


class MemoryResponse(BaseSchema):
    """Schema for memory response."""

    id: int
    category: str
    key: str
    value: str
    importance: int
    created_at: datetime
    updated_at: datetime
