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
        self.n8n_webhook_url = settings.N8N_WEBHOOK_URL
        self.api_key = settings.N8N_API_KEY
        self.timeout = 30  # seconds

    async def _call_n8n_webhook(
        self, 
        action: str, 
        payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Make a request to the n8n webhook
        
        Args:
            action: The calendar action to perform (create, update, delete, list)
            payload: The payload for the action
            
        Returns:
            Dict containing the response from n8n
        """
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

    async def create_event(self, event: CalendarEvent) -> Dict[str, Any]:
        """Create a new calendar event"""
        event_body = {
            'summary': event.summary,
            'description': event.description,
            'start': {
                'dateTime': event.start_time.isoformat(),
                'timeZone': event.timezone,
            },
            'end': {
                'dateTime': event.end_time.isoformat(),
                'timeZone': event.timezone,
            },
            'attendees': event.attendees,
            'reminders': {
                'useDefault': True,
            },
        }
        
        if event.location:
            event_body['location'] = event.location
        
        try:
            event_result = self.service.events().insert(
                calendarId='primary',
                body=event_body,
                sendUpdates='all'
            ).execute()
            return event_result
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create calendar event: {str(e)}"
            )

    async def get_available_slots(
        self, 
        calendar_id: str = 'primary',
        time_min: Optional[datetime] = None,
        time_max: Optional[datetime] = None,
        time_zone: str = 'UTC',
        slot_duration_minutes: int = 60
    ) -> List[Dict[str, datetime]]:
        """Get available time slots for booking"""
        if not time_min:
            time_min = datetime.utcnow()
        if not time_max:
            time_max = time_min + timedelta(days=30)
            
        try:
            # Get busy time slots
            freebusy_result = self.service.freebusy().query(
                body={
                    "timeMin": time_min.isoformat() + 'Z',
                    "timeMax": time_max.isoformat() + 'Z',
                    "timeZone": time_zone,
                    "items": [{"id": calendar_id}]
                }
            ).execute()
            
            busy_slots = freebusy_result.get('calendars', {}).get(calendar_id, {}).get('busy', [])
            
            # Generate all possible slots
            all_slots = []
            current_time = time_min
            slot_duration = timedelta(minutes=slot_duration_minutes)
            
            while current_time + slot_duration <= time_max:
                slot_end = current_time + slot_duration
                all_slots.append((current_time, slot_end))
                current_time = slot_end
            
            # Filter out busy slots
            available_slots = []
            for slot_start, slot_end in all_slots:
                slot_is_available = True
                for busy in busy_slots:
                    busy_start = datetime.fromisoformat(busy['start'].replace('Z', '+00:00'))
                    busy_end = datetime.fromisoformat(busy['end'].replace('Z', '+00:00'))
                    
                    # Check for overlap
                    if not (slot_end <= busy_start or slot_start >= busy_end):
                        slot_is_available = False
                        break
                
                if slot_is_available:
                    available_slots.append({
                        'start': slot_start,
                        'end': slot_end
                    })
            
            return available_slots
            
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to fetch available slots: {str(e)}"
            )

    async def update_event(self, event_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Update an existing calendar event"""
        try:
            event = self.service.events().get(calendarId='primary', eventId=event_id).execute()
            
            # Apply updates
            for key, value in updates.items():
                if key in event:
                    event[key] = value
            
            updated_event = self.service.events().update(
                calendarId='primary',
                eventId=event_id,
                body=event,
                sendUpdates='all'
            ).execute()
            
            return updated_event
            
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update calendar event: {str(e)}"
            )

    async def cancel_event(self, event_id: str) -> bool:
        """Cancel/delete a calendar event"""
        try:
            self.service.events().delete(
                calendarId='primary',
                eventId=event_id,
                sendUpdates='all'
            ).execute()
            return True
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to cancel calendar event: {str(e)}"
            )
