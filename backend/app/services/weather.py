"""Weather Service - Fetch weather data from OpenWeatherMap API."""

from datetime import datetime
from typing import Optional

import httpx

from app.config import get_settings


class WeatherService:
    """Service for fetching weather data from OpenWeatherMap."""

    BASE_URL = "https://api.openweathermap.org/data/2.5"

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.weather_api_key
        self.default_city = settings.weather_default_city

    async def get_current_weather(
        self,
        city: Optional[str] = None,
        units: str = "metric",
    ) -> Optional[dict]:
        """Get current weather for a city.
        
        Args:
            city: City name (e.g., "Istanbul,TR")
            units: Temperature units (metric, imperial, kelvin)
            
        Returns:
            Weather data dictionary or None if API key not configured
        """
        if not self.api_key:
            return None
            
        city = city or self.default_city
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.BASE_URL}/weather",
                params={
                    "q": city,
                    "appid": self.api_key,
                    "units": units,
                },
            )
            
            if response.status_code != 200:
                return None
                
            data = response.json()
            
        return {
            "city": data.get("name"),
            "country": data.get("sys", {}).get("country"),
            "temperature": data.get("main", {}).get("temp"),
            "feels_like": data.get("main", {}).get("feels_like"),
            "humidity": data.get("main", {}).get("humidity"),
            "description": data.get("weather", [{}])[0].get("description"),
            "icon": data.get("weather", [{}])[0].get("icon"),
            "wind_speed": data.get("wind", {}).get("speed"),
            "timestamp": datetime.utcnow().isoformat(),
        }

    async def get_forecast(
        self,
        city: Optional[str] = None,
        units: str = "metric",
        days: int = 5,
    ) -> Optional[list[dict]]:
        """Get weather forecast for a city.
        
        Args:
            city: City name
            units: Temperature units
            days: Number of days (max 5 for free tier)
            
        Returns:
            List of forecast entries or None if API key not configured
        """
        if not self.api_key:
            return None
            
        city = city or self.default_city
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.BASE_URL}/forecast",
                params={
                    "q": city,
                    "appid": self.api_key,
                    "units": units,
                    "cnt": days * 8,  # 8 entries per day (3-hour intervals)
                },
            )
            
            if response.status_code != 200:
                return None
                
            data = response.json()
            
        forecasts = []
        for item in data.get("list", []):
            forecasts.append({
                "datetime": item.get("dt_txt"),
                "temperature": item.get("main", {}).get("temp"),
                "feels_like": item.get("main", {}).get("feels_like"),
                "humidity": item.get("main", {}).get("humidity"),
                "description": item.get("weather", [{}])[0].get("description"),
                "icon": item.get("weather", [{}])[0].get("icon"),
                "wind_speed": item.get("wind", {}).get("speed"),
            })
            
        return forecasts

    async def get_weather_summary(self, city: Optional[str] = None) -> str:
        """Get a human-readable weather summary.
        
        Args:
            city: City name
            
        Returns:
            Weather summary string
        """
        weather = await self.get_current_weather(city)
        
        if not weather:
            return "Weather data unavailable."
            
        return (
            f"Currently in {weather['city']}: {weather['temperature']}°C "
            f"({weather['description']}), feels like {weather['feels_like']}°C. "
            f"Humidity: {weather['humidity']}%, Wind: {weather['wind_speed']} m/s."
        )
