"""Chat API router."""

import json
from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.auth import verify_api_key
from app.schemas import ChatRequest, ChatResponse, Action, ActionType
from app.services.conversation import ConversationEngine
from app.services.memory import MemoryService
from app.services.task import TaskService
from app.services.calendar import CalendarService
from app.services.email import EmailService
from app.services.briefing import BriefingService
from app.services.llm import get_llm_service
from app.services.function_calling import FunctionExecutor, get_function_definitions
from app.schemas import TaskCreate, EventCreate, EmailDraft
from app.models import Conversation, Message

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    conversation_id: Optional[int] = Query(None, description="Continue existing conversation"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Process a chat message and return assistant response with actions."""
    llm = get_llm_service()
    conversation_engine = ConversationEngine(db, llm)
    memory_service = MemoryService(db, llm)
    task_service = TaskService(db)
    calendar_service = CalendarService(db)
    email_service = EmailService(db)
    briefing_service = BriefingService(db)

    # Build memory context
    memory_context = await memory_service.build_context_from_memory()

    # Process the message
    response, conversation, intent_info = await conversation_engine.process_message(
        user_message=request.message,
        timezone=request.timezone,
        conversation_id=conversation_id,
        additional_context=memory_context if memory_context else None,
    )

    # Handle intents and generate actions
    actions: list[Action] = []
    intent = intent_info.get("intent", "general_chat")

    # Process based on intent
    if intent == "briefing":
        # Generate briefing text and add to response
        briefing_text = await briefing_service.generate_text_briefing(request.timezone)
        response = briefing_text

    elif intent == "task_list":
        tasks = await task_service.list_pending_tasks()
        if tasks:
            task_list = "\n".join([
                f"• {t.title}" + (f" (due: {t.due_date.strftime('%b %d')})" if t.due_date else "")
                for t in tasks
            ])
            response = f"Here are your pending tasks:\n\n{task_list}"
        else:
            response = "You don't have any pending tasks."

    # Note: For task_create, calendar_create, email_draft intents,
    # we would need more sophisticated entity extraction.
    # In a real implementation, the LLM would extract the entities
    # and we would create the appropriate objects.
    # For now, these are handled through the direct API endpoints.

    return ChatResponse(
        reply=response,
        actions=actions,
        conversation_id=conversation.id,
    )


@router.post("/with-action", response_model=ChatResponse)
async def chat_with_action(
    request: ChatRequest,
    action_type: str = Query(..., description="Type of action to perform"),
    conversation_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Process a chat message with a specific action type.
    
    This endpoint is for when the frontend knows what action to take
    (e.g., from a button press) and wants to execute it through chat.
    """
    llm = get_llm_service()
    conversation_engine = ConversationEngine(db, llm)
    task_service = TaskService(db)
    briefing_service = BriefingService(db)

    actions: list[Action] = []

    if action_type == "briefing":
        briefing_text = await briefing_service.generate_text_briefing(request.timezone)
        response = briefing_text
    elif action_type == "list_tasks":
        tasks = await task_service.list_pending_tasks()
        if tasks:
            task_list = "\n".join([
                f"• {t.title}" + (f" (due: {t.due_date.strftime('%b %d')})" if t.due_date else "")
                for t in tasks
            ])
            response = f"Here are your pending tasks:\n\n{task_list}"
        else:
            response = "You don't have any pending tasks."
    else:
        # Default to regular chat processing
        response, conversation, _ = await conversation_engine.process_message(
            user_message=request.message,
            timezone=request.timezone,
            conversation_id=conversation_id,
        )
        return ChatResponse(
            reply=response,
            actions=actions,
            conversation_id=conversation.id,
        )

    # Get or create conversation for tracking
    conversation = await conversation_engine.get_or_create_conversation(conversation_id)
    await conversation_engine.add_message(conversation, "user", request.message)
    await conversation_engine.add_message(conversation, "assistant", response)

    return ChatResponse(
        reply=response,
        actions=actions,
        conversation_id=conversation.id,
    )


@router.post("/stream")
async def chat_stream(
    request: ChatRequest,
    conversation_id: Optional[int] = Query(None, description="Continue existing conversation"),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Stream a chat response using Server-Sent Events with function calling support."""
    llm = get_llm_service()
    conversation_engine = ConversationEngine(db, llm)
    memory_service = MemoryService(db, llm)
    function_executor = FunctionExecutor()
    functions = get_function_definitions()

    # Build memory context (stored facts)
    memory_context = await memory_service.build_context_from_memory()
    
    # Build recent conversations context (for continuity)
    recent_context = await memory_service.get_recent_conversations_context(limit=3)

    # Get or create conversation
    conversation = await conversation_engine.get_or_create_conversation(conversation_id)

    # Add user message
    await conversation_engine.add_message(conversation, "user", request.message)

    # Build context with current date
    from datetime import datetime, timedelta
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    
    system_prompt = conversation_engine._build_system_prompt(request.timezone)
    system_prompt += f"""

## Current Date Information
- Today's date: {today.strftime('%Y-%m-%d')} ({today.strftime('%A')})
- Tomorrow's date: {tomorrow.strftime('%Y-%m-%d')} ({tomorrow.strftime('%A')})
- Current time: {today.strftime('%H:%M')}

You have access to the following tools to help the user:

### Calendar & Tasks
- get_calendar_events: Check schedule and events (ALWAYS provide start_date and end_date)
- create_calendar_event: Create new calendar events
- get_tasks: List user's tasks
- create_task: Create new tasks
- complete_task: Mark tasks as done
- delete_task: Remove tasks

### Weather & News
- get_current_weather: Get current weather
- get_weather_forecast: Get weather forecast
- get_news_headlines: Get top news
- search_news: Search for specific news
- get_daily_briefing: Get comprehensive daily summary

### Knowledge Base (Memory)
- remember_info: Save information when user says "remember this", "hatırla", "bunu kaydet"
- search_memory: Search saved information when user asks "what do you know about...", "ne biliyorsun..."
- add_knowledge: Add structured knowledge with title for documentation/reference

IMPORTANT RULES:
1. DATE HANDLING:
   - "bugün/today" → start_date={today.strftime('%Y-%m-%d')}, end_date={today.strftime('%Y-%m-%d')}
   - "yarın/tomorrow" → start_date={tomorrow.strftime('%Y-%m-%d')}, end_date={tomorrow.strftime('%Y-%m-%d')}
   - Always calculate and provide exact dates

2. MEMORY:
   - When user says "remember this", "hatırla", "kaydet" → use remember_info
   - When user asks about previously saved info → use search_memory first
   - You remember previous conversations - use this context to maintain continuity

3. LANGUAGE: Respond in the same language as the user (Turkish or English)

After executing any function, provide a natural, conversational response."""

    # Add memory context (stored facts)
    if memory_context:
        system_prompt += f"\n\n{memory_context}"
    
    # Add recent conversations context
    if recent_context:
        system_prompt += f"\n\n{recent_context}"

    context_messages = await conversation_engine.get_context_messages(conversation)

    # Build full message list for LLM
    messages = [
        {"role": "system", "content": system_prompt},
        *context_messages,
    ]

    async def generate():
        full_response = ""
        # Send conversation_id first
        yield f"data: {json.dumps({'type': 'start', 'conversation_id': conversation.id})}\n\n"
        
        try:
            # First pass: check for function calls
            function_result = None
            print(f"[DEBUG] Starting stream with {len(functions)} functions available")
            async for event in llm.generate_with_functions_stream(messages, functions):
                print(f"[DEBUG] Received event: {event.get('type')}")
                if event["type"] == "function_call":
                    # Execute the function
                    func_name = event["name"]
                    func_args = event.get("arguments", {})
                    print(f"[DEBUG] Function call detected: {func_name} with args: {func_args}")
                    
                    # Notify frontend that we're executing a function
                    yield f"data: {json.dumps({'type': 'function_start', 'name': func_name})}\n\n"
                    
                    # Execute the function
                    result = await function_executor.execute(func_name, func_args)
                    function_result = {
                        "name": func_name,
                        "result": result,
                    }
                    
                    # Send function result to frontend
                    yield f"data: {json.dumps({'type': 'function_result', 'name': func_name, 'result': result})}\n\n"
                    break
                    
                elif event["type"] == "chunk":
                    full_response += event["content"]
                    yield f"data: {json.dumps({'type': 'chunk', 'content': event['content']})}\n\n"
                    
                elif event["type"] == "done":
                    pass
            
            # If we got a function result, generate a natural language response
            if function_result:
                # Add function result to messages and get a natural response
                messages.append({
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": function_result["name"],
                            "arguments": json.dumps(func_args),
                        }
                    }]
                })
                messages.append({
                    "role": "tool",
                    "tool_call_id": "call_1",
                    "content": json.dumps(function_result["result"]),
                })
                
                # Stream the follow-up response
                async for chunk in llm.generate_response_stream(messages):
                    full_response += chunk
                    yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n"
            
            # Save the complete response to database
            if full_response:
                await conversation_engine.add_message(conversation, "assistant", full_response)
                
                # Generate title for new conversations (when there's only user + assistant message)
                if conversation.title is None:
                    try:
                        title = await llm.generate_conversation_title(
                            request.message, 
                            full_response
                        )
                        conversation.title = title
                        yield f"data: {json.dumps({'type': 'title_generated', 'title': title})}\n\n"
                    except Exception as title_error:
                        print(f"Error generating title: {title_error}")
                        conversation.title = "Yeni Sohbet"
                
                await db.commit()
                
                # Extract and store facts periodically (every 10 messages in a conversation)
                try:
                    from sqlalchemy import func
                    msg_count_result = await db.execute(
                        select(func.count()).where(Message.conversation_id == conversation.id)
                    )
                    msg_count = msg_count_result.scalar() or 0
                    
                    # Extract facts every 10 messages
                    if msg_count > 0 and msg_count % 10 == 0:
                        await memory_service.extract_and_store_facts(conversation.id)
                        print(f"[MEMORY] Extracted facts from conversation {conversation.id}")
                except Exception as mem_error:
                    print(f"[MEMORY] Error extracting facts: {mem_error}")
            
            yield f"data: {json.dumps({'type': 'done', 'content': full_response})}\n\n"
        except Exception as e:
            import traceback
            traceback.print_exc()
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ==================== Conversation History ====================

@router.get("/conversations")
async def list_conversations(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """List all conversations with their first message as preview."""
    result = await db.execute(
        select(Conversation)
        .options(selectinload(Conversation.messages))
        .order_by(Conversation.started_at.desc())
        .limit(limit)
        .offset(offset)
    )
    conversations = result.scalars().all()

    return [
        {
            "id": conv.id,
            "title": conv.title or (conv.messages[0].content[:50] + "..." if conv.messages and len(conv.messages[0].content) > 50 else conv.messages[0].content if conv.messages else "Yeni Sohbet"),
            "started_at": conv.started_at.isoformat(),
            "preview": conv.messages[0].content[:100] if conv.messages else "New conversation",
            "message_count": len(conv.messages),
        }
        for conv in conversations
    ]


@router.get("/conversations/{conversation_id}")
async def get_conversation(
    conversation_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Get a specific conversation with all messages."""
    result = await db.execute(
        select(Conversation)
        .options(selectinload(Conversation.messages))
        .where(Conversation.id == conversation_id)
    )
    conversation = result.scalar_one_or_none()

    if not conversation:
        return {"error": "Conversation not found"}

    return {
        "id": conversation.id,
        "started_at": conversation.started_at.isoformat(),
        "messages": [
            {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat(),
            }
            for msg in sorted(conversation.messages, key=lambda m: m.created_at)
        ],
    }


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: int,
    db: AsyncSession = Depends(get_db),
    _auth: bool = Depends(verify_api_key),
):
    """Delete a conversation."""
    result = await db.execute(
        select(Conversation).where(Conversation.id == conversation_id)
    )
    conversation = result.scalar_one_or_none()

    if not conversation:
        return {"error": "Conversation not found"}

    await db.delete(conversation)
    await db.commit()

    return {"success": True, "message": "Conversation deleted"}
