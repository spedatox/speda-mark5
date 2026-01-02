"""Proactive Scheduler - SPEDA's background intelligence engine."""

import asyncio
from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, async_session_maker
from app.models import User
from app.services.google_calendar import GoogleCalendarService
from app.services.google_tasks import GoogleTasksService
from app.services.weather import WeatherService
from app.services.llm import LLMService


class ProactiveScheduler:
    """Background intelligence - monitors and suggests proactively."""
    
    def __init__(self):
        self.calendar_service = GoogleCalendarService()
        self.tasks_service = GoogleTasksService()
        self.weather_service = WeatherService()
        self.llm_service = LLMService()
        self.is_running = False
    
    async def start(self):
        """Start the proactive scheduler loop."""
        self.is_running = True
        print("[SCHEDULER] Proactive scheduler started")
        
        while self.is_running:
            try:
                await self._check_upcoming_events()
                await self._check_overdue_tasks()
                await self._check_weather_alerts()
                await self._suggest_daily_plan()
            except Exception as e:
                print(f"[SCHEDULER] Error: {e}")
            
            # Run every 5 minutes
            await asyncio.sleep(300)
    
    async def stop(self):
        """Stop the scheduler."""
        self.is_running = False
        print("[SCHEDULER] Proactive scheduler stopped")
    
    async def _check_upcoming_events(self):
        """Check for upcoming events and send reminders."""
        # TODO: Get user from session/context
        # For now, check for events in next 15 minutes
        print("[SCHEDULER] Checking upcoming events...")
        
        # Get calendar events
        time_min = datetime.now().isoformat() + 'Z'
        time_max = (datetime.now() + timedelta(minutes=15)).isoformat() + 'Z'
        
        # This would need OAuth token from user
        # events = await self.calendar_service.get_events(time_min, time_max)
        
        # If event found, generate briefing
        # briefing = await self._generate_event_briefing(event)
        # await self._send_notification(briefing)
        pass
    
    async def _check_overdue_tasks(self):
        """Check for overdue tasks and remind user."""
        print("[SCHEDULER] Checking overdue tasks...")
        # Similar to events, need user context
        pass
    
    async def _check_weather_alerts(self):
        """Check weather and suggest actions."""
        print("[SCHEDULER] Checking weather alerts...")
        
        try:
            # Get current weather (default city from config)
            weather = await self.weather_service.get_current_weather("Istanbul")
            
            if weather:
                temp = weather.get("main", {}).get("temp")
                condition = weather.get("weather", [{}])[0].get("main")
                
                # Smart suggestions based on weather
                if condition in ["Rain", "Drizzle", "Thunderstorm"]:
                    print("[SCHEDULER] Rain detected - suggest umbrella")
                    # await self._send_notification("Yağmur yağıyor, şemsiye almayı unutma!")
                
                if temp and temp < 5:
                    print("[SCHEDULER] Cold weather - suggest warm clothing")
                    # await self._send_notification("Hava soğuk, kalın giyinmeyi unutma!")
        
        except Exception as e:
            print(f"[SCHEDULER] Weather check failed: {e}")
    
    async def _suggest_daily_plan(self):
        """Generate smart daily suggestions."""
        print("[SCHEDULER] Generating daily suggestions...")
        
        # Check time of day and suggest routines
        hour = datetime.now().hour
        
        if hour == 7:  # Morning briefing
            print("[SCHEDULER] Morning briefing time!")
            # briefing = await self._generate_morning_briefing()
            # await self._send_notification(briefing)
        
        elif hour == 20:  # Evening summary
            print("[SCHEDULER] Evening summary time!")
            # summary = await self._generate_evening_summary()
            # await self._send_notification(summary)
    
    async def _generate_event_briefing(self, event: dict) -> str:
        """Generate intelligent briefing for upcoming event."""
        prompt = f"""
        Upcoming event: {event.get('summary')}
        Time: {event.get('start')}
        Location: {event.get('location', 'Not specified')}
        
        Generate a brief, professional reminder in Turkish.
        Include: time until meeting, location if important, preparation tips.
        Keep it under 2 sentences.
        """
        
        return await self.llm_service.generate_response([
            {"role": "system", "content": "You are SPEDA, a proactive executive assistant."},
            {"role": "user", "content": prompt}
        ])
    
    async def _generate_morning_briefing(self) -> str:
        """Generate morning briefing."""
        # Get calendar events, tasks, weather
        # Combine into intelligent briefing
        return "Günaydın! Bugün 3 toplantın ve 5 görevin var. Hava güneşli, 18°C."
    
    async def _generate_evening_summary(self) -> str:
        """Generate evening summary."""
        return "Bugün 8 görevi tamamladın. Yarın için 3 toplantı planlandı."
    
    async def _send_notification(self, message: str):
        """Send notification to user."""
        # This would integrate with notification system
        # For now, just log
        print(f"[NOTIFICATION] {message}")


# Global scheduler instance
_scheduler: Optional[ProactiveScheduler] = None


async def start_scheduler():
    """Start the global scheduler."""
    global _scheduler
    if _scheduler is None:
        _scheduler = ProactiveScheduler()
        asyncio.create_task(_scheduler.start())


async def stop_scheduler():
    """Stop the global scheduler."""
    global _scheduler
    if _scheduler:
        await _scheduler.stop()
        _scheduler = None
