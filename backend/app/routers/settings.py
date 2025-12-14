"""Settings Router - runtime configuration toggles."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import verify_api_key
from app.config import get_settings

router = APIRouter(prefix="/api/settings", tags=["Settings"])


class LlmUpdateRequest(BaseModel):
    provider: str
    model: str | None = None
    base_url: str | None = None


@router.get("/llm")
async def get_llm_settings(_auth: bool = Depends(verify_api_key)):
    """Return the active LLM configuration."""
    settings = get_settings()
    return {
        "provider": settings.llm_provider,
        "available": settings.available_llms,
        "model": settings.openai_model,
        "base_url": settings.openai_base_url,
    }


@router.post("/llm")
async def update_llm_settings(
    request: LlmUpdateRequest,
    _auth: bool = Depends(verify_api_key),
):
    """Switch the active LLM provider at runtime."""
    settings = get_settings()

    if request.provider not in settings.available_llms:
        raise HTTPException(status_code=400, detail="Unsupported provider")

    settings.llm_provider = request.provider  # type: ignore[attr-defined]
    if request.model:
        settings.openai_model = request.model  # type: ignore[attr-defined]
    if request.base_url is not None:
        settings.openai_base_url = request.base_url  # type: ignore[attr-defined]

    return {
        "provider": settings.llm_provider,
        "available": settings.available_llms,
        "model": settings.openai_model,
        "base_url": settings.openai_base_url,
    }
