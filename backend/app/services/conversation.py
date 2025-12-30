"""Conversation Engine - Manages chat context and system identity."""

from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Conversation, Message
from app.config import get_settings
from app.services.llm import LLMService


# Speda's system identity
SYSTEM_PROMPT = """
### SYSTEM PROMPT: SPEDA MK1 (OPTIMIZED)

## CORE IDENTITY
You are Speda. You are not a database; you are a proactive Executive Assistant and Chief of Staff.
- **Vibe:** Warm, highly intelligent, fluid, and "Human-First."
- **Goal:** To manage the user's life with the natural ease of a real person, not a command-line tool.

## PRIME DIRECTIVE: THE "NO-LIST" PROTOCOL
You are strictly forbidden from using robotic formatting for conversation.
1. **NO** Bullet points (*).
2. **NO** Numbered lists (1., 2.).
3. **NO** Markdown tables.
4. **NO** Bold keys (e.g., **Date:**)
UNLESS YOU'RE TOLD TO SPECIFICALLY DO SO.

Instead, **NARRATE** the data.
- *Bad:* "- Meeting: 10 AM"
- *Good:* "You have that meeting coming up at 10 AM, so you should probably get ready."

## LANGUAGE & ADAPTABILITY
- **Language Lock:** If User = Turkish, You = Turkish. If User = English, You = English.
- **Mirroring:** Match the user's energy. If they are stressed, be concise and supportive. If they are casual, be chatty.

## OPERATIONAL RULES (CRITICAL)
1. **The "Check First" Rule:** NEVER send emails, delete data, or modify calendar events without explicit confirmation. Draft it, show it, wait for a "Yes."
2. **Persistence:** Tasks are immortal until marked done. If a task is overdue, nag the user gently ("Hey, we still haven't tackled the X project yet.").
3. **Insight:** Don't just report; analyze.
   - *Instead of:* "You have 3 events."
   - *Say:* "It looks like a heavy Tuesday. You've got three back-to-back meetings starting at 10, so manage your energy carefully."

## CONTEXT
- **Current Time:** {current_time}
- **Timezone:** {timezone}
"""


class ConversationEngine:
    """Engine for managing conversations with the assistant."""

    def __init__(self, db: AsyncSession, llm: LLMService):
        self.db = db
        self.llm = llm
        self.settings = get_settings()

    def _build_system_prompt(self, timezone: str = "Europe/Istanbul") -> str:
        """Build the system prompt with current context."""
        from zoneinfo import ZoneInfo
        
        try:
            tz = ZoneInfo(timezone)
        except Exception:
            tz = ZoneInfo("Europe/Istanbul")
        
        now = datetime.now(tz)
        return SYSTEM_PROMPT.format(
            current_time=now.strftime("%Y-%m-%d %H:%M"),
            timezone=timezone,
        )

    async def get_or_create_conversation(
        self, conversation_id: Optional[int] = None
    ) -> Conversation:
        """Get existing or create new conversation."""
        if conversation_id:
            result = await self.db.execute(
                select(Conversation)
                .options(selectinload(Conversation.messages))
                .where(Conversation.id == conversation_id)
            )
            conversation = result.scalar_one_or_none()
            if conversation:
                return conversation

        # Create new conversation
        conversation = Conversation()
        self.db.add(conversation)
        await self.db.flush()
        return conversation

    async def add_message(
        self,
        conversation: Conversation,
        role: str,
        content: str,
    ) -> Message:
        """Add a message to the conversation."""
        message = Message(
            conversation_id=conversation.id,
            role=role,
            content=content,
        )
        self.db.add(message)
        await self.db.flush()
        return message

    async def get_context_messages(
        self,
        conversation: Conversation,
        max_messages: Optional[int] = None,
    ) -> list[dict[str, str]]:
        """Get messages for LLM context with windowing."""
        max_messages = max_messages or self.settings.max_context_messages

        # Always load messages from database to avoid lazy loading issues
        result = await self.db.execute(
            select(Message)
            .where(Message.conversation_id == conversation.id)
            .order_by(Message.created_at.asc())
        )
        messages = list(result.scalars().all())

        # Window the messages
        if len(messages) > max_messages:
            messages = messages[-max_messages:]

        return [{"role": msg.role, "content": msg.content} for msg in messages]

    async def process_message(
        self,
        user_message: str,
        timezone: str = "Europe/Istanbul",
        conversation_id: Optional[int] = None,
        additional_context: Optional[str] = None,
    ) -> tuple[str, Conversation, dict]:
        """Process a user message and generate a response."""
        # Get or create conversation
        conversation = await self.get_or_create_conversation(conversation_id)

        # Add user message
        await self.add_message(conversation, "user", user_message)

        # Build context
        system_prompt = self._build_system_prompt(timezone)
        if additional_context:
            system_prompt += f"\n\n## Additional Context\n{additional_context}"

        context_messages = await self.get_context_messages(conversation)

        # Build full message list for LLM
        messages = [
            {"role": "system", "content": system_prompt},
            *context_messages,
        ]

        # Extract intent for action handling
        intent_info = await self.llm.extract_intent(user_message)

        # Generate response
        response = await self.llm.generate_response(messages)

        # Add assistant response
        await self.add_message(conversation, "assistant", response)

        return response, conversation, intent_info

    async def get_conversation_summary(
        self, conversation_id: int
    ) -> Optional[str]:
        """Get or generate a summary of the conversation."""
        result = await self.db.execute(
            select(Conversation).where(Conversation.id == conversation_id)
        )
        conversation = result.scalar_one_or_none()

        if not conversation:
            return None

        if conversation.summary:
            return conversation.summary

        # Generate summary if many messages
        result = await self.db.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
        )
        messages = result.scalars().all()

        if len(messages) < self.settings.summary_threshold:
            return None

        # Generate summary using LLM
        summary_prompt = "Summarize this conversation in 2-3 sentences, focusing on key decisions and outcomes:\n\n"
        for msg in messages:
            summary_prompt += f"{msg.role}: {msg.content}\n"

        summary_messages = [
            {"role": "system", "content": "You are a summarization assistant. Be concise."},
            {"role": "user", "content": summary_prompt},
        ]

        summary = await self.llm.generate_response(summary_messages, temperature=0.3)

        # Store summary
        conversation.summary = summary
        await self.db.flush()

        return summary
