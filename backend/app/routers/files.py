"""Files API - Upload, analyze, and process files."""

import os
import uuid
from pathlib import Path
from typing import Optional, List
import base64
import mimetypes

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Header
from pydantic import BaseModel

from app.auth import verify_api_key
from app.config import get_settings
from app.services.llm import LLMService


router = APIRouter(prefix="/api/files", tags=["files"])
settings = get_settings()

# Upload directory
UPLOAD_DIR = Path("./uploads")
UPLOAD_DIR.mkdir(exist_ok=True)


class FileAnalysis(BaseModel):
    """File analysis response."""
    file_id: str
    filename: str
    file_type: str
    size: int
    analysis: Optional[str] = None
    extracted_text: Optional[str] = None
    vision_description: Optional[str] = None


class VisionAnalysisRequest(BaseModel):
    """Vision analysis request."""
    image_url: Optional[str] = None
    prompt: str = "What's in this image? Describe in detail."


@router.post("/upload", response_model=FileAnalysis)
async def upload_file(
    file: UploadFile = File(...),
    analyze: bool = Form(False),
    prompt: Optional[str] = Form(None),
    x_api_key: str = Header(None),
):
    """Upload a file and optionally analyze it.
    
    Supports:
    - Images: JPG, PNG, GIF, WebP (with Vision API)
    - Documents: PDF, TXT, MD
    - Audio: MP3, WAV, M4A (future: transcription)
    """
    verify_api_key(x_api_key)
    
    # Generate unique file ID
    file_id = str(uuid.uuid4())
    file_ext = Path(file.filename or "file").suffix
    safe_filename = f"{file_id}{file_ext}"
    file_path = UPLOAD_DIR / safe_filename
    
    # Save file
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)
    
    # Detect MIME type
    mime_type, _ = mimetypes.guess_type(str(file_path))
    mime_type = mime_type or "application/octet-stream"
    
    analysis_result = FileAnalysis(
        file_id=file_id,
        filename=file.filename or "unknown",
        file_type=mime_type,
        size=len(content),
    )
    
    # Analyze if requested
    if analyze and mime_type.startswith("image/"):
        try:
            llm_service = LLMService()
            
            # Encode image to base64
            image_b64 = base64.b64encode(content).decode('utf-8')
            image_url = f"data:{mime_type};base64,{image_b64}"
            
            # Use GPT-4 Vision
            analysis_prompt = prompt or "Describe this image in detail. What do you see?"
            
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": analysis_prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": image_url}
                        }
                    ]
                }
            ]
            
            vision_analysis = await llm_service.generate_response(
                messages,
                model="gpt-4o",  # Vision model
            )
            
            analysis_result.vision_description = vision_analysis
            analysis_result.analysis = f"Image analyzed: {vision_analysis[:200]}..."
            
        except Exception as e:
            print(f"[FILES] Vision analysis failed: {e}")
            analysis_result.analysis = f"Vision analysis failed: {str(e)}"
    
    elif analyze and mime_type == "text/plain":
        # Read text content
        try:
            text_content = content.decode('utf-8')
            analysis_result.extracted_text = text_content[:5000]  # Limit to 5KB
            analysis_result.analysis = f"Text file with {len(text_content)} characters"
        except Exception as e:
            analysis_result.analysis = f"Failed to read text: {e}"
    
    return analysis_result


@router.post("/analyze-image")
async def analyze_image(
    file: UploadFile = File(...),
    prompt: str = Form("What's in this image? Describe everything you see."),
    x_api_key: str = Header(None),
):
    """Analyze an image with GPT-4 Vision."""
    verify_api_key(x_api_key)
    
    # Read and encode image
    content = await file.read()
    mime_type, _ = mimetypes.guess_type(file.filename or "image.jpg")
    mime_type = mime_type or "image/jpeg"
    
    if not mime_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        llm_service = LLMService()
        
        # Encode to base64
        image_b64 = base64.b64encode(content).decode('utf-8')
        image_url = f"data:{mime_type};base64,{image_b64}"
        
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url}
                    }
                ]
            }
        ]
        
        description = await llm_service.generate_response(
            messages,
            model="gpt-4o",
        )
        
        return {
            "success": True,
            "filename": file.filename,
            "description": description,
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision analysis failed: {str(e)}")


@router.post("/analyze-url")
async def analyze_image_url(
    request: VisionAnalysisRequest,
    x_api_key: str = Header(None),
):
    """Analyze an image from URL."""
    verify_api_key(x_api_key)
    
    if not request.image_url:
        raise HTTPException(status_code=400, detail="image_url is required")
    
    try:
        llm_service = LLMService()
        
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": request.prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": request.image_url}
                    }
                ]
            }
        ]
        
        description = await llm_service.generate_response(
            messages,
            model="gpt-4o",
        )
        
        return {
            "success": True,
            "description": description,
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision analysis failed: {str(e)}")


@router.get("/{file_id}")
async def get_file(
    file_id: str,
    x_api_key: str = Header(None),
):
    """Get uploaded file."""
    verify_api_key(x_api_key)
    
    # Find file
    files = list(UPLOAD_DIR.glob(f"{file_id}.*"))
    
    if not files:
        raise HTTPException(status_code=404, detail="File not found")
    
    file_path = files[0]
    
    return {
        "file_id": file_id,
        "filename": file_path.name,
        "size": file_path.stat().st_size,
        "path": str(file_path),
    }


@router.delete("/{file_id}")
async def delete_file(
    file_id: str,
    x_api_key: str = Header(None),
):
    """Delete uploaded file."""
    verify_api_key(x_api_key)
    
    # Find and delete file
    files = list(UPLOAD_DIR.glob(f"{file_id}.*"))
    
    if not files:
        raise HTTPException(status_code=404, detail="File not found")
    
    for file_path in files:
        file_path.unlink()
    
    return {"success": True, "message": "File deleted"}


@router.get("/")
async def list_files(
    x_api_key: str = Header(None),
):
    """List all uploaded files."""
    verify_api_key(x_api_key)
    
    files = []
    for file_path in UPLOAD_DIR.iterdir():
        if file_path.is_file():
            files.append({
                "file_id": file_path.stem,
                "filename": file_path.name,
                "size": file_path.stat().st_size,
            })
    
    return {
        "files": files,
        "count": len(files),
    }
