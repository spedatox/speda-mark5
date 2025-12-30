"""LLM Service - Using OpenAI Responses API."""

import asyncio
import json
from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from typing import Any, Optional

import httpx
from openai import AsyncOpenAI

from app.config import get_settings


class LLMService(ABC):
    """Abstract base class for LLM services."""

    @abstractmethod
    async def generate_response(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> str:
        """Generate a response from the LLM."""
        pass

    @abstractmethod
    async def generate_response_stream(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming response from the LLM."""
        pass

    @abstractmethod
    async def generate_with_functions(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> dict[str, Any]:
        """Generate a response with function calling support."""
        pass

    @abstractmethod
    async def generate_with_functions_stream(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream response with function calling support."""
        pass

    @abstractmethod
    async def extract_intent(
        self,
        user_message: str,
        context: Optional[str] = None,
    ) -> dict:
        """Extract intent and entities from user message."""
        pass


class OpenAIResponsesService(LLMService):
    """OpenAI service using the new Responses API.
    
    The Responses API is simpler: send input items, get output items.
    Supports vision natively with input_image type.
    """

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.openai_api_key
        self.base_url = settings.openai_base_url or "https://api.openai.com/v1"
        self.model = settings.openai_model
        
        # Also keep AsyncOpenAI for some operations
        self.client = AsyncOpenAI(
            api_key=settings.openai_api_key,
            base_url=settings.openai_base_url,
        )
        
        # HTTP client for Responses API
        self.http_client = httpx.AsyncClient(
            base_url=self.base_url,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            timeout=120.0,
        )

    def _convert_messages_to_input(
        self, 
        messages: list[dict], 
        images: list[str] | None = None
    ) -> tuple[str | None, list[dict]]:
        """Convert chat messages format to Responses API input format.
        
        Returns:
            tuple of (instructions, input_items)
            - instructions: extracted from system message
            - input_items: converted user/assistant messages
        """
        instructions = None
        input_items = []
        
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            
            if role == "system":
                # System message becomes instructions
                if instructions:
                    instructions += "\n\n" + content
                else:
                    instructions = content
                continue
            
            if role == "tool":
                # Tool response
                input_items.append({
                    "type": "function_call_output",
                    "call_id": msg.get("tool_call_id", ""),
                    "output": content,
                })
                continue
            
            if role == "assistant":
                # Check if this was a tool call
                if msg.get("tool_calls"):
                    for tc in msg["tool_calls"]:
                        input_items.append({
                            "type": "function_call",
                            "id": tc.get("id", ""),
                            "call_id": tc.get("id", ""),
                            "name": tc["function"]["name"],
                            "arguments": tc["function"]["arguments"],
                        })
                elif content:
                    # Regular assistant message
                    input_items.append({
                        "role": "assistant",
                        "content": [{"type": "output_text", "text": content}],
                    })
                continue
            
            # User message - check if content is already structured (vision format)
            if isinstance(content, list):
                # Already structured content (vision format from chat completions)
                item_content = []
                for part in content:
                    if part.get("type") == "text":
                        item_content.append({"type": "input_text", "text": part["text"]})
                    elif part.get("type") == "image_url":
                        url = part["image_url"]["url"] if isinstance(part["image_url"], dict) else part["image_url"]
                        item_content.append({"type": "input_image", "image_url": url})
                    elif part.get("type") == "input_text":
                        item_content.append(part)
                    elif part.get("type") == "input_image":
                        item_content.append(part)
                input_items.append({"role": "user", "content": item_content})
            else:
                # Simple text content
                item_content = [{"type": "input_text", "text": content}]
                input_items.append({"role": "user", "content": item_content})
        
        # Add images to the last user message if provided
        if images and input_items:
            # Find the last user message
            for i in range(len(input_items) - 1, -1, -1):
                if input_items[i].get("role") == "user":
                    for img in images:
                        # Ensure proper data URI format
                        if not img.startswith("data:"):
                            img = f"data:image/jpeg;base64,{img}"
                        input_items[i]["content"].append({
                            "type": "input_image",
                            "image_url": img,
                        })
                    break
        
        return instructions, input_items

    def _convert_tools_to_functions(self, tools: list[dict]) -> list[dict]:
        """Convert tools format to Responses API function format."""
        functions = []
        for tool in tools:
            if tool.get("type") == "function":
                func = tool.get("function", {})
                functions.append({
                    "type": "function",
                    "name": func.get("name", ""),
                    "description": func.get("description", ""),
                    "parameters": func.get("parameters", {}),
                })
        return functions

    async def generate_response(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> str:
        """Generate a response using OpenAI Responses API."""
        instructions, input_items = self._convert_messages_to_input(messages, images)
        
        payload = {
            "model": self.model,
            "input": input_items,
            "temperature": temperature,
        }
        
        if instructions:
            payload["instructions"] = instructions
        if max_tokens:
            payload["max_output_tokens"] = max_tokens
        
        response = await self.http_client.post("/responses", json=payload)
        response.raise_for_status()
        data = response.json()
        
        # Extract text from output
        output = data.get("output", [])
        for item in output:
            if item.get("type") == "message":
                for content in item.get("content", []):
                    if content.get("type") == "output_text":
                        return content.get("text", "")
        
        # Fallback to output_text shorthand
        return data.get("output_text", "")

    async def generate_response_stream(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming response using OpenAI Responses API."""
        instructions, input_items = self._convert_messages_to_input(messages, images)
        
        payload = {
            "model": self.model,
            "input": input_items,
            "temperature": temperature,
            "stream": True,
        }
        
        if instructions:
            payload["instructions"] = instructions
        if max_tokens:
            payload["max_output_tokens"] = max_tokens
        
        async with self.http_client.stream("POST", "/responses", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        # Handle different event types
                        event_type = data.get("type", "")
                        if event_type == "response.output_text.delta":
                            delta = data.get("delta", "")
                            if delta:
                                yield delta
                        elif "delta" in data and isinstance(data.get("delta"), str):
                            yield data["delta"]
                    except json.JSONDecodeError:
                        continue

    async def generate_with_functions(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> dict[str, Any]:
        """Generate a response with function calling support."""
        instructions, input_items = self._convert_messages_to_input(messages, images)
        tools = self._convert_tools_to_functions(functions)
        
        payload = {
            "model": self.model,
            "input": input_items,
            "tools": tools,
            "tool_choice": "auto",
            "temperature": temperature,
        }
        
        if instructions:
            payload["instructions"] = instructions
        if max_tokens:
            payload["max_output_tokens"] = max_tokens
        
        response = await self.http_client.post("/responses", json=payload)
        response.raise_for_status()
        data = response.json()
        
        # Check output for function calls
        output = data.get("output", [])
        for item in output:
            if item.get("type") == "function_call":
                args_str = item.get("arguments", "{}")
                try:
                    args = json.loads(args_str) if isinstance(args_str, str) else args_str
                except json.JSONDecodeError:
                    args = {}
                
                return {
                    "type": "function_call",
                    "id": item.get("call_id", item.get("id", "")),
                    "name": item.get("name", ""),
                    "arguments": args,
                }
            elif item.get("type") == "message":
                for content in item.get("content", []):
                    if content.get("type") == "output_text":
                        return {
                            "type": "message",
                            "content": content.get("text", ""),
                        }
        
        # Fallback
        return {
            "type": "message",
            "content": data.get("output_text", ""),
        }

    async def generate_with_functions_stream(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream response with function calling support."""
        instructions, input_items = self._convert_messages_to_input(messages, images)
        tools = self._convert_tools_to_functions(functions)
        
        payload = {
            "model": self.model,
            "input": input_items,
            "tools": tools,
            "tool_choice": "auto",
            "temperature": temperature,
            "stream": True,
        }
        
        if instructions:
            payload["instructions"] = instructions
        if max_tokens:
            payload["max_output_tokens"] = max_tokens
        
        # Track function call accumulation
        function_call_id = None
        function_name = ""
        function_arguments = ""
        has_function_call = False
        
        async with self.http_client.stream("POST", "/responses", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        event_type = data.get("type", "")
                        
                        # Function call events
                        if event_type == "response.function_call_arguments.delta":
                            has_function_call = True
                            function_arguments += data.get("delta", "")
                        elif event_type == "response.output_item.added":
                            item = data.get("item", {})
                            if item.get("type") == "function_call":
                                has_function_call = True
                                function_call_id = item.get("call_id", item.get("id", ""))
                                function_name = item.get("name", "")
                        elif event_type == "response.output_text.delta":
                            # Text content
                            delta = data.get("delta", "")
                            if delta:
                                yield {"type": "chunk", "content": delta}
                        elif "delta" in data and isinstance(data.get("delta"), str):
                            yield {"type": "chunk", "content": data["delta"]}
                    except json.JSONDecodeError:
                        continue
        
        # Yield function call if accumulated
        if has_function_call and function_name:
            try:
                args = json.loads(function_arguments) if function_arguments else {}
            except json.JSONDecodeError:
                args = {}
            
            yield {
                "type": "function_call",
                "id": function_call_id,
                "name": function_name,
                "arguments": args,
            }
        
        yield {"type": "done"}

    async def extract_intent(
        self,
        user_message: str,
        context: Optional[str] = None,
    ) -> dict:
        """Extract intent using OpenAI Responses API."""
        system_prompt = """You are an intent extraction system. Analyze the user message and extract:
- intent: The primary intent (task_create, task_list, task_complete, calendar_view, calendar_create, email_draft, email_send, briefing, general_chat, unknown)
- entities: Relevant entities like dates, times, titles, recipients, etc.
- language: The detected language (tr for Turkish, en for English, etc.)

Respond in JSON format only."""

        input_items = [{"role": "user", "content": [{"type": "input_text", "text": user_message}]}]
        
        if context:
            system_prompt += f"\n\nContext: {context}"
        
        payload = {
            "model": self.model,
            "instructions": system_prompt,
            "input": input_items,
            "temperature": 0.1,
            "text": {"format": {"type": "json_object"}},
        }
        
        response = await self.http_client.post("/responses", json=payload)
        response.raise_for_status()
        data = response.json()
        
        try:
            return json.loads(data.get("output_text", "{}"))
        except json.JSONDecodeError:
            return {"intent": "general_chat", "entities": {}, "language": "en"}

    async def generate_conversation_title(
        self,
        first_user_message: str,
        first_assistant_response: str,
    ) -> str:
        """Generate a creative title for a conversation."""
        prompt = f"""Generate a short, creative title (2-5 words) for a conversation:

User: {first_user_message}
Assistant: {first_assistant_response[:200]}...

Rules:
- 2-5 words maximum
- Same language as user message
- Creative and descriptive
- No quotes or punctuation

Just output the title."""

        input_items = [{"role": "user", "content": [{"type": "input_text", "text": prompt}]}]
        
        try:
            payload = {
                "model": self.model,
                "input": input_items,
                "temperature": 0.7,
                "max_output_tokens": 30,
            }
            
            response = await self.http_client.post("/responses", json=payload)
            response.raise_for_status()
            data = response.json()
            
            title = data.get("output_text", "Yeni Sohbet")
            title = title.strip().strip('"').strip("'").strip()
            if len(title) > 50:
                title = title[:50]
            return title
        except Exception as e:
            print(f"Error generating title: {e}")
            return "Yeni Sohbet"

    # Helper method for vision - kept for compatibility
    def _supports_vision(self) -> bool:
        """All models via Responses API support vision with input_image."""
        return True

    def build_vision_message(self, text: str, images: list[str]) -> dict:
        """Build a message with images for the Responses API.
        
        This creates a properly formatted user message with input_image items.
        """
        content = []
        
        if text:
            content.append({"type": "input_text", "text": text})
        
        for img in images:
            if not img.startswith("data:"):
                img = f"data:image/jpeg;base64,{img}"
            content.append({"type": "input_image", "image_url": img})
        
        return {"role": "user", "content": content}

    async def close(self):
        """Close HTTP client."""
        await self.http_client.aclose()


# Keep the old class name as alias for compatibility
OpenAIService = OpenAIResponsesService


class MockLLMService(LLMService):
    """Mock LLM service for development and testing."""

    INTENT_PATTERNS = {
        "task": ["görev", "task", "yapılacak", "todo", "reminder", "hatırlat"],
        "calendar": ["takvim", "calendar", "etkinlik", "event", "toplantı", "meeting"],
        "email": ["mail", "e-posta", "email", "mesaj gönder"],
        "briefing": ["özet", "briefing", "günlük", "daily", "bugün ne var"],
    }

    async def generate_response(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> str:
        """Generate a mock response."""
        last_user_message = ""
        for msg in reversed(messages):
            if msg["role"] == "user":
                content = msg["content"]
                if isinstance(content, list):
                    for part in content:
                        if part.get("type") in ("text", "input_text"):
                            last_user_message = part.get("text", "").lower()
                            break
                else:
                    last_user_message = content.lower()
                break

        is_turkish = any(
            word in last_user_message
            for word in ["merhaba", "nasıl", "görev", "takvim", "bugün", "yarın"]
        )

        if any(word in last_user_message for word in self.INTENT_PATTERNS["task"]):
            return "Görev oluşturdum." if is_turkish else "Task noted."

        if any(word in last_user_message for word in self.INTENT_PATTERNS["calendar"]):
            return "Takvim güncellendi." if is_turkish else "Calendar updated."

        if any(word in last_user_message for word in self.INTENT_PATTERNS["briefing"]):
            return "İşte özetin." if is_turkish else "Here's your briefing."

        return "Anladım." if is_turkish else "Understood."

    async def generate_response_stream(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[str, None]:
        """Generate a mock streaming response."""
        response = await self.generate_response(messages, temperature, max_tokens, images)
        for word in response.split(" "):
            yield word + " "
            await asyncio.sleep(0.05)

    async def generate_with_functions(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> dict[str, Any]:
        """Mock function calling."""
        last_user_message = ""
        for msg in reversed(messages):
            if msg["role"] == "user":
                content = msg["content"]
                if isinstance(content, list):
                    for part in content:
                        if part.get("type") in ("text", "input_text"):
                            last_user_message = part.get("text", "").lower()
                            break
                else:
                    last_user_message = content.lower()
                break
        
        if any(word in last_user_message for word in ["weather", "hava"]):
            return {"type": "function_call", "id": "mock_1", "name": "get_current_weather", "arguments": {}}
        
        if any(word in last_user_message for word in ["calendar", "takvim"]):
            return {"type": "function_call", "id": "mock_2", "name": "get_calendar_events", "arguments": {}}
        
        if any(word in last_user_message for word in ["gmail", "mail", "email", "inbox", "messages"]):
            args = {"unread_only": True, "important_only": True, "max_results": 5}
            return {"type": "function_call", "id": "mock_3", "name": "get_gmail_messages", "arguments": args}
        
        response = await self.generate_response(messages, temperature, max_tokens, images)
        return {"type": "message", "content": response}

    async def generate_with_functions_stream(
        self,
        messages: list[dict],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        images: list[str] | None = None,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream mock response."""
        result = await self.generate_with_functions(messages, functions, temperature, max_tokens, images)
        
        if result["type"] == "function_call":
            yield result
        else:
            for word in result["content"].split(" "):
                yield {"type": "chunk", "content": word + " "}
                await asyncio.sleep(0.05)
        
        yield {"type": "done"}

    async def extract_intent(
        self,
        user_message: str,
        context: Optional[str] = None,
    ) -> dict:
        """Mock intent extraction."""
        message_lower = user_message.lower()
        is_turkish = any(word in message_lower for word in ["merhaba", "görev", "takvim"])
        
        intent = "general_chat"
        if any(word in message_lower for word in self.INTENT_PATTERNS["task"]):
            intent = "task_create"
        elif any(word in message_lower for word in self.INTENT_PATTERNS["calendar"]):
            intent = "calendar_view"
        elif any(word in message_lower for word in self.INTENT_PATTERNS["briefing"]):
            intent = "briefing"
        
        return {
            "intent": intent,
            "entities": {},
            "language": "tr" if is_turkish else "en",
            "confidence": 0.8,
        }

    async def generate_conversation_title(
        self,
        first_user_message: str,
        first_assistant_response: str,
    ) -> str:
        """Generate mock title."""
        return "Yeni Sohbet"

    def _supports_vision(self) -> bool:
        return True

    def build_vision_message(self, text: str, images: list[str]) -> dict:
        content = [{"type": "input_text", "text": text}]
        for img in images:
            content.append({"type": "input_image", "image_url": img})
        return {"role": "user", "content": content}


def get_llm_service() -> LLMService:
    """Factory function to get the appropriate LLM service."""
    settings = get_settings()

    if settings.llm_provider == "openai" and settings.openai_api_key:
        return OpenAIResponsesService()

    return MockLLMService()
