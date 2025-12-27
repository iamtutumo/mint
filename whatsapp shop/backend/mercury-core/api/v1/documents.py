from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from app.db.session import get_db
from app.models.document import Document, DocumentType
from app.schemas.document import DocumentCreate, DocumentUpdate, DocumentBase
from app.services.document import DocumentService
from app.core.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/documents", tags=["documents"])

@router.get("/", response_model=List[dict])
async def get_documents(
    skip: int = 0,
    limit: int = 100,
    document_type: Optional[DocumentType] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all documents with optional filtering"""
    query = db.query(Document)
    if document_type:
        query = query.filter(Document.document_type == document_type)
    documents = query.offset(skip).limit(limit).all()
    return [
        {
            "id": doc.id,
            "document_number": doc.document_number,
            "document_type": doc.document_type,
            "file_path": doc.file_path,
            "file_url": doc.file_url,
            "created_at": doc.created_at,
            "updated_at": doc.updated_at
        }
        for doc in documents
    ]

@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_document(
    document: DocumentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new document"""
    # Generate document number
    import uuid
    document_number = f"DOC-{uuid.uuid4().hex[:8].upper()}"
    
    db_document = Document(
        document_number=document_number,
        document_type=document.document_type,
        file_path="",  # Will be set when file is uploaded
        file_url=None
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    
    return {
        "id": db_document.id,
        "document_number": db_document.document_number,
        "document_type": db_document.document_type,
        "file_path": db_document.file_path,
        "created_at": db_document.created_at
    }

@router.get("/{document_id}", response_model=dict)
async def get_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific document by ID"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    return {
        "id": document.id,
        "document_number": document.document_number,
        "document_type": document.document_type,
        "file_path": document.file_path,
        "file_url": document.file_url,
        "created_at": document.created_at,
        "updated_at": document.updated_at
    }

@router.put("/{document_id}", response_model=dict)
async def update_document(
    document_id: int,
    document_update: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a document"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Update fields
    for field, value in document_update.dict(exclude_unset=True).items():
        setattr(document, field, value)
    
    db.commit()
    db.refresh(document)
    
    return {
        "id": document.id,
        "document_number": document.document_number,
        "document_type": document.document_type,
        "file_path": document.file_path,
        "file_url": document.file_url,
        "updated_at": document.updated_at
    }

@router.delete("/{document_id}")
async def delete_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a document"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    db.delete(document)
    db.commit()
    
    return {"message": "Document deleted successfully"}

@router.post("/{document_id}/upload", response_model=dict)
async def upload_document_file(
    document_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Upload a file for a document"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # In a real implementation, save the file to storage
    # For now, just update the file_path
    document.file_path = f"documents/{document_id}/{file.filename}"
    db.commit()
    
    return {
        "message": "File uploaded successfully",
        "file_path": document.file_path
    }