"""Knowledge Base Service - Vector storage with ChromaDB and OpenAI embeddings."""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from typing import Any, Optional

import chromadb
from chromadb.config import Settings
from openai import OpenAI

from app.config import get_settings

# Thread pool for running blocking OpenAI calls
_executor = ThreadPoolExecutor(max_workers=4)


class KnowledgeBaseService:
    """Knowledge Base using ChromaDB for vector storage and OpenAI for embeddings."""
    
    def __init__(self):
        settings = get_settings()
        self.openai_client = OpenAI(api_key=settings.openai_api_key)
        self.embedding_model = "text-embedding-3-small"  # Cheapest, good quality
        
        # Initialize ChromaDB with persistent storage
        db_path = os.path.join(os.path.dirname(__file__), "..", "..", "data", "chromadb")
        os.makedirs(db_path, exist_ok=True)
        
        self.chroma_client = chromadb.PersistentClient(
            path=db_path,
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=True,
            )
        )
        
        # Create collections
        self._init_collections()
    
    def _init_collections(self):
        """Initialize ChromaDB collections."""
        # Main knowledge collection
        self.knowledge_collection = self.chroma_client.get_or_create_collection(
            name="knowledge",
            metadata={"description": "User's personal knowledge base"}
        )
        
        # Notes collection (quick memories)
        self.notes_collection = self.chroma_client.get_or_create_collection(
            name="notes",
            metadata={"description": "Quick notes and memories"}
        )
        
        # Documents collection (files)
        self.documents_collection = self.chroma_client.get_or_create_collection(
            name="documents",
            metadata={"description": "Indexed documents and files"}
        )
    
    def _get_embedding_sync(self, text: str) -> list[float]:
        """Get OpenAI embedding for text (synchronous, for thread pool)."""
        response = self.openai_client.embeddings.create(
            model=self.embedding_model,
            input=text,
        )
        return response.data[0].embedding
    
    async def _get_embedding(self, text: str) -> list[float]:
        """Get OpenAI embedding for text (async, non-blocking)."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(_executor, self._get_embedding_sync, text)
    
    async def _get_embeddings_batch(self, texts: list[str]) -> list[list[float]]:
        """Get embeddings for multiple texts in parallel."""
        tasks = [self._get_embedding(text) for text in texts]
        return await asyncio.gather(*tasks)
    
    # ==================== Notes (Quick Memories) ====================
    
    async def add_note(
        self,
        content: str,
        category: str = "general",
        tags: list[str] | None = None,
    ) -> dict[str, Any]:
        """Add a quick note/memory to the knowledge base."""
        note_id = f"note_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"
        
        # Get embedding (async, non-blocking)
        embedding = await self._get_embedding(content)
        
        # Store in ChromaDB
        self.notes_collection.add(
            ids=[note_id],
            embeddings=[embedding],
            documents=[content],
            metadatas=[{
                "category": category,
                "tags": ",".join(tags) if tags else "",
                "created_at": datetime.now().isoformat(),
                "type": "note",
            }]
        )
        
        return {
            "success": True,
            "note_id": note_id,
            "message": f"Note saved: {content[:50]}...",
        }
    
    async def search_notes(
        self,
        query: str,
        limit: int = 5,
        category: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search notes by semantic similarity."""
        query_embedding = await self._get_embedding(query)
        
        where_filter = None
        if category:
            where_filter = {"category": category}
        
        results = self.notes_collection.query(
            query_embeddings=[query_embedding],
            n_results=limit,
            where=where_filter,
        )
        
        notes = []
        if results["documents"] and results["documents"][0]:
            for i, doc in enumerate(results["documents"][0]):
                notes.append({
                    "id": results["ids"][0][i],
                    "content": doc,
                    "metadata": results["metadatas"][0][i] if results["metadatas"] else {},
                    "distance": results["distances"][0][i] if results["distances"] else None,
                })
        
        return notes
    
    async def get_all_notes(self, limit: int = 100) -> list[dict[str, Any]]:
        """Get all notes."""
        results = self.notes_collection.get(limit=limit)
        
        notes = []
        if results["documents"]:
            for i, doc in enumerate(results["documents"]):
                notes.append({
                    "id": results["ids"][i],
                    "content": doc,
                    "metadata": results["metadatas"][i] if results["metadatas"] else {},
                })
        
        return notes
    
    async def delete_note(self, note_id: str) -> dict[str, Any]:
        """Delete a note."""
        self.notes_collection.delete(ids=[note_id])
        return {"success": True, "message": f"Note {note_id} deleted"}
    
    # ==================== Knowledge (Structured Info) ====================
    
    async def add_knowledge(
        self,
        title: str,
        content: str,
        category: str = "general",
        source: str | None = None,
        tags: list[str] | None = None,
    ) -> dict[str, Any]:
        """Add structured knowledge to the base."""
        knowledge_id = f"kb_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"
        
        # Combine title and content for embedding
        full_text = f"{title}\n\n{content}"
        embedding = await self._get_embedding(full_text)
        
        self.knowledge_collection.add(
            ids=[knowledge_id],
            embeddings=[embedding],
            documents=[full_text],
            metadatas=[{
                "title": title,
                "category": category,
                "source": source or "",
                "tags": ",".join(tags) if tags else "",
                "created_at": datetime.now().isoformat(),
                "type": "knowledge",
            }]
        )
        
        return {
            "success": True,
            "knowledge_id": knowledge_id,
            "message": f"Knowledge saved: {title}",
        }
    
    async def search_knowledge(
        self,
        query: str,
        limit: int = 5,
        category: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search knowledge base by semantic similarity."""
        query_embedding = await self._get_embedding(query)
        
        where_filter = None
        if category:
            where_filter = {"category": category}
        
        results = self.knowledge_collection.query(
            query_embeddings=[query_embedding],
            n_results=limit,
            where=where_filter,
        )
        
        items = []
        if results["documents"] and results["documents"][0]:
            for i, doc in enumerate(results["documents"][0]):
                metadata = results["metadatas"][0][i] if results["metadatas"] else {}
                items.append({
                    "id": results["ids"][0][i],
                    "title": metadata.get("title", ""),
                    "content": doc,
                    "metadata": metadata,
                    "distance": results["distances"][0][i] if results["distances"] else None,
                })
        
        return items
    
    # ==================== Documents (File Indexing) ====================
    
    async def add_document(
        self,
        filename: str,
        content: str,
        file_type: str = "text",
        chunk_size: int = 1000,
    ) -> dict[str, Any]:
        """Index a document by chunking and embedding."""
        # Split content into chunks
        chunks = self._chunk_text(content, chunk_size)
        
        if not chunks:
            return {
                "success": False,
                "message": "No content to index",
            }
        
        doc_id_base = f"doc_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Get all embeddings in parallel (non-blocking)
        embeddings = await self._get_embeddings_batch(chunks)
        
        # Prepare batch data for ChromaDB
        chunk_ids = [f"{doc_id_base}_chunk_{i}" for i in range(len(chunks))]
        metadatas = [
            {
                "filename": filename,
                "file_type": file_type,
                "chunk_index": i,
                "total_chunks": len(chunks),
                "created_at": datetime.now().isoformat(),
                "type": "document",
            }
            for i in range(len(chunks))
        ]
        
        # Add all chunks in a single batch operation
        self.documents_collection.add(
            ids=chunk_ids,
            embeddings=embeddings,
            documents=chunks,
            metadatas=metadatas,
        )
        
        return {
            "success": True,
            "document_id": doc_id_base,
            "chunks": len(chunks),
            "message": f"Document indexed: {filename} ({len(chunks)} chunks)",
        }
    
    async def search_documents(
        self,
        query: str,
        limit: int = 5,
        filename: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search documents by semantic similarity."""
        query_embedding = await self._get_embedding(query)
        
        where_filter = None
        if filename:
            where_filter = {"filename": filename}
        
        results = self.documents_collection.query(
            query_embeddings=[query_embedding],
            n_results=limit,
            where=where_filter,
        )
        
        items = []
        if results["documents"] and results["documents"][0]:
            for i, doc in enumerate(results["documents"][0]):
                metadata = results["metadatas"][0][i] if results["metadatas"] else {}
                items.append({
                    "id": results["ids"][0][i],
                    "content": doc,
                    "filename": metadata.get("filename", ""),
                    "metadata": metadata,
                    "distance": results["distances"][0][i] if results["distances"] else None,
                })
        
        return items
    
    def _chunk_text(self, text: str, chunk_size: int = 1000, overlap: int = 100) -> list[str]:
        """Split text into overlapping chunks."""
        chunks = []
        start = 0
        
        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end]
            
            # Try to break at sentence boundary
            if end < len(text):
                last_period = chunk.rfind('.')
                last_newline = chunk.rfind('\n')
                break_point = max(last_period, last_newline)
                if break_point > chunk_size // 2:
                    chunk = chunk[:break_point + 1]
                    end = start + break_point + 1
            
            chunks.append(chunk.strip())
            start = end - overlap
        
        return [c for c in chunks if c]  # Filter empty chunks
    
    # ==================== Unified Search ====================
    
    async def search_all(
        self,
        query: str,
        limit: int = 10,
    ) -> dict[str, Any]:
        """Search across all collections."""
        notes = await self.search_notes(query, limit=limit // 3 + 1)
        knowledge = await self.search_knowledge(query, limit=limit // 3 + 1)
        documents = await self.search_documents(query, limit=limit // 3 + 1)
        
        # Combine and sort by distance
        all_results = []
        
        for note in notes:
            all_results.append({**note, "source": "notes"})
        
        for kb in knowledge:
            all_results.append({**kb, "source": "knowledge"})
        
        for doc in documents:
            all_results.append({**doc, "source": "documents"})
        
        # Sort by distance (lower is better)
        all_results.sort(key=lambda x: x.get("distance", 999))
        
        return {
            "results": all_results[:limit],
            "total": len(all_results),
            "sources": {
                "notes": len(notes),
                "knowledge": len(knowledge),
                "documents": len(documents),
            }
        }
    
    # ==================== Stats ====================
    
    async def get_stats(self) -> dict[str, Any]:
        """Get knowledge base statistics."""
        return {
            "notes_count": self.notes_collection.count(),
            "knowledge_count": self.knowledge_collection.count(),
            "documents_count": self.documents_collection.count(),
            "total": (
                self.notes_collection.count() +
                self.knowledge_collection.count() +
                self.documents_collection.count()
            ),
        }
