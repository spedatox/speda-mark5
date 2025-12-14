"""Web search service powered by Tavily."""

from __future__ import annotations

from typing import Any, Optional

import httpx

from app.config import get_settings


class TavilySearchService:
    """Lightweight wrapper around the Tavily API."""

    BASE_URL = "https://api.tavily.com/search"

    def __init__(self) -> None:
        settings = get_settings()
        self.api_key = settings.tavily_api_key

    async def search(
        self,
        query: str,
        *,
        max_results: int = 5,
        include_images: bool = False,
        search_depth: str = "advanced",
    ) -> dict[str, Any]:
        """Execute a search query against Tavily.
        
        Returns a normalized payload even when Tavily is not configured.
        """
        if not self.api_key:
            return {
                "success": False,
                "error": "Tavily API key not configured",
            }

        payload = {
            "api_key": self.api_key,
            "query": query,
            "max_results": max_results,
            "search_depth": search_depth,
            "include_images": include_images,
        }

        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(self.BASE_URL, json=payload)
            response.raise_for_status()
            data = response.json()

        results = data.get("results", [])
        return {
            "success": True,
            "query": query,
            "results": [
                {
                    "title": r.get("title"),
                    "url": r.get("url"),
                    "content": r.get("content"),
                    "score": r.get("score"),
                    "image_url": r.get("image_url"),
                }
                for r in results[:max_results]
            ],
            "source": "tavily",
        }
