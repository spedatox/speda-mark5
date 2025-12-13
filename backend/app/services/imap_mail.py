"""IMAP/SMTP Mail Service - Fetch and send emails via IMAP/SMTP."""

import asyncio
import imaplib
import smtplib
import email
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import decode_header
from datetime import datetime
from typing import Optional
from pathlib import Path
import json

from app.config import get_settings


class ImapMailService:
    """Service for interacting with email via IMAP/SMTP."""

    def __init__(self):
        settings = get_settings()
        self.email_address = settings.mail_email
        self.password = settings.mail_password
        self.imap_server = settings.mail_imap_server
        self.imap_port = settings.mail_imap_port
        self.smtp_server = settings.mail_smtp_server
        self.smtp_port = settings.mail_smtp_port
        self.config_file = Path("mail_config.json")

    def is_configured(self) -> bool:
        """Check if mail is configured."""
        return bool(self.email_address and self.password and self.imap_server)

    def _decode_header_value(self, value: str) -> str:
        """Decode email header value."""
        if not value:
            return ""
        decoded_parts = decode_header(value)
        result = []
        for part, charset in decoded_parts:
            if isinstance(part, bytes):
                result.append(part.decode(charset or 'utf-8', errors='replace'))
            else:
                result.append(part)
        return ''.join(result)

    def _parse_email_address(self, addr: str) -> dict:
        """Parse email address into name and address."""
        if not addr:
            return {"name": "", "address": ""}
        
        # Handle "Name <email@example.com>" format
        if '<' in addr and '>' in addr:
            name = addr[:addr.index('<')].strip().strip('"')
            address = addr[addr.index('<')+1:addr.index('>')].strip()
        else:
            name = ""
            address = addr.strip()
        
        return {"name": self._decode_header_value(name), "address": address}

    def _get_imap_connection(self) -> imaplib.IMAP4_SSL:
        """Get IMAP connection."""
        if not self.is_configured():
            raise ValueError("Mail not configured. Please set up email credentials.")
        
        imap = imaplib.IMAP4_SSL(self.imap_server, self.imap_port)
        imap.login(self.email_address, self.password)
        return imap

    def _list_messages_sync(
        self,
        folder: str = "INBOX",
        limit: int = 25,
        unread_only: bool = False,
    ) -> list[dict]:
        """Synchronous version of list_messages."""
        imap = self._get_imap_connection()
        
        try:
            imap.select(folder)
            
            # Search for messages
            if unread_only:
                _, message_ids = imap.search(None, 'UNSEEN')
            else:
                _, message_ids = imap.search(None, 'ALL')
            
            ids = message_ids[0].split()
            # Get latest messages first
            ids = ids[-limit:] if len(ids) > limit else ids
            ids.reverse()
            
            messages = []
            for msg_id in ids:
                _, msg_data = imap.fetch(msg_id, '(RFC822.HEADER FLAGS)')
                
                # Parse email
                email_body = msg_data[0][1]
                msg = email.message_from_bytes(email_body)
                
                # Check flags for read status
                flags = msg_data[0][0].decode() if msg_data[0][0] else ""
                is_read = '\\Seen' in flags
                
                # Parse date
                date_str = msg.get('Date', '')
                try:
                    # Try to parse the date
                    from email.utils import parsedate_to_datetime
                    received_date = parsedate_to_datetime(date_str).isoformat()
                except:
                    received_date = date_str
                
                messages.append({
                    "id": msg_id.decode(),
                    "subject": self._decode_header_value(msg.get('Subject', '(No Subject)')),
                    "from": self._parse_email_address(msg.get('From', '')),
                    "to": self._parse_email_address(msg.get('To', '')),
                    "date": received_date,
                    "isRead": is_read,
                    "hasAttachments": False,  # Would need to check BODYSTRUCTURE
                })
            
            return messages
        finally:
            imap.logout()

    async def list_messages(
        self,
        folder: str = "INBOX",
        limit: int = 25,
        unread_only: bool = False,
    ) -> list[dict]:
        """List messages from a mail folder."""
        return await asyncio.to_thread(
            self._list_messages_sync, folder, limit, unread_only
        )

    def _get_message_sync(self, message_id: str, folder: str = "INBOX") -> dict:
        """Synchronous version of get_message."""
        imap = self._get_imap_connection()
        
        try:
            imap.select(folder)
            _, msg_data = imap.fetch(message_id.encode(), '(RFC822)')
            
            email_body = msg_data[0][1]
            msg = email.message_from_bytes(email_body)
            
            # Get body
            body = ""
            body_html = ""
            
            if msg.is_multipart():
                for part in msg.walk():
                    content_type = part.get_content_type()
                    if content_type == "text/plain":
                        payload = part.get_payload(decode=True)
                        if payload:
                            body = payload.decode('utf-8', errors='replace')
                    elif content_type == "text/html":
                        payload = part.get_payload(decode=True)
                        if payload:
                            body_html = payload.decode('utf-8', errors='replace')
            else:
                payload = msg.get_payload(decode=True)
                if payload:
                    if msg.get_content_type() == "text/html":
                        body_html = payload.decode('utf-8', errors='replace')
                    else:
                        body = payload.decode('utf-8', errors='replace')
            
            # Parse date
            date_str = msg.get('Date', '')
            try:
                from email.utils import parsedate_to_datetime
                received_date = parsedate_to_datetime(date_str).isoformat()
            except:
                received_date = date_str
            
            return {
                "id": message_id,
                "subject": self._decode_header_value(msg.get('Subject', '(No Subject)')),
                "from": self._parse_email_address(msg.get('From', '')),
                "to": self._parse_email_address(msg.get('To', '')),
                "cc": self._parse_email_address(msg.get('Cc', '')),
                "date": received_date,
                "body": body,
                "bodyHtml": body_html,
            }
        finally:
            imap.logout()

    async def get_message(self, message_id: str, folder: str = "INBOX") -> dict:
        """Get a specific message with full body."""
        return await asyncio.to_thread(self._get_message_sync, message_id, folder)

    def _send_message_sync(
        self,
        to: list[str],
        subject: str,
        body: str,
        cc: Optional[list[str]] = None,
        is_html: bool = False,
    ) -> None:
        """Synchronous version of send_message."""
        if not self.is_configured():
            raise ValueError("Mail not configured. Please set up email credentials.")
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['From'] = self.email_address
        msg['To'] = ', '.join(to)
        msg['Subject'] = subject
        
        if cc:
            msg['Cc'] = ', '.join(cc)
        
        # Attach body
        if is_html:
            msg.attach(MIMEText(body, 'html'))
        else:
            msg.attach(MIMEText(body, 'plain'))
        
        # Send via SMTP - use STARTTLS for port 587, SSL for port 465
        recipients = to + (cc or [])
        if self.smtp_port == 587:
            # Use STARTTLS (Office 365, Gmail with STARTTLS)
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as smtp:
                smtp.starttls()
                smtp.login(self.email_address, self.password)
                smtp.sendmail(self.email_address, recipients, msg.as_string())
        else:
            # Use SSL (port 465)
            with smtplib.SMTP_SSL(self.smtp_server, self.smtp_port) as smtp:
                smtp.login(self.email_address, self.password)
                smtp.sendmail(self.email_address, recipients, msg.as_string())

    async def send_message(
        self,
        to: list[str],
        subject: str,
        body: str,
        cc: Optional[list[str]] = None,
        is_html: bool = False,
    ) -> None:
        """Send an email message."""
        await asyncio.to_thread(
            self._send_message_sync, to, subject, body, cc, is_html
        )

    def _list_folders_sync(self) -> list[str]:
        """List available mail folders."""
        imap = self._get_imap_connection()
        
        try:
            _, folders = imap.list()
            folder_names = []
            for folder in folders:
                # Parse folder name from response
                folder_str = folder.decode()
                # Extract folder name (last part after delimiter)
                if '"/"' in folder_str:
                    name = folder_str.split('"/" ')[-1].strip('"')
                else:
                    name = folder_str.split()[-1].strip('"')
                folder_names.append(name)
            return folder_names
        finally:
            imap.logout()

    async def list_folders(self) -> list[str]:
        """List available mail folders."""
        return await asyncio.to_thread(self._list_folders_sync)

    def _get_unread_count_sync(self, folder: str = "INBOX") -> int:
        """Get unread message count."""
        imap = self._get_imap_connection()
        
        try:
            imap.select(folder)
            _, message_ids = imap.search(None, 'UNSEEN')
            return len(message_ids[0].split()) if message_ids[0] else 0
        finally:
            imap.logout()

    async def get_unread_count(self, folder: str = "INBOX") -> int:
        """Get unread message count."""
        return await asyncio.to_thread(self._get_unread_count_sync, folder)
