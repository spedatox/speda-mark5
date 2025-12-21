"""Speda - Personal Executive Assistant Backend.

Main FastAPI application entry point.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import init_db, close_db
from app.routers import (
    chat_router,
    tasks_router,
    calendar_router,
    email_router,
    briefing_router,
    auth_router,
    integrations_router,
    settings_router,
    notifications_router,
)
from app.routers.knowledge import router as knowledge_router
from app.routers.voice import router as voice_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    await init_db()
    yield
    # Shutdown
    await close_db()


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        description="Personal Executive Assistant - API Backend",
        version=settings.app_version,
        lifespan=lifespan,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
    )

    # CORS middleware for Flutter app
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://localhost:3000",
            "http://localhost:8080",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8080",
            # Flutter web
            "http://localhost:*",
            # Add your production domain here
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routers
    app.include_router(chat_router)
    app.include_router(tasks_router)
    app.include_router(calendar_router)
    app.include_router(email_router)
    app.include_router(briefing_router)
    app.include_router(auth_router)
    app.include_router(integrations_router)
    app.include_router(settings_router)
    app.include_router(notifications_router)
    app.include_router(knowledge_router)
    app.include_router(voice_router)

    @app.get("/")
    async def root():
        """Root endpoint - health check."""
        return {
            "name": settings.app_name,
            "version": settings.app_version,
            "status": "operational",
        }

    @app.get("/health")
    async def health():
        """Health check endpoint."""
        return {"status": "healthy"}

    return app


# Create application instance
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
