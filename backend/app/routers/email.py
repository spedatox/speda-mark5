"""Email API router."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth import verify_api_key
from app.schemas import (
    EmailDraft,
    EmailResponse,
    EmailStatus,
    Mailbox,
)
from app.services.email import EmailService

router = APIRouter(prefix="/email", tags=["email"])


@router.get("", response_model=list[EmailResponse])
async def list_emails(
    status_filter: Optional[EmailStatus] = Query(None, alias="status", description="Filter by status"),
    mailbox: Optional[Mailbox] = Query(None, description="Filter by mailbox"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List emails with optional filters."""
    email_service = EmailService(db)
    
    from app.models import EmailStatus as DBEmailStatus, Mailbox as DBMailbox
    
    db_status = DBEmailStatus(status_filter.value) if status_filter else None
    db_mailbox = DBMailbox(mailbox.value) if mailbox else None
    
    emails = await email_service.list_emails(status=db_status, mailbox=db_mailbox)
    return [EmailResponse.model_validate(email) for email in emails]


@router.get("/pending", response_model=list[EmailResponse])
async def list_pending_drafts(
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all emails awaiting confirmation."""
    email_service = EmailService(db)
    emails = await email_service.list_pending_drafts()
    return [EmailResponse.model_validate(email) for email in emails]


@router.get("/{email_id}", response_model=EmailResponse)
async def get_email(
    email_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get a specific email by ID."""
    email_service = EmailService(db)
    email = await email_service.get_email(email_id)
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email not found",
        )
    
    return EmailResponse.model_validate(email)


@router.post("/draft", response_model=dict)
async def draft_email(
    email_data: EmailDraft,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Create an email draft.
    
    The email will NOT be sent automatically.
    It requires explicit confirmation via the /send endpoint.
    """
    email_service = EmailService(db)
    email, action = await email_service.draft_email(email_data)
    
    return {
        "email": EmailResponse.model_validate(email),
        "action": action,
    }


@router.put("/{email_id}", response_model=dict)
async def update_draft(
    email_id: int,
    email_data: EmailDraft,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Update an email draft."""
    email_service = EmailService(db)
    email, action = await email_service.update_draft(email_id, email_data)
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email not found",
        )
    
    return {
        "email": EmailResponse.model_validate(email),
        "action": action,
    }


@router.post("/send", response_model=dict)
async def send_email(
    email_id: int = Query(..., description="ID of the email to send"),
    confirmed: bool = Query(False, description="Explicit confirmation to send"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Send an email.
    
    REQUIRES EXPLICIT CONFIRMATION.
    
    This is a non-negotiable rule: emails are NEVER sent without
    the user explicitly confirming by setting confirmed=true.
    
    Flow:
    1. First call with confirmed=false returns a confirmation request
    2. Second call with confirmed=true actually sends the email
    """
    email_service = EmailService(db)
    email, action = await email_service.send_email(email_id, confirmed=confirmed)
    
    result = {
        "action": action,
    }
    
    if email:
        result["email"] = EmailResponse.model_validate(email)
    
    return result


@router.delete("/{email_id}", response_model=dict)
async def delete_email(
    email_id: int,
    confirmed: bool = Query(False, description="Confirm deletion for sent emails"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Delete an email (draft or sent).
    
    Deleting sent emails requires confirmation.
    """
    email_service = EmailService(db)
    success, action = await email_service.delete_draft(email_id, confirmed=confirmed)
    
    return {
        "success": success,
        "action": action,
    }
