"""LLM Service - Abstracted interface for language model interactions."""

import asyncio
import json
from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from typing import Any, Optional

from openai import AsyncOpenAI

from app.config import get_settings


class LLMService(ABC):
    """Abstract base class for LLM services."""

    @abstractmethod
    async def generate_response(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> str:
        """Generate a response from the LLM."""
        pass

    @abstractmethod
    async def generate_response_stream(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming response from the LLM."""
        pass

    @abstractmethod
    async def generate_with_functions(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> dict[str, Any]:
        """Generate a response with function calling support.
        
        Returns dict with either:
        - {"type": "message", "content": str} for regular responses
        - {"type": "function_call", "name": str, "arguments": dict} for function calls
        """
        pass

    @abstractmethod
    async def generate_with_functions_stream(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream response with function calling support.
        
        Yields dicts with:
        - {"type": "chunk", "content": str} for text chunks
        - {"type": "function_call", "name": str, "arguments": dict} for function calls
        - {"type": "done"} when complete
        """
        pass

    @abstractmethod
    async def extract_intent(
        self,
        user_message: str,
        context: Optional[str] = None,
    ) -> dict:
        """Extract intent and entities from user message."""
        pass

    @abstractmethod
    async def generate_conversation_title(
        self,
        first_user_message: str,
        first_assistant_response: str,
    ) -> str:
        """Generate a creative, concise title for a conversation."""
        pass


class OpenAIService(LLMService):
    """OpenAI-based LLM service."""

    def __init__(self):
        settings = get_settings()
        self.client = AsyncOpenAI(
            api_key=settings.openai_api_key,
            base_url=settings.openai_base_url,
        )
        self.model = settings.openai_model

    async def generate_response(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> str:
        """Generate a response using OpenAI API."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return response.choices[0].message.content or ""

    async def generate_response_stream(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming response using OpenAI API."""
        stream = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )
        async for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    async def generate_with_functions(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> dict[str, Any]:
        """Generate a response with function calling support."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            tools=functions,
            tool_choice="auto",
            temperature=temperature,
            max_tokens=max_tokens,
        )
        
        message = response.choices[0].message
        
        # Check if there's a function call
        if message.tool_calls:
            tool_call = message.tool_calls[0]
            return {
                "type": "function_call",
                "id": tool_call.id,
                "name": tool_call.function.name,
                "arguments": json.loads(tool_call.function.arguments),
            }
        
        # Regular message response
        return {
            "type": "message",
            "content": message.content or "",
        }

    async def generate_with_functions_stream(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream response with function calling support."""
        stream = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            tools=functions,
            tool_choice="auto",
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )
        
        # Accumulate function call data
        function_call_id = None
        function_name = ""
        function_arguments = ""
        has_function_call = False
        
        async for chunk in stream:
            if not chunk.choices:
                continue
                
            delta = chunk.choices[0].delta
            
            # Check for tool calls in the delta
            if delta.tool_calls:
                has_function_call = True
                tool_call = delta.tool_calls[0]
                
                if tool_call.id:
                    function_call_id = tool_call.id
                if tool_call.function:
                    if tool_call.function.name:
                        function_name = tool_call.function.name
                    if tool_call.function.arguments:
                        function_arguments += tool_call.function.arguments
            
            # Check for regular content
            elif delta.content:
                yield {"type": "chunk", "content": delta.content}
        
        # If we accumulated a function call, yield it
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
        """Extract intent using OpenAI."""
        system_prompt = """You are an intent extraction system. Analyze the user message and extract:
- intent: The primary intent (task_create, task_list, task_complete, calendar_view, calendar_create, email_draft, email_send, briefing, general_chat, unknown)
- entities: Relevant entities like dates, times, titles, recipients, etc.
- language: The detected language (tr for Turkish, en for English, etc.)

Respond in JSON format only."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ]

        if context:
            messages.insert(1, {"role": "system", "content": f"Context: {context}"})

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=0.1,
            max_tokens=500,
            response_format={"type": "json_object"},
        )

        import json

        return json.loads(response.choices[0].message.content or "{}")


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
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> str:
        """Generate a mock response."""
        last_user_message = ""
        for msg in reversed(messages):
            if msg["role"] == "user":
                last_user_message = msg["content"].lower()
                break

        # Detect language
        is_turkish = any(
            word in last_user_message
            for word in ["merhaba", "nasıl", "görev", "takvim", "bugün", "yarın"]
        )

        # Generate contextual response
        if any(word in last_user_message for word in self.INTENT_PATTERNS["task"]):
            if is_turkish:
                return "Görev oluşturdum. Başka bir şey var mı?"
            return "I've noted that task. Anything else?"

        if any(word in last_user_message for word in self.INTENT_PATTERNS["calendar"]):
            if is_turkish:
                return "Takvim etkinliğini ekledim. Çakışma yok."
            return "Calendar event added. No conflicts detected."

        if any(word in last_user_message for word in self.INTENT_PATTERNS["email"]):
            if is_turkish:
                return "E-posta taslağını hazırladım. Göndermeden önce onayınızı alacağım."
            return "I've drafted the email. I'll need your confirmation before sending."

        if any(word in last_user_message for word in self.INTENT_PATTERNS["briefing"]):
            if is_turkish:
                return "İşte bugünkü özetin. Bekleyen görevlerin ve etkinliklerin var."
            return "Here's your daily briefing. You have pending tasks and events."

        # Default responses
        if is_turkish:
            return "Anladım. Size nasıl yardımcı olabilirim?"
        return "Understood. How can I assist you further?"

    async def generate_response_stream(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[str, None]:
        """Generate a mock streaming response."""
        response = await self.generate_response(messages, temperature, max_tokens)
        # Simulate streaming by yielding word by word
        words = response.split(" ")
        for i, word in enumerate(words):
            if i > 0:
                yield " "
            yield word
            await asyncio.sleep(0.05)  # Small delay to simulate streaming

    async def generate_with_functions(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> dict[str, Any]:
        """Generate a mock response with function calling (basic pattern matching)."""
        last_user_message = ""
        for msg in reversed(messages):
            if msg["role"] == "user":
                last_user_message = msg["content"].lower()
                break
        
        # Check for function-triggering patterns
        if any(word in last_user_message for word in ["weather", "hava", "sıcaklık", "temperature"]):
            return {"type": "function_call", "id": "mock_1", "name": "get_current_weather", "arguments": {}}
        
        if any(word in last_user_message for word in ["task", "görev", "yapılacak"]):
            if any(word in last_user_message for word in ["list", "show", "göster", "listele"]):
                return {"type": "function_call", "id": "mock_2", "name": "get_tasks", "arguments": {}}
        
        if any(word in last_user_message for word in ["calendar", "takvim", "schedule", "meeting"]):
            return {"type": "function_call", "id": "mock_3", "name": "get_calendar_events", "arguments": {}}
        
        if any(word in last_user_message for word in ["briefing", "özet", "daily", "günlük"]):
            return {"type": "function_call", "id": "mock_4", "name": "get_daily_briefing", "arguments": {}}
        
        if any(word in last_user_message for word in ["news", "haber"]):
            return {"type": "function_call", "id": "mock_5", "name": "get_news_headlines", "arguments": {}}
        
        # Default to regular message
        response = await self.generate_response(messages, temperature, max_tokens)
        return {"type": "message", "content": response}

    async def generate_with_functions_stream(
        self,
        messages: list[dict[str, str]],
        functions: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Stream mock response with function calling."""
        result = await self.generate_with_functions(messages, functions, temperature, max_tokens)
        
        if result["type"] == "function_call":
            yield result
        else:
            # Stream the message content
            words = result["content"].split(" ")
            for i, word in enumerate(words):
                if i > 0:
                    yield {"type": "chunk", "content": " "}
                yield {"type": "chunk", "content": word}
                await asyncio.sleep(0.05)
        
        yield {"type": "done"}

    async def extract_intent(
        self,
        user_message: str,
        context: Optional[str] = None,
    ) -> dict:
        """Extract intent from user message using pattern matching."""
        message_lower = user_message.lower()

        # Detect language
        is_turkish = any(
            word in message_lower
            for word in ["merhaba", "nasıl", "görev", "takvim", "bugün", "yarın", "lütfen"]
        )
        language = "tr" if is_turkish else "en"

        # Detect intent
        intent = "general_chat"
        entities = {}

        # Task intent detection
        if any(word in message_lower for word in self.INTENT_PATTERNS["task"]):
            if any(word in message_lower for word in ["oluştur", "ekle", "create", "add", "yeni", "new"]):
                intent = "task_create"
            elif any(word in message_lower for word in ["listele", "list", "göster", "show"]):
                intent = "task_list"
            elif any(word in message_lower for word in ["tamamla", "complete", "done", "bitti"]):
                intent = "task_complete"
            else:
                intent = "task_create"  # Default to create for task mentions

        # Calendar intent detection
        elif any(word in message_lower for word in self.INTENT_PATTERNS["calendar"]):
            if any(word in message_lower for word in ["oluştur", "ekle", "create", "add", "yeni", "new"]):
                intent = "calendar_create"
            else:
                intent = "calendar_view"

        # Email intent detection
        elif any(word in message_lower for word in self.INTENT_PATTERNS["email"]):
            if any(word in message_lower for word in ["gönder", "send"]):
                intent = "email_send"
            else:
                intent = "email_draft"

        # Briefing intent detection
        elif any(word in message_lower for word in self.INTENT_PATTERNS["briefing"]):
            intent = "briefing"

        return {
            "intent": intent,
            "entities": entities,
            "language": language,
            "confidence": 0.8,
        }

    async def generate_conversation_title(
        self,
        first_user_message: str,
        first_assistant_response: str,
    ) -> str:
        """Generate a creative, concise title for a conversation based on the first exchange.
        
        Returns a short title (2-5 words) that captures the essence of the conversation.
        """
        prompt = f"""You are a title generator for a personal AI assistant called SPEDA (like JARVIS).
Generate a short, creative title (2-5 words) for a conversation that started with this exchange:

User: {first_user_message}
Assistant: {first_assistant_response[:200]}...

Rules:
- Title should be 2-5 words maximum
- Use the same language as the user message
- Be creative and descriptive, not generic
- No quotes or punctuation marks
- Capture the main topic or intent

Examples for Turkish:
- "Yarınki Toplantı Planı"
- "İstanbul Hava Durumu"
- "Kod Hata Çözümü"
- "Günlük Brifing Özeti"

Examples for English:
- "Weather Check Request"
- "Calendar Event Planning"
- "Code Bug Investigation"
- "Daily Schedule Review"

Just output the title, nothing else."""

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                max_tokens=30,
            )
            title = response.choices[0].message.content or "Yeni Sohbet"
            # Clean up the title
            title = title.strip().strip('"').strip("'").strip()
            # Limit length
            if len(title) > 50:
                title = title[:50]
            return title
        except Exception as e:
            print(f"Error generating conversation title: {e}")
            return "Yeni Sohbet"


def get_llm_service() -> LLMService:
    """Factory function to get the appropriate LLM service."""
    settings = get_settings()

    if settings.llm_provider == "openai" and settings.openai_api_key:
        return OpenAIService()

    return MockLLMService()
