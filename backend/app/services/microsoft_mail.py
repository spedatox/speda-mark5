"""Microsoft 365 Mail Service - Fetch and send emails via Microsoft Graph API."""

from datetime import datetime
from typing import Optional

import httpx

from app.services.microsoft_auth import MicrosoftAuthService


class MicrosoftMailService:
    """Service for interacting with Microsoft Graph Mail API."""

    GRAPH_BASE = "https://graph.microsoft.com/v1.0"

    def __init__(self):
        self.auth_service = MicrosoftAuthService()

    def _get_headers(self) -> dict:
        """Get authorization headers."""
        token = self.auth_service.get_access_token()
        if not token:
            raise ValueError("Not authenticated with Microsoft. Please authorize first.")
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    async def list_messages(
        self,
        folder: str = "inbox",
        top: int = 25,
        filter_unread: bool = False,
    ) -> list[dict]:
        """List messages from a mail folder.
        
        Args:
            folder: Mail folder (inbox, sentitems, drafts, etc.)
            top: Number of messages to return
            filter_unread: Only return unread messages
            
        Returns:
            List of message dictionaries
        """
        url = f"{self.GRAPH_BASE}/me/mailFolders/{folder}/messages"
        params = {
            "$top": top,
            "$orderby": "receivedDateTime desc",
            "$select": "id,subject,from,receivedDateTime,isRead,bodyPreview,hasAttachments",
        }
        
        if filter_unread:
            params["$filter"] = "isRead eq false"

        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers=self._get_headers(),
                params=params,
            )
            response.raise_for_status()
            data = response.json()
            
        return data.get("value", [])

    async def get_message(self, message_id: str) -> dict:
        """Get a specific message with full body."""
        url = f"{self.GRAPH_BASE}/me/messages/{message_id}"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers=self._get_headers(),
            )
            response.raise_for_status()
            
        return response.json()

    async def send_message(
        self,
        to: list[str],
        subject: str,
        body: str,
        cc: Optional[list[str]] = None,
        is_html: bool = False,
    ) -> None:
        """Send an email message.
        
        Args:
            to: List of recipient email addresses
            subject: Email subject
            body: Email body
            cc: List of CC recipients (optional)
            is_html: Whether body is HTML (default: plain text)
        """
        url = f"{self.GRAPH_BASE}/me/sendMail"
        
        message = {
            "message": {
                "subject": subject,
                "body": {
                    "contentType": "HTML" if is_html else "Text",
                    "content": body,
                },
                "toRecipients": [
                    {"emailAddress": {"address": addr}} for addr in to
                ],
            }
        }
        
        if cc:
            message["message"]["ccRecipients"] = [
                {"emailAddress": {"address": addr}} for addr in cc
            ]

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                headers=self._get_headers(),
                json=message,
            )
            response.raise_for_status()

    async def create_draft(
        self,
        to: list[str],
        subject: str,
        body: str,
        cc: Optional[list[str]] = None,
        is_html: bool = False,
    ) -> dict:
        """Create a draft email.
        
        Returns:
            Created draft message dictionary
        """
        url = f"{self.GRAPH_BASE}/me/messages"
        
        message = {
            "subject": subject,
            "body": {
                "contentType": "HTML" if is_html else "Text",
                "content": body,
            },
            "toRecipients": [
                {"emailAddress": {"address": addr}} for addr in to
            ],
        }
        
        if cc:
            message["ccRecipients"] = [
                {"emailAddress": {"address": addr}} for addr in cc
            ]

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                headers=self._get_headers(),
                json=message,
            )
            response.raise_for_status()
            
        return response.json()

    async def send_draft(self, message_id: str) -> None:
        """Send a draft message."""
        url = f"{self.GRAPH_BASE}/me/messages/{message_id}/send"
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                headers=self._get_headers(),
            )
            response.raise_for_status()

    async def mark_as_read(self, message_id: str) -> None:
        """Mark a message as read."""
        url = f"{self.GRAPH_BASE}/me/messages/{message_id}"
        
        async with httpx.AsyncClient() as client:
            response = await client.patch(
                url,
                headers=self._get_headers(),
                json={"isRead": True},
            )
            response.raise_for_status()

    async def delete_message(self, message_id: str) -> None:
        """Delete a message (moves to Deleted Items)."""
        url = f"{self.GRAPH_BASE}/me/messages/{message_id}"
        
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                url,
                headers=self._get_headers(),
            )
            response.raise_for_status()

    async def get_unread_count(self) -> int:
        """Get count of unread messages in inbox."""
        messages = await self.list_messages(filter_unread=True, top=100)
        return len(messages)
