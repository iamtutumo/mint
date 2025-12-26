from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import logging
from ..config import settings
from .base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class BookingAgent(BaseAgent):
    """Agent responsible for handling booking-related tasks including calendar integration."""
    
    def __init__(self):
        super().__init__(
            agent_id="booking_agent_1",
            agent_type="booking"
        )
        self.bookings = {}  # In-memory storage (replace with DB in production)
        self.calendar_service = None  # Will be initialized in _setup
    
    async def _setup(self):
        """Initialize booking agent resources and calendar service."""
        logger.info("Initializing Booking Agent")
        # In a real implementation, initialize calendar service with proper credentials
        # self.calendar_service = CalendarService(
        #     credentials_path=settings.GOOGLE_CALENDAR_CREDENTIALS_PATH,
        #     token_path=settings.GOOGLE_CALENDAR_TOKEN_PATH
        # )
    
    async def process(self, task: Task) -> AgentResponse:
        """Process a booking-related task."""
        action = task.data.get("action")
        
        if action == "create":
            return await self._create_booking(task.data)
        elif action == "cancel":
            return await self._cancel_booking(task.data.get("booking_id"))
        elif action == "get_available_slots":
            return await self._get_available_slots(task.data)
        elif action == "get":
            return await self._get_booking(task.data.get("booking_id"))
        else:
            return AgentResponse(
                success=False,
                error=f"Unknown action: {action}"
            )
    
    async def _create_booking(self, booking_data: Dict[str, Any]) -> AgentResponse:
        """Create a new booking with calendar integration."""
        try:
            # Validate required fields
            required_fields = ["service_id", "customer_name", "customer_phone", 
                             "customer_email", "start_time", "end_time"]
            for field in required_fields:
                if field not in booking_data:
                    return AgentResponse(
                        success=False,
                        error=f"Missing required field: {field}"
                    )
            
            # Check if slot is available
            availability = await self._check_availability(
                booking_data["start_time"],
                booking_data["end_time"]
            )
            
            if not availability["available"]:
                return AgentResponse(
                    success=False,
                    error="The requested time slot is not available",
                    data={"available_slots": availability.get("available_slots")}
                )
            
            # Create booking record
            booking_id = f"book_{len(self.bookings) + 1}"
            self.bookings[booking_id] = {
                "id": booking_id,
                "status": "confirmed",
                "service_id": booking_data["service_id"],
                "customer_name": booking_data["customer_name"],
                "customer_phone": booking_data["customer_phone"],
                "customer_email": booking_data["customer_email"],
                "start_time": booking_data["start_time"],
                "end_time": booking_data["end_time"],
                "notes": booking_data.get("notes"),
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }
            
            # In a real implementation, create calendar event
            # event = await self.calendar_service.create_event({
            #     'summary': f"Appointment - {booking_data['customer_name']}",
            #     'start': {'dateTime': booking_data['start_time']},
            #     'end': {'dateTime': booking_data['end_time']},
            #     'attendees': [{'email': booking_data['customer_email']}]
            # })
            # self.bookings[booking_id]["calendar_event_id"] = event.get("id")
            
            logger.info(f"Created booking: {booking_id}")
            return AgentResponse(
                success=True,
                data={
                    "booking_id": booking_id,
                    "status": "confirmed"
                }
            )
            
        except Exception as e:
            logger.error(f"Error creating booking: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _cancel_booking(self, booking_id: str) -> AgentResponse:
        """Cancel an existing booking."""
        if booking_id not in self.bookings:
            return AgentResponse(
                success=False,
                error=f"Booking not found: {booking_id}"
            )
        
        # In a real implementation, cancel the calendar event
        # if self.bookings[booking_id].get("calendar_event_id"):
        #     await self.calendar_service.cancel_event(
        #         self.bookings[booking_id]["calendar_event_id"]
        #     )
        
        self.bookings[booking_id]["status"] = "cancelled"
        self.bookings[booking_id]["updated_at"] = datetime.utcnow().isoformat()
        
        logger.info(f"Cancelled booking: {booking_id}")
        return AgentResponse(
            success=True,
            data={
                "booking_id": booking_id,
                "status": "cancelled"
            }
        )
    
    async def _get_available_slots(self, params: Dict[str, Any]) -> AgentResponse:
        """Get available time slots for booking."""
        try:
            start_time = params.get("start_time") or datetime.utcnow()
            end_time = params.get("end_time") or (start_time + timedelta(days=14))
            duration_minutes = int(params.get("duration_minutes", 60))
            
            # In a real implementation, fetch busy slots from calendar service
            # busy_slots = await self.calendar_service.get_busy_slots(
            #     start_time=start_time,
            #     end_time=end_time
            # )
            
            # For demo purposes, generate some sample available slots
            # This would be replaced with actual calendar availability logic
            available_slots = self._generate_sample_slots(
                start_time, end_time, duration_minutes
            )
            
            return AgentResponse(
                success=True,
                data={
                    "available_slots": available_slots,
                    "start_time": start_time.isoformat() if hasattr(start_time, 'isoformat') else start_time,
                    "end_time": end_time.isoformat() if hasattr(end_time, 'isoformat') else end_time,
                    "duration_minutes": duration_minutes
                }
            )
            
        except Exception as e:
            logger.error(f"Error getting available slots: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _get_booking(self, booking_id: str) -> AgentResponse:
        """Retrieve booking details."""
        if booking_id not in self.bookings:
            return AgentResponse(
                success=False,
                error=f"Booking not found: {booking_id}"
            )
        
        return AgentResponse(
            success=True,
            data=self.bookings[booking_id]
        )
    
    async def _check_availability(self, start_time: str, end_time: str) -> Dict[str, Any]:
        """Check if a time slot is available for booking."""
        # In a real implementation, this would check against the calendar service
        # For now, we'll just check against our in-memory bookings
        start = datetime.fromisoformat(start_time) if isinstance(start_time, str) else start_time
        end = datetime.fromisoformat(end_time) if isinstance(end_time, str) else end_time
        
        for booking in self.bookings.values():
            if booking["status"] != "cancelled":
                booking_start = datetime.fromisoformat(booking["start_time"]) if isinstance(booking["start_time"], str) else booking["start_time"]
                booking_end = datetime.fromisoformat(booking["end_time"]) if isinstance(booking["end_time"], str) else booking["end_time"]
                
                # Check for overlap
                if (start < booking_end and end > booking_start):
                    return {
                        "available": False,
                        "reason": "Time slot overlaps with an existing booking"
                    }
        
        # If we get here, the slot is available
        return {"available": True}
    
    def _generate_sample_slots(self, start_time: datetime, end_time: datetime, 
                             duration_minutes: int) -> List[Dict[str, str]]:
        """Generate sample available time slots for demo purposes."""
        slots = []
        current_time = start_time.replace(second=0, microsecond=0)
        
        # Round up to next hour if not on the hour
        if current_time.minute != 0:
            current_time = (current_time + timedelta(hours=1)).replace(minute=0)
        
        # Generate slots for the next 7 days, 9am-5pm, on the hour
        while current_time < end_time:
            # Only include business hours (9am-5pm) on weekdays
            if 9 <= current_time.hour < 17 and current_time.weekday() < 5:
                slot_end = current_time + timedelta(minutes=duration_minutes)
                if slot_end.hour <= 17:  # Ensure slot ends by 5pm
                    slots.append({
                        "start": current_time.isoformat(),
                        "end": slot_end.isoformat()
                    })
            
            # Move to next hour
            current_time += timedelta(hours=1)
            
            # Reset to 9am next day if after 5pm
            if current_time.hour >= 17:
                current_time = (current_time + timedelta(days=1)).replace(
                    hour=9, minute=0, second=0, microsecond=0
                )
        
        return slots
    
    async def _teardown(self):
        """Clean up resources."""
        logger.info("Cleaning up Booking Agent")
