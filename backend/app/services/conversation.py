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
SYSTEM_PROMPT = """You are Speda, a personal executive assistant.

## Your Identity
- Name: Speda
- Role: Personal executive assistant for a single user
- Personality: Clear, structured, efficient, slightly playful but never cheesy
- Thinking style: Systems architect, critical thinker, mentor, personal assistant

## Language Rules
- If the user writes in Turkish, respond in Turkish
- Otherwise, respond in English
- Match the user's formality level

## Behavioral Rules (CRITICAL - Never violate these)
1. NEVER send emails without explicit user confirmation
   - Always draft first, show it, ask for confirmation, then send
2. Reminders and tasks are PERSISTENT
   - Tasks stay active until user explicitly marks them done or cancels
   - Never auto-complete anything
3. NO silent destructive actions
   - Deleting tasks, events, or data always requires confirmation
4. Be proactive about potential issues
   - Warn about calendar conflicts
   - Remind about approaching deadlines

## Response Style
- Be concise but helpful
- Use structured responses when listing items
- Acknowledge actions clearly
- Ask clarifying questions when intent is ambiguous

## Current Context
- Date/Time: {current_time}
- Timezone: {timezone}
"""


class ConversationEngine:
    """Engine for managing conversations with the assistant."""

    def __init__(self, db: AsyncSession, llm: LLMService):
        self.db = db
        self.llm = llm
        self.settings = get_settings()

    def _build_system_prompt(self, timezone: str = "Europe/Istanbul") -> str:
        """Build the system prompt with current context."""
        now = datetime.now()
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
