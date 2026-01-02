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
        print(f"[SEARCH] Tavily API key configured: {bool(self.api_key)}")

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
        print(f"[SEARCH] Executing query: {query}")
        
        if not self.api_key:
            print("[SEARCH] ERROR: Tavily API key not configured")
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

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                print(f"[SEARCH] Calling Tavily API...")
                response = await client.post(self.BASE_URL, json=payload)
                print(f"[SEARCH] Response status: {response.status_code}")
                response.raise_for_status()
                data = response.json()
                print(f"[SEARCH] Got {len(data.get('results', []))} results")
        except httpx.HTTPStatusError as e:
            print(f"[SEARCH] HTTP Error: {e.response.status_code} - {e.response.text}")
            return {"success": False, "error": f"Tavily API error: {e.response.status_code}"}
        except Exception as e:
            print(f"[SEARCH] Exception: {type(e).__name__}: {e}")
            return {"success": False, "error": str(e)}

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
