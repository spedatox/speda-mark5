"""Memory Service - Long-term memory storage and retrieval."""

from typing import Optional

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Memory, Conversation, Message
from app.services.llm import LLMService


class MemoryService:
    """Service for managing long-term memory and key facts."""

    def __init__(self, db: AsyncSession, llm: Optional[LLMService] = None):
        self.db = db
        self.llm = llm

    async def store_memory(
        self,
        category: str,
        key: str,
        value: str,
        importance: int = 5,
    ) -> Memory:
        """Store a new memory or update existing one."""
        # Check if memory with same key exists
        result = await self.db.execute(
            select(Memory).where(Memory.category == category, Memory.key == key)
        )
        existing = result.scalar_one_or_none()

        if existing:
            existing.value = value
            existing.importance = importance
            await self.db.flush()
            return existing

        memory = Memory(
            category=category,
            key=key,
            value=value,
            importance=importance,
        )
        self.db.add(memory)
        await self.db.flush()
        return memory

    async def get_memory(self, category: str, key: str) -> Optional[Memory]:
        """Retrieve a specific memory."""
        result = await self.db.execute(
            select(Memory).where(Memory.category == category, Memory.key == key)
        )
        return result.scalar_one_or_none()

    async def get_memories_by_category(self, category: str) -> list[Memory]:
        """Get all memories in a category."""
        result = await self.db.execute(
            select(Memory)
            .where(Memory.category == category)
            .order_by(Memory.importance.desc())
        )
        return list(result.scalars().all())

    async def get_important_memories(self, min_importance: int = 7) -> list[Memory]:
        """Get high-importance memories across all categories."""
        result = await self.db.execute(
            select(Memory)
            .where(Memory.importance >= min_importance)
            .order_by(Memory.importance.desc())
        )
        return list(result.scalars().all())

    async def search_memories(self, query: str) -> list[Memory]:
        """Search memories by value content."""
        result = await self.db.execute(
            select(Memory)
            .where(Memory.value.ilike(f"%{query}%"))
            .order_by(Memory.importance.desc())
        )
        return list(result.scalars().all())

    async def delete_memory(self, memory_id: int) -> bool:
        """Delete a memory by ID."""
        result = await self.db.execute(
            delete(Memory).where(Memory.id == memory_id)
        )
        return result.rowcount > 0

    async def build_context_from_memory(self) -> str:
        """Build a context string from important memories for the LLM."""
        memories = await self.get_important_memories(min_importance=5)

        if not memories:
            return ""

        context_parts = ["## User Memory"]

        # Group by category
        categories: dict[str, list[Memory]] = {}
        for memory in memories:
            if memory.category not in categories:
                categories[memory.category] = []
            categories[memory.category].append(memory)

        for category, mems in categories.items():
            context_parts.append(f"\n### {category.title()}")
            for mem in mems:
                context_parts.append(f"- {mem.key}: {mem.value}")

        return "\n".join(context_parts)

    async def extract_and_store_facts(
        self,
        conversation_id: int,
    ) -> list[Memory]:
        """Extract key facts from conversation and store them."""
        if not self.llm:
            return []

        # Get conversation messages
        result = await self.db.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
        )
        messages = result.scalars().all()

        if len(messages) < 5:
            return []

        # Build conversation text
        conv_text = "\n".join(
            f"{msg.role}: {msg.content}" for msg in messages[-20:]
        )

        # Ask LLM to extract key facts
        extraction_prompt = """Analyze this conversation and extract any important facts about the user that should be remembered long-term. 

Focus on:
- Preferences (communication style, scheduling preferences)
- Important information (job, relationships, locations)
- Routines (wake time, work schedule)
- Key decisions made

Format each fact as:
CATEGORY|KEY|VALUE|IMPORTANCE(1-10)

Only include genuinely important facts. If nothing is worth remembering, respond with "NONE".

Conversation:
"""
        messages_for_llm = [
            {"role": "system", "content": "You extract key facts from conversations for long-term memory."},
            {"role": "user", "content": extraction_prompt + conv_text},
        ]

        response = await self.llm.generate_response(messages_for_llm, temperature=0.2)

        if response.strip() == "NONE":
            return []

        # Parse and store facts
        stored_memories = []
        for line in response.strip().split("\n"):
            parts = line.split("|")
            if len(parts) == 4:
                try:
                    category, key, value, importance = parts
                    memory = await self.store_memory(
                        category=category.strip().lower(),
                        key=key.strip(),
                        value=value.strip(),
                        importance=int(importance.strip()),
                    )
                    stored_memories.append(memory)
                except (ValueError, IndexError):
                    continue

        return stored_memories

    async def summarize_old_conversations(self) -> int:
        """Summarize old conversations and extract facts, then clean up."""
        # Get conversations without summaries that have many messages
        result = await self.db.execute(
            select(Conversation)
            .where(Conversation.summary.is_(None))
        )
        conversations = result.scalars().all()

        summarized_count = 0

        for conversation in conversations:
            # Count messages
            result = await self.db.execute(
                select(Message).where(Message.conversation_id == conversation.id)
            )
            messages = result.scalars().all()

            if len(messages) >= 50:
                # Extract facts
                await self.extract_and_store_facts(conversation.id)
                summarized_count += 1

        return summarized_count
