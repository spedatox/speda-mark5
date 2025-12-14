"""Microsoft 365 OAuth2 Service - Handles authentication for Outlook Mail."""

import json
from datetime import datetime
from pathlib import Path
from typing import Optional

import httpx

from app.config import get_settings


# Microsoft Graph scopes for mail
SCOPES = [
    "https://graph.microsoft.com/Mail.Read",
    "https://graph.microsoft.com/Mail.Send",
    "https://graph.microsoft.com/Mail.ReadWrite",
    "offline_access",
]


class MicrosoftAuthService:
    """Service for managing Microsoft OAuth2 authentication."""

    AUTHORITY = "https://login.microsoftonline.com/common"
    TOKEN_ENDPOINT = f"{AUTHORITY}/oauth2/v2.0/token"
    AUTH_ENDPOINT = f"{AUTHORITY}/oauth2/v2.0/authorize"

    def __init__(self):
        settings = get_settings()
        self.client_id = settings.microsoft_client_id
        self.client_secret = settings.microsoft_client_secret
        self.redirect_uri = settings.microsoft_redirect_uri
        self.token_file = Path("microsoft_token.json")

    def get_auth_url(self, redirect_uri: Optional[str] = None) -> str:
        """Generate the OAuth2 authorization URL."""
        redirect = redirect_uri or self.redirect_uri
        params = {
            "client_id": self.client_id,
            "response_type": "code",
            "redirect_uri": redirect,
            "scope": " ".join(SCOPES),
            "response_mode": "query",
            "prompt": "consent",
        }
        query = "&".join(f"{k}={v}" for k, v in params.items())
        return f"{self.AUTH_ENDPOINT}?{query}"

    async def handle_callback(self, code: str, redirect_uri: Optional[str] = None) -> dict:
        """Exchange authorization code for tokens."""
        redirect = redirect_uri or self.redirect_uri
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_ENDPOINT,
                data={
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "code": code,
                    "redirect_uri": redirect,
                    "grant_type": "authorization_code",
                    "scope": " ".join(SCOPES),
                },
            )
            response.raise_for_status()
            tokens = response.json()
            
        # Save tokens
        self._save_tokens(tokens)
        
        return tokens

    async def refresh_token(self) -> Optional[dict]:
        """Refresh the access token using refresh token."""
        token_data = self._load_tokens()
        if not token_data or "refresh_token" not in token_data:
            return None

        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_ENDPOINT,
                data={
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "refresh_token": token_data["refresh_token"],
                    "grant_type": "refresh_token",
                    "scope": " ".join(SCOPES),
                },
            )
            if response.status_code != 200:
                return None
                
            tokens = response.json()
            
        # Save new tokens (keep refresh token if not returned)
        if "refresh_token" not in tokens:
            tokens["refresh_token"] = token_data["refresh_token"]
        self._save_tokens(tokens)
        
        return tokens

    def get_access_token(self) -> Optional[str]:
        """Get valid access token, refreshing if necessary."""
        token_data = self._load_tokens()
        if not token_data:
            return None
        return token_data.get("access_token")

    def _save_tokens(self, tokens: dict) -> None:
        """Save tokens to file."""
        tokens["saved_at"] = datetime.utcnow().isoformat()
        with open(self.token_file, "w") as f:
            json.dump(tokens, f)

    def _load_tokens(self) -> Optional[dict]:
        """Load tokens from file."""
        if not self.token_file.exists():
            return None
        with open(self.token_file, "r") as f:
            return json.load(f)

    def is_authenticated(self) -> bool:
        """Check if we have tokens."""
        return self._load_tokens() is not None

    def logout(self) -> None:
        """Remove stored tokens."""
        if self.token_file.exists():
            self.token_file.unlink()
