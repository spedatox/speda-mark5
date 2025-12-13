"""Function Calling Service - Define and execute functions for SPEDA AI."""

import json
from datetime import datetime, timedelta
from typing import Any, Optional

from app.services.google_calendar import GoogleCalendarService
from app.services.google_tasks import GoogleTasksService
from app.services.weather import WeatherService
from app.services.news import NewsService


# ==================== Function Definitions ====================

SPEDA_FUNCTIONS = [
    # ==================== Calendar Functions ====================
    {
        "type": "function",
        "function": {
            "name": "get_calendar_events",
            "description": "Get calendar events for a specific date range. Use this when the user asks about their schedule, meetings, or events. IMPORTANT: Always calculate the correct dates based on user's request - 'tomorrow' means today+1, 'next week' means today+7, etc. Use the current date provided in the system prompt to calculate.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "description": "Start date in ISO format (YYYY-MM-DD). Calculate based on user request: 'today' = current date, 'tomorrow' = current date + 1 day, 'this week' = current date, 'next Monday' = calculate the date."
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date in ISO format (YYYY-MM-DD). For single day queries use same as start_date. For 'this week' use end of week, etc."
                    },
                    "calendar_id": {
                        "type": "string",
                        "description": "Calendar ID. Use 'primary' for the main calendar.",
                        "default": "primary"
                    }
                },
                "required": ["start_date", "end_date"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_calendar_event",
            "description": "Create a new calendar event. Use this when the user wants to schedule a meeting, appointment, or event.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "The title/summary of the event"
                    },
                    "start_time": {
                        "type": "string",
                        "description": "Start date and time in ISO format (YYYY-MM-DDTHH:MM:SS)"
                    },
                    "end_time": {
                        "type": "string",
                        "description": "End date and time in ISO format (YYYY-MM-DDTHH:MM:SS)"
                    },
                    "description": {
                        "type": "string",
                        "description": "Optional description for the event"
                    },
                    "location": {
                        "type": "string",
                        "description": "Optional location for the event"
                    }
                },
                "required": ["title", "start_time", "end_time"]
            }
        }
    },
    
    # ==================== Task Functions ====================
    {
        "type": "function",
        "function": {
            "name": "get_tasks",
            "description": "Get the user's tasks from Google Tasks. Use this when the user asks about their tasks, to-do list, or things to do.",
            "parameters": {
                "type": "object",
                "properties": {
                    "show_completed": {
                        "type": "boolean",
                        "description": "Whether to include completed tasks",
                        "default": False
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of tasks to return",
                        "default": 20
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_task",
            "description": "Create a new task in Google Tasks. Use this when the user wants to add a task, reminder, or to-do item.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "The title of the task"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Optional notes/description for the task"
                    },
                    "due_date": {
                        "type": "string",
                        "description": "Optional due date in ISO format (YYYY-MM-DD)"
                    }
                },
                "required": ["title"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "complete_task",
            "description": "Mark a task as completed. Use this when the user says they finished a task.",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "The ID of the task to complete"
                    }
                },
                "required": ["task_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "delete_task",
            "description": "Delete a task from Google Tasks. Use this when the user wants to remove a task.",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "The ID of the task to delete"
                    }
                },
                "required": ["task_id"]
            }
        }
    },
    
    # ==================== Weather Functions ====================
    {
        "type": "function",
        "function": {
            "name": "get_current_weather",
            "description": "Get the current weather for a city. Use this when the user asks about the weather.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "City name (e.g., 'Istanbul', 'Ankara'). If not specified, uses default city."
                    },
                    "units": {
                        "type": "string",
                        "enum": ["metric", "imperial"],
                        "description": "Temperature units. 'metric' for Celsius, 'imperial' for Fahrenheit.",
                        "default": "metric"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_weather_forecast",
            "description": "Get weather forecast for upcoming days. Use this when the user asks about future weather.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "City name (e.g., 'Istanbul', 'Ankara'). If not specified, uses default city."
                    },
                    "days": {
                        "type": "integer",
                        "description": "Number of days for forecast (1-5)",
                        "default": 3
                    },
                    "units": {
                        "type": "string",
                        "enum": ["metric", "imperial"],
                        "description": "Temperature units",
                        "default": "metric"
                    }
                },
                "required": []
            }
        }
    },
    
    # ==================== News Functions ====================
    {
        "type": "function",
        "function": {
            "name": "get_news_headlines",
            "description": "Get top news headlines. Use this when the user asks about news or current events.",
            "parameters": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": ["general", "business", "technology", "science", "health", "sports", "entertainment"],
                        "description": "News category",
                        "default": "general"
                    },
                    "country": {
                        "type": "string",
                        "description": "Country code (e.g., 'tr' for Turkey, 'us' for USA)",
                        "default": "us"
                    },
                    "query": {
                        "type": "string",
                        "description": "Optional search query to filter news"
                    },
                    "count": {
                        "type": "integer",
                        "description": "Number of articles to return",
                        "default": 5
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_news",
            "description": "Search for news articles on a specific topic. Use this when the user wants news about something specific.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query for news articles"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language code (e.g., 'en', 'tr')",
                        "default": "en"
                    },
                    "count": {
                        "type": "integer",
                        "description": "Number of articles to return",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        }
    },
    
    # ==================== Daily Briefing ====================
    {
        "type": "function",
        "function": {
            "name": "get_daily_briefing",
            "description": "Get a comprehensive daily briefing including weather, calendar events, and tasks. Use this when the user asks for their daily summary, briefing, or 'what's on today'.",
            "parameters": {
                "type": "object",
                "properties": {
                    "include_weather": {
                        "type": "boolean",
                        "description": "Include weather in briefing",
                        "default": True
                    },
                    "include_calendar": {
                        "type": "boolean",
                        "description": "Include calendar events in briefing",
                        "default": True
                    },
                    "include_tasks": {
                        "type": "boolean",
                        "description": "Include tasks in briefing",
                        "default": True
                    }
                },
                "required": []
            }
        }
    },
    
    # ==================== Time/Date Functions ====================
    {
        "type": "function",
        "function": {
            "name": "get_current_datetime",
            "description": "Get the current date and time. Use this when you need to know the current time for scheduling or reference.",
            "parameters": {
                "type": "object",
                "properties": {
                    "timezone": {
                        "type": "string",
                        "description": "Timezone (e.g., 'Europe/Istanbul'). Defaults to local time."
                    }
                },
                "required": []
            }
        }
    },
    
    # ==================== Knowledge Base Functions ====================
    {
        "type": "function",
        "function": {
            "name": "remember_info",
            "description": "Save information to the knowledge base. Use this when the user says 'remember this', 'save this', 'note this', 'hatırla', 'kaydet', or wants you to remember something for later.",
            "parameters": {
                "type": "object",
                "properties": {
                    "content": {
                        "type": "string",
                        "description": "The information to remember"
                    },
                    "category": {
                        "type": "string",
                        "description": "Category for the note (e.g., 'personal', 'work', 'project', 'idea')",
                        "default": "general"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional tags for the note"
                    }
                },
                "required": ["content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_memory",
            "description": "Search the knowledge base for previously saved information. Use this when the user asks 'what do you know about...', 'do you remember...', 'ne biliyorsun...', or asks about something that might have been saved before.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query - what to look for in the knowledge base"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of results to return",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "add_knowledge",
            "description": "Add structured knowledge with a title. Use for longer, more formal information like project details, documentation, or reference material.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Title for the knowledge entry"
                    },
                    "content": {
                        "type": "string",
                        "description": "The detailed content"
                    },
                    "category": {
                        "type": "string",
                        "description": "Category (e.g., 'project', 'documentation', 'reference')",
                        "default": "general"
                    }
                },
                "required": ["title", "content"]
            }
        }
    },
]


