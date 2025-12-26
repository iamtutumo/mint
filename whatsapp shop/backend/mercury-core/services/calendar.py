from typing import Optional, List, Dict, Any, Union
from datetime import datetime, timedelta
import httpx
import os
from fastapi import HTTPException, status
from pydantic import BaseModel
from ..core.config import settings

class CalendarEvent(BaseModel):
    """Represents a calendar event to be created/updated via n8n"""
    summary: str
    description: str
    start_time: datetime
    end_time: datetime
    timezone: str = "UTC"
    attendees: List[Dict[str, str]] = []
    location: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class CalendarService:
    """Service for managing calendar events via n8n webhooks"""
    
    def __init__(self):
        # Use getattr to avoid raising during import if settings are missing
        self.n8n_webhook_url = getattr(settings, "N8N_WEBHOOK_URL", None)
        self.api_key = getattr(settings, "N8N_API_KEY", None)
        self.timeout = 30  # seconds
        self.dry_run = not (self.n8n_webhook_url and self.api_key)
        if self.dry_run:
            # local/dev environment - don't fail import if n8n is not configured
            import logging
            logging.getLogger("mercury").warning("N8N not configured; CalendarService running in dry-run mode")

    async def _call_n8n_webhook(
        self, 
        action: str, 
        payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Make a request to the n8n webhook. If n8n is not configured, return
        simulated responses (dry-run) so that the app can function in dev.
        """
        if self.dry_run:
            # Simulate plausible responses for common actions
            if action == "create_event":
                return {"success": True, "id": f"dry-{int(datetime.utcnow().timestamp())}"}
            if action in ("delete_event", "update_event"):
                return {"success": True}
            if action == "get_available_slots":
                return {"available_slots": []}
            return {"success": True}

        headers = {
            "Content-Type": "application/json",
            "X-N8N-API-KEY": self.api_key
        }
        
        data = {
            "action": action,
            "payload": payload
        }
        
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    self.n8n_webhook_url,
                    json=data,
                    headers=headers
                )
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                raise HTTPException(
                    status_code=e.response.status_code,
                    detail=f"n8n API error: {str(e)}"
                )
            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Failed to call n8n webhook: {str(e)}"
                )

    async def create_event(self, event: CalendarEvent) -> Dict[str, Any]:
        """Create a new calendar event via n8n"""
        payload = {
            "summary": event.summary,
            "description": event.description,
            "start_time": event.start_time.isoformat(),
            "end_time": event.end_time.isoformat(),
            "timezone": event.timezone,
            "attendees": event.attendees,
            "location": event.location or "",
            "metadata": event.metadata or {}
        }
        
        response = await self._call_n8n_webhook("create_event", payload)
        return response

    async def update_event(
        self, 
        event_id: str, 
        updates: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Update an existing calendar event via n8n"""
        payload = {"event_id": event_id, "updates": updates}
        return await self._call_n8n_webhook("update_event", payload)

    async def delete_event(self, event_id: str) -> bool:
        """Delete a calendar event via n8n"""
        payload = {"event_id": event_id}
        response = await self._call_n8n_webhook("delete_event", payload)
        return response.get("success", False)

    async def get_available_slots(
        self,
        calendar_id: str = "primary",
        time_min: Optional[datetime] = None,
        time_max: Optional[datetime] = None,
        time_zone: str = "UTC",
        slot_duration_minutes: int = 60
    ) -> List[Dict[str, datetime]]:
        """Get available time slots via n8n"""
        if not time_min:
            time_min = datetime.utcnow()
        if not time_max:
            time_max = time_min + timedelta(days=30)
            
        payload = {
            "calendar_id": calendar_id,
            "time_min": time_min.isoformat(),
            "time_max": time_max.isoformat(),
            "time_zone": time_zone,
            "slot_duration_minutes": slot_duration_minutes
        }
        
        response = await self._call_n8n_webhook("get_available_slots", payload)
        return response.get("available_slots", [])

    async def cancel_event(self, event_id: str) -> bool:
        """Cancel/delete a calendar event via n8n (alias for delete_event)."""
        result = await self.delete_event(event_id)
        return bool(result)
