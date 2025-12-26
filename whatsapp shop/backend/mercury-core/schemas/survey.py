from enum import Enum
from typing import List, Optional, Dict, Any, Union
from pydantic import BaseModel, Field, validator
from datetime import datetime

class QuestionType(str, Enum):
    TEXT = "text"
    MULTIPLE_CHOICE = "multiple_choice"
    CHECKBOX = "checkbox"
    DROPDOWN = "dropdown"
    RATING = "rating"
    DATE = "date"
    TIME = "time"
    DATETIME = "datetime"
    EMAIL = "email"
    PHONE = "phone"
    NUMBER = "number"

class SurveyStatus(str, Enum):
    DRAFT = "draft"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    ARCHIVED = "archived"

class QuestionOption(BaseModel):
    id: str
    text: str
    value: str
    order: int

class QuestionBase(BaseModel):
    title: str
    description: Optional[str] = None
    question_type: QuestionType
    is_required: bool = True
    order: int
    options: Optional[List[QuestionOption]] = None
    validation: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class QuestionCreate(QuestionBase):
    pass

class QuestionUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    question_type: Optional[QuestionType] = None
    is_required: Optional[bool] = None
    order: Optional[int] = None
    options: Optional[List[QuestionOption]] = None
    validation: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class Question(QuestionBase):
    id: str
    survey_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class SurveyBase(BaseModel):
    title: str
    description: Optional[str] = None
    status: SurveyStatus = SurveyStatus.DRAFT
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    is_anonymous: bool = True
    allow_resubmit: bool = False
    thank_you_message: Optional[str] = "Thank you for your response!"
    theme: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class SurveyCreate(SurveyBase):
    questions: List[QuestionCreate]

class SurveyUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[SurveyStatus] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    is_anonymous: Optional[bool] = None
    allow_resubmit: Optional[bool] = None
    thank_you_message: Optional[str] = None
    theme: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

class Survey(SurveyBase):
    id: str
    created_by: str
    created_at: datetime
    updated_at: datetime
    questions: List[Question] = []
    response_count: int = 0
    
    class Config:
        from_attributes = True

class SurveyResponseAnswer(BaseModel):
    question_id: str
    answer: Union[str, int, float, bool, List[str], Dict[str, Any]]

class SurveyResponseBase(BaseModel):
    survey_id: str
    respondent_email: Optional[str] = None
    respondent_name: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class SurveyResponseCreate(SurveyResponseBase):
    answers: List[SurveyResponseAnswer]

class SurveyResponse(SurveyResponseBase):
    id: str
    submitted_at: datetime
    time_spent_seconds: Optional[int] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    answers: List[Dict[str, Any]]
    
    class Config:
        from_attributes = True

class SurveyAnalytics(BaseModel):
    total_responses: int
    completion_rate: float
    average_time_spent: Optional[float] = None
    question_analytics: Dict[str, Dict[str, Any]] = {}
    date_analytics: Dict[str, int] = {}

class SurveyList(BaseModel):
    items: List[Survey]
    total: int
    page: int
    size: int
    pages: int