# ==================== Function Executor ====================

class FunctionExecutor:
    """Execute functions called by the LLM."""
    
    def __init__(self):
        self.calendar_service = GoogleCalendarService()
        self.tasks_service = GoogleTasksService()
        self.weather_service = WeatherService()
        self.news_service = NewsService()
    
    async def execute(self, function_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        """Execute a function and return the result."""
        try:
            if function_name == "get_calendar_events":
                return await self._get_calendar_events(**arguments)
            elif function_name == "create_calendar_event":
                return await self._create_calendar_event(**arguments)
            elif function_name == "get_tasks":
                return await self._get_tasks(**arguments)
            elif function_name == "create_task":
                return await self._create_task(**arguments)
            elif function_name == "complete_task":
                return await self._complete_task(**arguments)
            elif function_name == "delete_task":
                return await self._delete_task(**arguments)
            elif function_name == "get_current_weather":
                return await self._get_current_weather(**arguments)
            elif function_name == "get_weather_forecast":
                return await self._get_weather_forecast(**arguments)
            elif function_name == "get_news_headlines":
                return await self._get_news_headlines(**arguments)
            elif function_name == "search_news":
                return await self._search_news(**arguments)
            elif function_name == "get_daily_briefing":
                return await self._get_daily_briefing(**arguments)
            elif function_name == "get_current_datetime":
                return await self._get_current_datetime(**arguments)
            # Knowledge Base functions
            elif function_name == "remember_info":
                return await self._remember_info(**arguments)
            elif function_name == "search_memory":
                return await self._search_memory(**arguments)
            elif function_name == "add_knowledge":
                return await self._add_knowledge(**arguments)
            else:
                return {"error": f"Unknown function: {function_name}"}
        except Exception as e:
            return {"error": str(e)}
    
    # ==================== Calendar Implementations ====================
    
    async def _get_calendar_events(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Get calendar events."""
        try:
            today = datetime.now().date()
            
            if start_date:
                start = datetime.fromisoformat(start_date)
            else:
                start = datetime.combine(today, datetime.min.time())
            
            if end_date:
                end = datetime.fromisoformat(end_date)
            else:
                end = datetime.combine(start.date(), datetime.max.time())
            
            events = await self.calendar_service.get_events(calendar_id, start, end)
            
            # Format events for readability
            formatted_events = []
            for event in events:
                formatted_events.append({
                    "id": event.get("id"),
                    "title": event.get("summary", "No title"),
                    "start": event.get("start", {}).get("dateTime") or event.get("start", {}).get("date"),
                    "end": event.get("end", {}).get("dateTime") or event.get("end", {}).get("date"),
                    "location": event.get("location"),
                    "description": event.get("description"),
                })
            
            return {
                "success": True,
                "events": formatted_events,
                "count": len(formatted_events),
                "date_range": f"{start.date()} to {end.date()}"
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _create_calendar_event(
        self,
        title: str,
        start_time: str,
        end_time: str,
        description: Optional[str] = None,
        location: Optional[str] = None,
        calendar_id: str = "primary",
    ) -> dict:
        """Create a calendar event."""
        try:
            event = await self.calendar_service.create_event(
                summary=title,
                start_time=datetime.fromisoformat(start_time),
                end_time=datetime.fromisoformat(end_time),
                description=description,
                location=location,
                calendar_id=calendar_id,
            )
            return {
                "success": True,
                "message": f"Created event: {title}",
                "event_id": event.get("id"),
                "event_link": event.get("htmlLink"),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    # ==================== Task Implementations ====================
    
    async def _get_tasks(
        self,
        show_completed: bool = False,
        max_results: int = 20,
    ) -> dict:
        """Get tasks."""
        try:
            tasks = await self.tasks_service.get_tasks(
                show_completed=show_completed,
                max_results=max_results,
            )
            
            formatted_tasks = []
            for task in tasks or []:
                formatted_tasks.append({
                    "id": task.get("id"),
                    "title": task.get("title"),
                    "notes": task.get("notes"),
                    "due": task.get("due"),
                    "status": task.get("status"),
                })
            
            return {
                "success": True,
                "tasks": formatted_tasks,
                "count": len(formatted_tasks),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _create_task(
        self,
        title: str,
        notes: Optional[str] = None,
        due_date: Optional[str] = None,
    ) -> dict:
        """Create a task."""
        try:
            task = await self.tasks_service.create_task(
                title=title,
                notes=notes,
                due_date=datetime.fromisoformat(due_date) if due_date else None,
            )
            return {
                "success": True,
                "message": f"Created task: {title}",
                "task_id": task.get("id"),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _complete_task(self, task_id: str) -> dict:
        """Complete a task."""
        try:
            task = await self.tasks_service.complete_task(task_id)
            return {
                "success": True,
                "message": f"Completed task: {task.get('title')}",
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _delete_task(self, task_id: str) -> dict:
        """Delete a task."""
        try:
            await self.tasks_service.delete_task(task_id)
            return {
                "success": True,
                "message": "Task deleted successfully",
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    # ==================== Weather Implementations ====================
    
    async def _get_current_weather(
        self,
        city: Optional[str] = None,
        units: str = "metric",
    ) -> dict:
        """Get current weather."""
        try:
            weather = await self.weather_service.get_current_weather(city, units)
            if weather:
                return {
                    "success": True,
                    "weather": weather,
                }
            return {"success": False, "error": "Weather data not available"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _get_weather_forecast(
        self,
        city: Optional[str] = None,
        days: int = 3,
        units: str = "metric",
    ) -> dict:
        """Get weather forecast."""
        try:
            forecast = await self.weather_service.get_forecast(city, units, days)
            if forecast:
                return {
                    "success": True,
                    "forecast": forecast,
                }
            return {"success": False, "error": "Forecast data not available"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    # ==================== News Implementations ====================
    
    async def _get_news_headlines(
        self,
        category: str = "general",
        country: str = "us",
        query: Optional[str] = None,
        count: int = 5,
    ) -> dict:
        """Get news headlines."""
        try:
            headlines = await self.news_service.get_top_headlines(
                country=country,
                category=category,
                query=query,
                page_size=count,
            )
            if headlines:
                formatted = []
                for article in headlines[:count]:
                    formatted.append({
                        "title": article.get("title"),
                        "source": article.get("source", {}).get("name"),
                        "description": article.get("description"),
                        "url": article.get("url"),
                        "published_at": article.get("publishedAt"),
                    })
                return {
                    "success": True,
                    "articles": formatted,
                    "count": len(formatted),
                }
            return {"success": False, "error": "News not available"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _search_news(
        self,
        query: str,
        language: str = "en",
        count: int = 5,
    ) -> dict:
        """Search news articles."""
        try:
            articles = await self.news_service.search_news(
                query=query,
                language=language,
                page_size=count,
            )
            if articles:
                formatted = []
                for article in articles[:count]:
                    formatted.append({
                        "title": article.get("title"),
                        "source": article.get("source", {}).get("name"),
                        "description": article.get("description"),
                        "url": article.get("url"),
                        "published_at": article.get("publishedAt"),
                    })
                return {
                    "success": True,
                    "articles": formatted,
                    "count": len(formatted),
                }
            return {"success": False, "error": "No articles found"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    # ==================== Briefing Implementation ====================
    
    async def _get_daily_briefing(
        self,
        include_weather: bool = True,
        include_calendar: bool = True,
        include_tasks: bool = True,
    ) -> dict:
        """Get comprehensive daily briefing."""
        briefing = {
            "success": True,
            "date": datetime.now().strftime("%A, %B %d, %Y"),
        }
        
        if include_weather:
            weather = await self._get_current_weather()
            if weather.get("success"):
                briefing["weather"] = weather.get("weather")
        
        if include_calendar:
            events = await self._get_calendar_events()
            if events.get("success"):
                briefing["events"] = events.get("events", [])
                briefing["event_count"] = events.get("count", 0)
        
        if include_tasks:
            tasks = await self._get_tasks()
            if tasks.get("success"):
                briefing["tasks"] = tasks.get("tasks", [])
                briefing["task_count"] = tasks.get("count", 0)
        
        return briefing
    
    # ==================== Utility Functions ====================
    
    async def _get_current_datetime(
        self,
        timezone: Optional[str] = None,
    ) -> dict:
        """Get current date and time."""
        now = datetime.now()
        return {
            "success": True,
            "datetime": now.isoformat(),
            "date": now.strftime("%Y-%m-%d"),
            "time": now.strftime("%H:%M:%S"),
            "day_of_week": now.strftime("%A"),
            "formatted": now.strftime("%A, %B %d, %Y at %I:%M %p"),
        }
    
    # ==================== Knowledge Base Functions ====================
    
    async def _remember_info(
        self,
        content: str,
        category: str = "general",
        tags: list[str] | None = None,
    ) -> dict:
        """Save information to knowledge base."""
        try:
            from app.services.knowledge_base import KnowledgeBaseService
            kb = KnowledgeBaseService()
            result = await kb.add_note(content=content, category=category, tags=tags)
            return {
                "success": True,
                "message": f"I'll remember that: {content[:100]}...",
                "note_id": result.get("note_id"),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _search_memory(
        self,
        query: str,
        limit: int = 5,
    ) -> dict:
        """Search knowledge base."""
        try:
            from app.services.knowledge_base import KnowledgeBaseService
            kb = KnowledgeBaseService()
            results = await kb.search_all(query=query, limit=limit)
            
            if results.get("results"):
                return {
                    "success": True,
                    "found": len(results["results"]),
                    "results": [
                        {
                            "content": r.get("content", "")[:500],
                            "source": r.get("source"),
                            "title": r.get("title", ""),
                        }
                        for r in results["results"]
                    ],
                }
            return {
                "success": True,
                "found": 0,
                "message": "No matching information found in my memory.",
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _add_knowledge(
        self,
        title: str,
        content: str,
        category: str = "general",
    ) -> dict:
        """Add structured knowledge."""
        try:
            from app.services.knowledge_base import KnowledgeBaseService
            kb = KnowledgeBaseService()
            result = await kb.add_knowledge(title=title, content=content, category=category)
            return {
                "success": True,
                "message": f"Knowledge saved: {title}",
                "knowledge_id": result.get("knowledge_id"),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}


# Export function definitions for use in LLM calls
def get_function_definitions() -> list[dict]:
    """Get all function definitions for OpenAI function calling."""
    return SPEDA_FUNCTIONS
