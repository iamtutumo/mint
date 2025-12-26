from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, HttpUrl
from datetime import datetime

class DocumentType(str, Enum):
    INVOICE = "invoice"
    RECEIPT = "receipt"
    QUOTE = "quote"
    CONTRACT = "contract"
    PROPOSAL = "proposal"
    REPORT = "report"
    OTHER = "other"

class DocumentStatus(str, Enum):
    DRAFT = "draft"
    SENT = "sent"
    VIEWED = "viewed"
    APPROVED = "approved"
    REJECTED = "rejected"
    PAID = "paid"
    OVERDUE = "overdue"
    VOID = "void"

class DocumentBase(BaseModel):
    title: str = Field(..., max_length=200)
    document_type: DocumentType
    status: DocumentStatus = DocumentStatus.DRAFT
    reference_number: Optional[str] = None
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    amount: Optional[float] = None
    currency: str = "USD"
    metadata: Optional[Dict[str, Any]] = None
    tags: List[str] = []
    is_archived: bool = False

class DocumentCreate(DocumentBase):
    template_id: Optional[str] = None
    template_data: Optional[Dict[str, Any]] = None

class DocumentUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    status: Optional[DocumentStatus] = None
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    amount: Optional[float] = None
    metadata: Optional[Dict[str, Any]] = None
    tags: Optional[List[str]] = None
    is_archived: Optional[bool] = None

class Document(DocumentBase):
    id: str
    file_url: Optional[HttpUrl] = None
    file_path: Optional[str] = None
    file_name: Optional[str] = None
    file_size: Optional[int] = None
    mime_type: Optional[str] = None
    created_by: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class DocumentList(BaseModel):
    items: List[Document]
    total: int
    page: int
    size: int
    pages: int

class DocumentTemplateBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    template_type: DocumentType
    content: str
    variables: List[str] = []
    is_active: bool = True
    metadata: Optional[Dict[str, Any]] = None

class DocumentTemplateCreate(DocumentTemplateBase):
    pass

class DocumentTemplateUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    content: Optional[str] = None
    variables: Optional[List[str]] = None
    is_active: Optional[bool] = None
    metadata: Optional[Dict[str, Any]] = None

class DocumentTemplate(DocumentTemplateBase):
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
