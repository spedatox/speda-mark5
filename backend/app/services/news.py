"""News Service - Fetch news from NewsAPI."""

from datetime import datetime
from typing import Optional

import httpx

from app.config import get_settings


class NewsService:
    """Service for fetching news from NewsAPI.org."""

    BASE_URL = "https://newsapi.org/v2"

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.news_api_key
        self.default_country = settings.news_default_country

    async def get_top_headlines(
        self,
        country: Optional[str] = None,
        category: Optional[str] = None,
        query: Optional[str] = None,
        page_size: int = 10,
    ) -> Optional[list[dict]]:
        """Get top headlines.
        
        Args:
            country: Country code (e.g., "tr", "us")
            category: Category (business, entertainment, general, health, science, sports, technology)
            query: Search query
            page_size: Number of articles to return
            
        Returns:
            List of news articles or None if API key not configured
        """
        if not self.api_key:
            return None
            
        params = {
            "apiKey": self.api_key,
            "pageSize": page_size,
        }
        
        if country or self.default_country:
            params["country"] = country or self.default_country
        if category:
            params["category"] = category
        if query:
            params["q"] = query

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.BASE_URL}/top-headlines",
                params=params,
            )
            
            if response.status_code != 200:
                return None
                
            data = response.json()
            
        articles = []
        for article in data.get("articles", []):
            articles.append({
                "title": article.get("title"),
                "description": article.get("description"),
                "source": article.get("source", {}).get("name"),
                "url": article.get("url"),
                "image_url": article.get("urlToImage"),
                "published_at": article.get("publishedAt"),
            })
            
        return articles

    async def search_news(
        self,
        query: str,
        language: str = "en",
        sort_by: str = "publishedAt",
        page_size: int = 10,
    ) -> Optional[list[dict]]:
        """Search for news articles.
        
        Args:
            query: Search query
            language: Language code
            sort_by: Sort order (relevancy, popularity, publishedAt)
            page_size: Number of articles to return
            
        Returns:
            List of news articles or None if API key not configured
        """
        if not self.api_key:
            return None

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.BASE_URL}/everything",
                params={
                    "apiKey": self.api_key,
                    "q": query,
                    "language": language,
                    "sortBy": sort_by,
                    "pageSize": page_size,
                },
            )
            
            if response.status_code != 200:
                return None
                
            data = response.json()
            
        articles = []
        for article in data.get("articles", []):
            articles.append({
                "title": article.get("title"),
                "description": article.get("description"),
                "source": article.get("source", {}).get("name"),
                "url": article.get("url"),
                "image_url": article.get("urlToImage"),
                "published_at": article.get("publishedAt"),
            })
            
        return articles

    async def get_news_summary(
        self,
        country: Optional[str] = None,
        count: int = 5,
    ) -> str:
        """Get a summary of top headlines.
        
        Args:
            country: Country code
            count: Number of headlines
            
        Returns:
            News summary string
        """
        headlines = await self.get_top_headlines(country=country, page_size=count)
        
        if not headlines:
            return "News data unavailable."
            
        summary_parts = ["Top Headlines:"]
        for i, article in enumerate(headlines, 1):
            summary_parts.append(f"{i}. {article['title']} ({article['source']})")
            
        return "\n".join(summary_parts)
