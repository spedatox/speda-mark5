"""Google Gmail Service - Fetch emails via Gmail API."""

import asyncio
from datetime import datetime
from email.header import decode_header, make_header
from email.utils import parseaddr, parsedate_to_datetime
from typing import Optional

from googleapiclient.discovery import build

from app.services.google_auth import GoogleAuthService


class GoogleGmailService:
    """Service for interacting with Gmail API."""

    def __init__(self):
        self.auth_service = GoogleAuthService()

    def _get_service(self):
        """Get authenticated Gmail API service."""
        credentials = self.auth_service.get_credentials()
        if not credentials:
            raise ValueError("Not authenticated with Google. Please authorize first.")
        return build("gmail", "v1", credentials=credentials)

    def _decode_header(self, value: Optional[str]) -> str:
        """Decode potentially encoded header values."""
        if not value:
            return ""
        try:
            return str(make_header(decode_header(value)))
        except Exception:
            return value

    def _parse_sender(self, sender_raw: str) -> dict:
        """Parse sender string into name/address."""
        name, address = parseaddr(sender_raw or "")
        return {
            "name": self._decode_header(name).strip('"'),
            "address": address,
        }

    def _parse_received_at(self, date_header: Optional[str], internal_ms: Optional[str]) -> Optional[datetime]:
        """Parse received time from headers or internal timestamp."""
        if date_header:
            try:
                return parsedate_to_datetime(date_header)
            except Exception:
                pass

        if internal_ms:
            try:
                return datetime.fromtimestamp(int(internal_ms) / 1000.0)
            except Exception:
                return None
        return None

    def _list_messages_sync(
        self,
        label_ids: Optional[list[str]] = None,
        query: Optional[str] = None,
        max_results: int = 10,
    ) -> list[dict]:
        """Synchronous version of list_messages."""
        service = self._get_service()
        result = service.users().messages().list(
            userId="me",
            labelIds=label_ids or ["INBOX"],
            q=query,
            maxResults=max_results,
        ).execute()
        return result.get("messages", [])

    async def list_messages(
        self,
        label_ids: Optional[list[str]] = None,
        query: Optional[str] = None,
        max_results: int = 10,
    ) -> list[dict]:
        """List messages from Gmail."""
        return await asyncio.to_thread(
            self._list_messages_sync,
            label_ids,
            query,
            max_results,
        )

    def _get_message_sync(self, message_id: str, format: str = "metadata") -> dict:
        """Synchronous version of get_message."""
        service = self._get_service()
        return service.users().messages().get(
            userId="me",
            id=message_id,
            format=format,
            metadataHeaders=["Subject", "From", "Date"],
        ).execute()

    async def get_message(self, message_id: str, format: str = "metadata") -> dict:
        """Get a specific Gmail message."""
        return await asyncio.to_thread(self._get_message_sync, message_id, format)

    async def get_important_messages(
        self,
        max_results: int = 5,
        unread_only: bool = True,
    ) -> list[dict]:
        """Get important (and optionally unread) messages from the inbox."""
        label_ids = ["INBOX", "IMPORTANT"]
        if unread_only:
            label_ids.append("UNREAD")

        messages = await self.list_messages(
            label_ids=label_ids,
            max_results=max_results,
        )

        important_messages: list[dict] = []
        for msg_ref in messages:
            msg = await self.get_message(msg_ref.get("id", ""))
            payload = msg.get("payload", {})
            headers = {h.get("name"): h.get("value") for h in payload.get("headers", [])}

            subject = self._decode_header(headers.get("Subject", "(No Subject)"))
            sender_raw = headers.get("From", "")
            received_at = self._parse_received_at(headers.get("Date"), msg.get("internalDate"))
            label_ids_in_msg = msg.get("labelIds", [])

            important_messages.append(
                {
                    "id": msg.get("id"),
                    "thread_id": msg.get("threadId"),
                    "subject": subject,
                    "from": self._parse_sender(sender_raw),
                    "snippet": msg.get("snippet", ""),
                    "received_at": received_at,
                    "is_unread": "UNREAD" in label_ids_in_msg,
                    "is_important": "IMPORTANT" in label_ids_in_msg,
                }
            )

        return important_messages
