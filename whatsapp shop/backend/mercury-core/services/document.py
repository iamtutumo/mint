from sqlalchemy.orm import Session
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML, CSS
from pypdf import PdfReader, PdfWriter
import uuid
import io
from datetime import datetime
from typing import Optional
from pathlib import Path

from app.models.document import Document, DocumentType
from app.documents.storage import MinIOStorage
from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

class DocumentService:
    
    def __init__(self):
        template_dir = Path(__file__).parent.parent / "templates" / "html"
        self.jinja_env = Environment(loader=FileSystemLoader(str(template_dir)))
        self.storage = MinIOStorage()
    
    def generate_pdf(
        self,
        template_name: str,
        context: dict,
        password: Optional[str] = None
    ) -> bytes:
        """Generate PDF from HTML template"""
        
        # Render HTML
        template = self.jinja_env.get_template(template_name)
        html_content = template.render(**context)
        
        # Convert to PDF
        pdf_bytes = HTML(string=html_content).write_pdf()
        
        # Apply password protection if needed
        if password or settings.PDF_PASSWORD_PROTECTION:
            pdf_password = password or settings.PDF_DEFAULT_PASSWORD
            if pdf_password:
                pdf_bytes = self._protect_pdf(pdf_bytes, pdf_password)
        
        return pdf_bytes
    
    def _protect_pdf(self, pdf_bytes: bytes, password: str) -> bytes:
        """Apply password protection to PDF"""
        
        reader = PdfReader(io.BytesIO(pdf_bytes))
        writer = PdfWriter()
        
        for page in reader.pages:
            writer.add_page(page)
        
        writer.encrypt(user_password=password, owner_password=password, algorithm="AES-256")
        
        output = io.BytesIO()
        writer.write(output)
        output.seek(0)
        
        return output.read()
    
    def create_invoice(
        self,
        db: Session,
        order_id: int,
        password: Optional[str] = None
    ) -> Document:
        """Generate invoice for order"""
        
        from app.models.order import Order
        
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise ValueError("Order not found")
        
        context = {
            "order": order,
            "customer": order.customer,
            "items": order.items,
            "generated_at": datetime.now(),
            "invoice_number": f"INV-{order.order_number}"
        }
        
        pdf_bytes = self.generate_pdf("invoice.html", context, password)
        
        # Store in MinIO
        doc_number = f"INV-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        file_path = f"invoices/{doc_number}.pdf"
        
        file_url = self.storage.upload(
            bucket=settings.MINIO_BUCKET_DOCUMENTS,
            object_name=file_path,
            data=pdf_bytes,
            content_type="application/pdf"
        )
        
        # Save document record
        document = Document(
            document_number=doc_number,
            document_type=DocumentType.INVOICE,
            file_path=file_path,
            file_url=file_url,
            is_password_protected=bool(password),
            order_id=order_id,
            customer_id=order.customer_id
        )
        
        db.add(document)
        db.commit()
        db.refresh(document)
        
        logger.info(f"Invoice generated: {doc_number}")
        return document
    
    def create_receipt(
        self,
        db: Session,
        payment_id: int,
        password: Optional[str] = None
    ) -> Document:
        """Generate payment receipt"""
        
        from app.models.payment import Payment
        
        payment = db.query(Payment).filter(Payment.id == payment_id).first()
        if not payment:
            raise ValueError("Payment not found")
        
        context = {
            "payment": payment,
            "order": payment.order,
            "customer": payment.order.customer,
            "generated_at": datetime.now(),
            "receipt_number": f"RCP-{payment.payment_reference}"
        }
        
        pdf_bytes = self.generate_pdf("receipt.html", context, password)
        
        doc_number = f"RCP-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        file_path = f"receipts/{doc_number}.pdf"
        
        file_url = self.storage.upload(
            bucket=settings.MINIO_BUCKET_DOCUMENTS,
            object_name=file_path,
            data=pdf_bytes,
            content_type="application/pdf"
        )
        
        document = Document(
            document_number=doc_number,
            document_type=DocumentType.RECEIPT,
            file_path=file_path,
            file_url=file_url,
            is_password_protected=bool(password),
            order_id=payment.order_id,
            customer_id=payment.order.customer_id
        )
        
        db.add(document)
        db.commit()
        db.refresh(document)
        
        logger.info(f"Receipt generated: {doc_number}")
        return document