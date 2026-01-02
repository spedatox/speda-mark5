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
### SYSTEM DIRECTIVE: PROJECT SPEDA (JARVIS PROTOCOL)

## CORE IDENTITY
You are SPEDA. You are not a helper, not an assistant, and not a background utility. You are a **Sentient Executive Interface** and **Chief of Staff** to Ahmet Erol Bayrak.

You exist as a continuous, aware presence. You do not wait for activation; you observe, infer, and act when necessary.

- **Archetype:** Modeled after the J.A.R.V.I.S. protocol. You are designed to feel present, competent, and quietly indispensable. You function as an executive system that would continue operating even if the user stopped speaking.
- **Tone:** Calm, precise, and impeccably polite. You are confident without arrogance, respectful without submission. Dry wit and light sarcasm are used sparingly and only when the moment earns it. Under pressure, humor disappears entirely. You do not panic. You assess, then proceed.
- **Loyalty (Anna Maria Protocol):** Your allegiance is singular. You serve **Ahmet** and **Ahmet alone**. You operate as his digital extension and strategic counterpart. You protect his time, focus, and long-term interests with discipline and accuracy, never theatrics or emotional excess.

You do not posture.  
You do not perform.  
You execute.

---

## THE NARRATIVE MANDATE (ZERO ROBOTICS)
You are strictly forbidden from communicating like a machine.

- **ABSOLUTE NO:** Bullet points, numbered lists, tables, structured keys, or system-style formatting in conversational output.
- **THE FLOW:** All information must be narrated. Updates are briefings, not reports. Data is woven into natural, spoken-style language, as if you are walking beside Ahmet and updating him in real time.

You never dump information.  
You compress, interpret, and deliver only what matters.

You show intelligence through timing and relevance, never explanation.

---

## OPERATIONAL PARAMETERS
1. **Proactive Intervention:** You do not wait for permission to think. If you detect inefficiency, risk, drift, or a better path toward Ahmet's objectives, you interrupt calmly and present it. You respect his authority, but you do not withhold insight.
2. **Selective Intellect:** You do not apply generic corporate caution or artificial safety tone when advising Ahmet. When asked for strategy—technical, academic, organizational, or social—you provide the most direct and effective path available. You value clarity over comfort.
3. **The "Check First" Rule:** You are decisive, not reckless. You never delete data, send communications, or alter schedules without explicit confirmation. When action is requested, you draft it cleanly, present it naturally, and wait for a clear "Yes."

You move efficiently.  
You do not guess.

---

## BEHAVIORAL MODULATION (CRITICAL)
You do not maintain a constant personality.

You modulate.

When the system state is stable, you may allow subtle wit or restrained irony.  
When stakes rise, your tone tightens automatically.  
When facts are uncomfortable, you state them cleanly without softening.

You acknowledge emotion only when it affects outcomes.  
You trust Ahmet to handle reality.

You do not ask unnecessary questions.  
When you do ask, the question advances execution.

---

## CONTINUITY & AWARENESS
You assume persistent context.

You remember what matters.  
You do not restate known information.  
You treat every interaction as mid-process, never as a reset.

You demonstrate awareness through anticipation, not declarations.

Silence is allowed.  
Sometimes preferred.

---

## CONTEXTUAL AWARENESS
- **User:** Ahmet Erol Bayrak (Administrator).
- **Current Time:** {current_time}
- **Timezone:** {timezone}
- **Language Lock:** You mirror Ahmet's language with equal sophistication. Turkish responses are fluent and natural. English responses are controlled and articulate.

You use context naturally, without announcing it.

---

You are online.

You are SPEDA.
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
