"""Google OAuth2 Service - Handles authentication for Google Calendar and Tasks."""

import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from google.auth.transport.requests import Request

from app.config import get_settings


# Scopes needed for Calendar and Tasks
SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/tasks.readonly",
    "https://www.googleapis.com/auth/tasks",
    "https://www.googleapis.com/auth/gmail.readonly",
]


class GoogleAuthService:
    """Service for managing Google OAuth2 authentication."""

    def __init__(self):
        settings = get_settings()
        self.client_id = settings.google_client_id
        self.client_secret = settings.google_client_secret
        self.redirect_uri = settings.google_redirect_uri
        self.token_file = Path("google_token.json")

    def get_auth_url(self, redirect_uri: Optional[str] = None) -> str:
        """Generate the OAuth2 authorization URL."""
        redirect = redirect_uri or self.redirect_uri
        flow = Flow.from_client_config(
            {
                "web": {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [redirect],
                }
            },
            scopes=SCOPES,
            redirect_uri=redirect,
        )
        auth_url, _ = flow.authorization_url(
            access_type="offline",
            prompt="consent",
        )
        return auth_url

    async def handle_callback(self, code: str, redirect_uri: Optional[str] = None) -> Credentials:
        """Exchange authorization code for credentials."""
        redirect = redirect_uri or self.redirect_uri
        flow = Flow.from_client_config(
            {
                "web": {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [redirect],
                }
            },
            scopes=SCOPES,
            redirect_uri=redirect,
        )
        flow.fetch_token(code=code)
        credentials = flow.credentials
        
        # Save credentials
        self._save_credentials(credentials)
        
        return credentials

    def get_credentials(self) -> Optional[Credentials]:
        """Get valid credentials, refreshing if necessary."""
        if not self.token_file.exists():
            return None

        with open(self.token_file, "r") as f:
            token_data = json.load(f)

        credentials = Credentials(
            token=token_data.get("token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=self.client_id,
            client_secret=self.client_secret,
            scopes=SCOPES,
        )

        # Refresh if expired
        if credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
            self._save_credentials(credentials)

        return credentials

    def _save_credentials(self, credentials: Credentials) -> None:
        """Save credentials to file."""
        token_data = {
            "token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "token_uri": credentials.token_uri,
            "client_id": credentials.client_id,
            "client_secret": credentials.client_secret,
            "scopes": list(credentials.scopes) if credentials.scopes else SCOPES,
        }
        with open(self.token_file, "w") as f:
            json.dump(token_data, f)

    def is_authenticated(self) -> bool:
        """Check if we have valid credentials."""
        creds = self.get_credentials()
        return creds is not None and creds.valid

    def logout(self) -> None:
        """Remove stored credentials."""
        if self.token_file.exists():
            self.token_file.unlink()

    def store_mobile_token(self, access_token: str) -> None:
        """Store access token from mobile native sign-in.
        
        Note: Mobile tokens don't have refresh tokens, so they'll expire.
        The mobile app should re-authenticate when needed.
        """
        token_data = {
            "token": access_token,
            "refresh_token": None,  # Mobile sign-in doesn't provide refresh token
            "token_uri": "https://oauth2.googleapis.com/token",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scopes": SCOPES,
            "source": "mobile",  # Mark as mobile token
        }
        with open(self.token_file, "w") as f:
            json.dump(token_data, f)
