"""Voice API endpoints for TTS and STT."""

import os
import uuid
import hashlib
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from openai import AsyncOpenAI

from app.config import get_settings

router = APIRouter(prefix="/api/voice", tags=["voice"])

settings = get_settings()

# TTS audio cache directory
TTS_CACHE_DIR = Path("./tts_cache")
TTS_CACHE_DIR.mkdir(exist_ok=True)


class TTSRequest(BaseModel):
    """TTS request model."""
    text: str
    voice: str = "nova"  # alloy, echo, fable, onyx, nova, shimmer


class TTSResponse(BaseModel):
    """TTS response model."""
    audio_url: str
    cached: bool = False


def get_cache_key(text: str, voice: str) -> str:
    """Generate a cache key for TTS audio."""
    content = f"{text}:{voice}"
    return hashlib.md5(content.encode()).hexdigest()


@router.post("/tts", response_model=TTSResponse)
async def generate_tts(request: TTSRequest):
    """Generate TTS audio from text using OpenAI TTS API.
    
    Returns a URL to the generated audio file.
    """
    if not settings.openai_api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured")
    
    if not request.text or len(request.text.strip()) == 0:
        raise HTTPException(status_code=400, detail="Text is required")
    
    # Limit text length (OpenAI TTS has a 4096 char limit)
    text = request.text[:4096]
    
    # Check cache first
    cache_key = get_cache_key(text, request.voice)
    cache_path = TTS_CACHE_DIR / f"{cache_key}.mp3"
    
    if cache_path.exists():
        return TTSResponse(
            audio_url=f"{settings.api_base_url}/api/voice/audio/{cache_key}.mp3",
            cached=True
        )
    
    # Generate new audio
    try:
        client = AsyncOpenAI(api_key=settings.openai_api_key)
        
        response = await client.audio.speech.create(
            model="tts-1",  # or "tts-1-hd" for higher quality
            voice=request.voice,
            input=text,
            response_format="mp3",
        )
        
        # Save to cache
        with open(cache_path, "wb") as f:
            for chunk in response.iter_bytes():
                f.write(chunk)
        
        return TTSResponse(
            audio_url=f"{settings.api_base_url}/api/voice/audio/{cache_key}.mp3",
            cached=False
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {str(e)}")


@router.get("/audio/{filename}")
async def get_audio(filename: str):
    """Serve cached TTS audio file."""
    # Sanitize filename
    if not filename.endswith(".mp3") or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    
    file_path = TTS_CACHE_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Audio file not found")
    
    return FileResponse(
        file_path,
        media_type="audio/mpeg",
        filename=filename,
    )


@router.delete("/cache")
async def clear_cache():
    """Clear the TTS audio cache."""
    count = 0
    for file in TTS_CACHE_DIR.glob("*.mp3"):
        file.unlink()
        count += 1
    
    return {"message": f"Cleared {count} cached audio files"}


@router.get("/voices")
async def list_voices():
    """List available TTS voices."""
    return {
        "voices": [
            {"id": "alloy", "name": "Alloy", "description": "Neutral, balanced"},
            {"id": "echo", "name": "Echo", "description": "Warm, conversational"},
            {"id": "fable", "name": "Fable", "description": "British, expressive"},
            {"id": "onyx", "name": "Onyx", "description": "Deep, authoritative"},
            {"id": "nova", "name": "Nova", "description": "Friendly, upbeat"},
            {"id": "shimmer", "name": "Shimmer", "description": "Clear, professional"},
        ],
        "default": "nova",
        "recommended_for_jarvis": "onyx",  # Deep voice for JARVIS feel
    }
