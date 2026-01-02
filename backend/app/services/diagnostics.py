"""Diagnostics Service - System and AI configuration monitoring."""

import psutil
import platform

from app.config import get_settings


class DiagnosticsService:
    """Service for retrieving system metrics and AI configuration."""
    
    @staticmethod
    def get_system_metrics() -> dict:
        """Returns real-time server hardware statistics (CPU, RAM, Disk)."""
        try:
            vm = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            return {
                "success": True,
                "cpu_percent": round(psutil.cpu_percent(interval=0.1), 2),
                "memory": {
                    "total_gb": round(vm.total / (1024**3), 2),
                    "used_gb": round(vm.used / (1024**3), 2),
                    "percent": round(vm.percent, 2)
                },
                "disk": {
                    "total_gb": round(disk.total / (1024**3), 2),
                    "used_gb": round(disk.used / (1024**3), 2),
                    "free_gb": round(disk.free / (1024**3), 2),
                    "percent": round(disk.percent, 2)
                },
                "os": platform.system(),
                "platform": platform.platform()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to get system metrics: {str(e)}"
            }
    
    @staticmethod
    def get_ai_configuration() -> dict:
        """Returns the active AI model information."""
        try:
            settings = get_settings()
            return {
                "success": True,
                "provider": settings.llm_provider,
                "model_name": settings.openai_model,
                "base_url": settings.openai_base_url or "https://api.openai.com/v1",
                "api_version": "v1",
                "status": "Active" if settings.openai_api_key else "Not Configured",
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to get AI configuration: {str(e)}"
            }
