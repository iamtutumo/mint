from datetime import datetime
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field, HttpUrl

class BookingStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    NO_SHOW = "no_show"

class BookingBase(BaseModel):
    customer_id: str
    service_id: str
    start_time: datetime
    end_time: datetime
    notes: Optional[str] = None
    status: BookingStatus = BookingStatus.PENDING

class BookingCreate(BookingBase):
    pass

class BookingUpdate(BaseModel):
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    status: Optional[BookingStatus] = None
    notes: Optional[str] = None

class BookingResponse(BookingBase):
    id: str
    created_at: datetime
    updated_at: datetime
    calendar_event_id: Optional[str] = None
    meeting_link: Optional[HttpUrl] = None
    
    class Config:
        from_attributes = True

class BookingList(BaseModel):
    items: List[BookingResponse]
    total: int
    page: int
    size: int
    pages: int
