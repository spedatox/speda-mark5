"""Knowledge Base Router - API endpoints for knowledge management."""

from typing import Optional
import io

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
from pydantic import BaseModel

from app.auth import verify_api_key
from app.services.knowledge_base import KnowledgeBaseService


router = APIRouter(
    prefix="/api/knowledge", 
    tags=["Knowledge Base"],
    dependencies=[Depends(verify_api_key)],
)


# ==================== Request Models ====================

class AddNoteRequest(BaseModel):
    content: str
    category: str = "general"
    tags: list[str] | None = None


class AddKnowledgeRequest(BaseModel):
    title: str
    content: str
    category: str = "general"
    source: str | None = None
    tags: list[str] | None = None


class SearchRequest(BaseModel):
    query: str
    limit: int = 5
    category: str | None = None


# ==================== Notes Endpoints ====================

@router.post("/notes")
async def add_note(request: AddNoteRequest):
    """Add a quick note/memory."""
    try:
        service = KnowledgeBaseService()
        result = await service.add_note(
            content=request.content,
            category=request.category,
            tags=request.tags,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/notes")
async def get_notes(limit: int = 100):
    """Get all notes."""
    try:
        service = KnowledgeBaseService()
        notes = await service.get_all_notes(limit)
        return {"notes": notes, "count": len(notes)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/notes/search")
async def search_notes(request: SearchRequest):
    """Search notes by semantic similarity."""
    try:
        service = KnowledgeBaseService()
        results = await service.search_notes(
            query=request.query,
            limit=request.limit,
            category=request.category,
        )
        return {"results": results, "count": len(results)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/notes/{note_id}")
async def delete_note(note_id: str):
    """Delete a note."""
    try:
        service = KnowledgeBaseService()
        result = await service.delete_note(note_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== Knowledge Endpoints ====================

@router.post("/knowledge")
async def add_knowledge(request: AddKnowledgeRequest):
    """Add structured knowledge."""
    try:
        service = KnowledgeBaseService()
        result = await service.add_knowledge(
            title=request.title,
            content=request.content,
            category=request.category,
            source=request.source,
            tags=request.tags,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/knowledge/search")
async def search_knowledge(request: SearchRequest):
    """Search knowledge base by semantic similarity."""
    try:
        service = KnowledgeBaseService()
        results = await service.search_knowledge(
            query=request.query,
            limit=request.limit,
            category=request.category,
        )
        return {"results": results, "count": len(results)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== Documents Endpoints ====================

@router.post("/documents")
async def add_document(
    file: UploadFile = File(...),
    chunk_size: int = Form(1000),
):
    """Upload and index a document."""
    try:
        # Read file content
        content = await file.read()
        is_image = (file.content_type or "").startswith("image/")
        text_content = content.decode("utf-8", errors="ignore") if not is_image else ""
        
        # Determine file type
        file_type = "text"
        if is_image:
            file_type = "image"
            try:
                from PIL import Image  # type: ignore
                with Image.open(io.BytesIO(content)) as img:
                    width, height = img.size
                    text_content = f"Image uploaded: {file.filename or 'image'} ({width}x{height})"
            except Exception:
                text_content = f"Image uploaded: {file.filename or 'image'} ({len(content)} bytes)"
        elif file.filename:
            if file.filename.endswith(".md"):
                file_type = "markdown"
            elif file.filename.endswith(".py"):
                file_type = "python"
            elif file.filename.endswith(".json"):
                file_type = "json"
        
        service = KnowledgeBaseService()
        result = await service.add_document(
            filename=file.filename or "unknown",
            content=text_content,
            file_type=file_type,
            chunk_size=chunk_size,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/documents/text")
async def add_document_text(
    filename: str,
    content: str,
    file_type: str = "text",
    chunk_size: int = 1000,
):
    """Add a document from text content."""
    try:
        service = KnowledgeBaseService()
        result = await service.add_document(
            filename=filename,
            content=content,
            file_type=file_type,
            chunk_size=chunk_size,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/documents/search")
async def search_documents(request: SearchRequest):
    """Search documents by semantic similarity."""
    try:
        service = KnowledgeBaseService()
        results = await service.search_documents(
            query=request.query,
            limit=request.limit,
        )
        return {"results": results, "count": len(results)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== Unified Search ====================

@router.post("/search")
async def search_all(request: SearchRequest):
    """Search across all knowledge base collections."""
    try:
        service = KnowledgeBaseService()
        results = await service.search_all(
            query=request.query,
            limit=request.limit,
        )
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search")
async def search_all_get(query: str, limit: int = 10):
    """Search across all knowledge base (GET version)."""
    try:
        service = KnowledgeBaseService()
        results = await service.search_all(query=query, limit=limit)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== Stats ====================

@router.get("/stats")
async def get_stats():
    """Get knowledge base statistics."""
    try:
        service = KnowledgeBaseService()
        stats = await service.get_stats()
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
