"""Settings Router - runtime configuration toggles."""

from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import verify_api_key
from app.config import get_settings

router = APIRouter(prefix="/api/settings", tags=["Settings"])

# Popular/recommended models to show first
RECOMMENDED_MODELS = [
    "gpt-4o",
    "gpt-4o-mini", 
    "gpt-4-turbo",
    "gpt-4-turbo-preview",
    "gpt-4",
    "gpt-3.5-turbo",
    "o1-preview",
    "o1-mini",
]


class LlmUpdateRequest(BaseModel):
    provider: str
    model: str | None = None
    base_url: str | None = None


async def fetch_openai_models() -> list[str]:
    """Fetch available models from OpenAI API."""
    settings = get_settings()
    if not settings.openai_api_key:
        return RECOMMENDED_MODELS  # Return defaults if no API key
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://api.openai.com/v1/models",
                headers={"Authorization": f"Bearer {settings.openai_api_key}"}
            )
            if response.status_code == 200:
                data = response.json()
                models = [m["id"] for m in data.get("data", [])]
                # Sort: recommended first, then alphabetically
                sorted_models = []
                for rec in RECOMMENDED_MODELS:
                    if rec in models:
                        sorted_models.append(rec)
                        models.remove(rec)
                sorted_models.extend(sorted(models))
                return sorted_models
    except Exception:
        pass
    return RECOMMENDED_MODELS


@router.get("/llm")
async def get_llm_settings(_auth: bool = Depends(verify_api_key)):
    """Return the active LLM configuration with available models."""
    settings = get_settings()
    
    # Fetch available models from OpenAI
    available_models = await fetch_openai_models()
    
    return {
        "provider": settings.llm_provider,
        "available_providers": settings.available_llms,
        "available_models": available_models,
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
        "model": settings.openai_model,
        "base_url": settings.openai_base_url,
        "status": "updated",
    }
