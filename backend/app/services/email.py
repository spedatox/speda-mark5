"""Email Service - Draft and send emails with mandatory confirmation."""

from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Email, EmailStatus, Mailbox
from app.schemas import EmailDraft, EmailResponse, Action, ActionType


class EmailService:
    """Service for managing emails.
    
    CRITICAL: Emails are NEVER sent without explicit user confirmation.
    The flow is: Draft -> Show -> Confirm -> Send
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def draft_email(self, email_data: EmailDraft) -> tuple[Email, Action]:
        """Create an email draft.
        
        The email will have status DRAFT and requires confirmation before sending.
        """
        email = Email(
            mailbox=Mailbox(email_data.mailbox.value),
            to_address=email_data.to_address,
            cc_address=email_data.cc_address,
            subject=email_data.subject,
            body=email_data.body,
            status=EmailStatus.DRAFT,
            confirmation_required=True,  # Always true
        )
        self.db.add(email)
        await self.db.flush()
        await self.db.refresh(email)

        action = Action(
            type=ActionType.EMAIL_DRAFTED,
            payload=EmailResponse.model_validate(email).model_dump(mode="json"),
            message=f"Email drafted to {email.to_address}. Please review and confirm to send.",
        )

        return email, action

    async def get_email(self, email_id: int) -> Optional[Email]:
        """Get an email by ID."""
        result = await self.db.execute(
            select(Email).where(Email.id == email_id)
        )
        return result.scalar_one_or_none()

    async def list_emails(
        self,
        status: Optional[EmailStatus] = None,
        mailbox: Optional[Mailbox] = None,
    ) -> list[Email]:
        """List emails with optional filters."""
        query = select(Email).order_by(Email.created_at.desc())

        if status:
            query = query.where(Email.status == status)
        if mailbox:
            query = query.where(Email.mailbox == mailbox)

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_pending_drafts(self) -> list[Email]:
        """List all emails awaiting confirmation."""
        result = await self.db.execute(
            select(Email)
            .where(Email.status.in_([EmailStatus.DRAFT, EmailStatus.PENDING_CONFIRMATION]))
            .order_by(Email.created_at.desc())
        )
        return list(result.scalars().all())

    async def send_email(
        self,
        email_id: int,
        confirmed: bool = False,
    ) -> tuple[Optional[Email], Action]:
        """Send an email.
        
        REQUIRES EXPLICIT CONFIRMATION - This is a non-negotiable rule.
        """
        email = await self.get_email(email_id)
        if not email:
            return None, Action(
                type=ActionType.ERROR,
                payload={"email_id": email_id},
                message="Email not found.",
            )

        if email.status == EmailStatus.SENT:
            return email, Action(
                type=ActionType.ERROR,
                payload=EmailResponse.model_validate(email).model_dump(mode="json"),
                message="This email has already been sent.",
            )

        # CRITICAL: Must have explicit confirmation
        if not confirmed:
            email.status = EmailStatus.PENDING_CONFIRMATION
            await self.db.flush()
            await self.db.refresh(email)

            return email, Action(
                type=ActionType.CONFIRMATION_REQUIRED,
                payload={
                    "email_id": email_id,
                    "action": "send_email",
                    "to": email.to_address,
                    "subject": email.subject,
                    "preview": email.body[:200] + "..." if len(email.body) > 200 else email.body,
                },
                message=f"Please confirm you want to send this email to {email.to_address} with subject '{email.subject}'.",
            )

        # Actually send the email
        success = await self._send_email_actual(email)

        if success:
            email.status = EmailStatus.SENT
            email.sent_at = datetime.utcnow()
            email.confirmation_required = False
            await self.db.flush()
            await self.db.refresh(email)

            return email, Action(
                type=ActionType.EMAIL_SENT,
                payload=EmailResponse.model_validate(email).model_dump(mode="json"),
                message=f"Email sent successfully to {email.to_address}.",
            )
        else:
            email.status = EmailStatus.FAILED
            await self.db.flush()
            await self.db.refresh(email)

            return email, Action(
                type=ActionType.ERROR,
                payload=EmailResponse.model_validate(email).model_dump(mode="json"),
                message="Failed to send email. Please try again.",
            )

    async def update_draft(
        self,
        email_id: int,
        email_data: EmailDraft,
    ) -> tuple[Optional[Email], Optional[Action]]:
        """Update an email draft."""
        email = await self.get_email(email_id)
        if not email:
            return None, None

        if email.status == EmailStatus.SENT:
            return email, Action(
                type=ActionType.ERROR,
                payload={"email_id": email_id},
                message="Cannot modify a sent email.",
            )

        email.mailbox = Mailbox(email_data.mailbox.value)
        email.to_address = email_data.to_address
        email.cc_address = email_data.cc_address
        email.subject = email_data.subject
        email.body = email_data.body
        email.status = EmailStatus.DRAFT  # Reset to draft
        email.updated_at = datetime.utcnow()

        await self.db.flush()
        await self.db.refresh(email)

        action = Action(
            type=ActionType.EMAIL_DRAFTED,
            payload=EmailResponse.model_validate(email).model_dump(mode="json"),
            message="Email draft updated. Please review and confirm to send.",
        )

        return email, action

    async def delete_draft(
        self,
        email_id: int,
        confirmed: bool = False,
    ) -> tuple[bool, Action]:
        """Delete an email draft.
        
        Requires confirmation for sent emails.
        """
        email = await self.get_email(email_id)
        if not email:
            return False, Action(
                type=ActionType.ERROR,
                payload={"email_id": email_id},
                message="Email not found.",
            )

        # Require confirmation for sent emails
        if email.status == EmailStatus.SENT and not confirmed:
            return False, Action(
                type=ActionType.CONFIRMATION_REQUIRED,
                payload={
                    "email_id": email_id,
                    "action": "delete_email",
                },
                message="Are you sure you want to delete this sent email from records?",
            )

        await self.db.delete(email)
        await self.db.flush()

        return True, Action(
            type=ActionType.TASK_DELETED,  # Reusing for simplicity
            payload={"email_id": email_id},
            message="Email deleted.",
        )

    async def _send_email_actual(self, email: Email) -> bool:
        """Actually send the email via SMTP or API.
        
        This is a mock implementation. Replace with real email sending logic.
        """
        # TODO: Implement actual email sending
        # Options:
        # 1. SMTP with smtplib/aiosmtplib
        # 2. Gmail API
        # 3. SendGrid/Mailgun/etc.

        from app.config import get_settings
        settings = get_settings()

        if not settings.email_smtp_host:
            # Mock mode - pretend it worked
            print(f"[MOCK] Sending email to {email.to_address}: {email.subject}")
            return True

        # Real implementation would go here
        # try:
        #     async with aiosmtplib.SMTP(hostname=settings.email_smtp_host, port=settings.email_smtp_port) as smtp:
        #         await smtp.login(settings.email_username, settings.email_password)
        #         message = EmailMessage()
        #         message["From"] = settings.email_username
        #         message["To"] = email.to_address
        #         message["Subject"] = email.subject
        #         message.set_content(email.body)
        #         await smtp.send_message(message)
        #     return True
        # except Exception as e:
        #     print(f"Email send error: {e}")
        #     return False

        return True
