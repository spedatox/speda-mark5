"""OAuth Authentication Router - Handles Google and Microsoft OAuth flows."""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse

from app.services.google_auth import GoogleAuthService
from app.services.microsoft_auth import MicrosoftAuthService


router = APIRouter(prefix="/api/auth", tags=["Authentication"])


# ==================== Google OAuth ====================

@router.get("/google/login")
async def google_login(redirect_uri: str | None = None, platform: str | None = None):
    """Initiate Google OAuth2 flow (web/mobile)."""
    auth_service = GoogleAuthService()
    auth_url = auth_service.get_auth_url(redirect_uri=redirect_uri)
    if platform == "mobile" and redirect_uri:
        auth_url += f"&state=mobile"
    return {"auth_url": auth_url}


@router.get("/google/callback")
async def google_callback(
    code: str = Query(...),
    redirect_uri: str | None = None,
):
    """Handle Google OAuth2 callback."""
    auth_service = GoogleAuthService()
    try:
        credentials = await auth_service.handle_callback(code, redirect_uri=redirect_uri)
        return {
            "status": "success",
            "message": "Google authentication successful! You can close this window.",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/google/status")
async def google_status():
    """Check Google authentication status."""
    auth_service = GoogleAuthService()
    return {
        "authenticated": auth_service.is_authenticated(),
        "provider": "google",
    }


@router.post("/google/logout")
async def google_logout():
    """Logout from Google (remove stored credentials)."""
    auth_service = GoogleAuthService()
    auth_service.logout()
    return {"status": "success", "message": "Logged out from Google"}


# ==================== Microsoft OAuth ====================

@router.get("/microsoft/login")
async def microsoft_login(redirect_uri: str | None = None, platform: str | None = None):
    """Initiate Microsoft OAuth2 flow."""
    auth_service = MicrosoftAuthService()
    auth_url = auth_service.get_auth_url(redirect_uri=redirect_uri)
    if platform == "mobile" and redirect_uri:
        auth_url += "&state=mobile"
    return {"auth_url": auth_url}


@router.get("/microsoft/callback")
async def microsoft_callback(
    code: str = Query(...),
    redirect_uri: str | None = None,
):
    """Handle Microsoft OAuth2 callback."""
    auth_service = MicrosoftAuthService()
    try:
        tokens = await auth_service.handle_callback(code, redirect_uri=redirect_uri)
        return {
            "status": "success",
            "message": "Microsoft authentication successful! You can close this window.",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/microsoft/status")
async def microsoft_status():
    """Check Microsoft authentication status."""
    auth_service = MicrosoftAuthService()
    return {
        "authenticated": auth_service.is_authenticated(),
        "provider": "microsoft",
    }


@router.post("/microsoft/logout")
async def microsoft_logout():
    """Logout from Microsoft (remove stored credentials)."""
    auth_service = MicrosoftAuthService()
    auth_service.logout()
    return {"status": "success", "message": "Logged out from Microsoft"}


# ==================== Combined Status ====================

@router.get("/status")
async def auth_status():
    """Check authentication status for all providers."""
    google_auth = GoogleAuthService()
    microsoft_auth = MicrosoftAuthService()
    
    return {
        "google": {
            "authenticated": google_auth.is_authenticated(),
            "services": ["calendar", "tasks"],
        },
        "microsoft": {
            "authenticated": microsoft_auth.is_authenticated(),
            "services": ["mail"],
        },
    }
