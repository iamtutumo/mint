import os
from io import BytesIO
from typing import Dict, Any, Optional, Tuple
import logging
from datetime import datetime, timedelta
from fpdf import FPDF
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
import qrcode
from ..config import settings
from .base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class DocumentAgent(BaseAgent):
    """Agent responsible for generating and managing business documents."""
    
    def __init__(self):
        super().__init__(
            agent_id="document_agent_1",
            agent_type="document"
        )
        self.storage_path = getattr(settings, 'DOCUMENT_STORAGE_PATH', './documents')
        os.makedirs(self.storage_path, exist_ok=True)
    
    async def _setup(self):
        """Initialize document agent resources."""
        logger.info("Initializing Document Agent")
    
    async def process(self, task: Task) -> AgentResponse:
        """Process a document-related task."""
        action = task.data.get("action")
        
        if action == "generate_invoice":
            return await self._generate_invoice(task.data)
        elif action == "generate_receipt":
            return await self._generate_receipt(task.data)
        elif action == "generate_packing_slip":
            return await self._generate_packing_slip(task.data)
        elif action == "generate_qr_code":
            return await self._generate_qr_code(task.data)
        else:
            return AgentResponse(
                success=False,
                error=f"Unknown action: {action}"
            )
    
    async def _generate_invoice(self, data: Dict[str, Any]) -> AgentResponse:
        """Generate an invoice PDF document."""
        try:
            invoice_number = data.get("invoice_number", f"INV-{datetime.now().strftime('%Y%m%d')}-{os.urandom(2).hex()}")
            customer = data.get("customer", {})
            items = data.get("items", [])
            company = data.get("company", {})
            due_date = data.get("due_date", (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d"))
            
            # Calculate totals
            subtotal = sum(float(item.get("price", 0)) * int(item.get("quantity", 1)) for item in items)
            tax = subtotal * 0.1  # 10% tax for example
            total = subtotal + tax
            
            # Create PDF
            pdf = FPDF()
            pdf.add_page()
            
            # Add header
            pdf.set_font('Arial', 'B', 16)
            pdf.cell(0, 10, 'INVOICE', 0, 1, 'C')
            pdf.ln(10)
            
            # Company and customer info
            pdf.set_font('Arial', '', 10)
            self._add_two_column(pdf, "From:", company.get("name", "Your Company Name"), 40)
            self._add_two_column(pdf, "To:", customer.get("name", "Customer Name"), 40)
            self._add_two_column(pdf, "Invoice #:", invoice_number, 40)
            self._add_two_column(pdf, "Date:", datetime.now().strftime("%Y-%m-%d"), 40)
            self._add_two_column(pdf, "Due Date:", due_date, 40)
            pdf.ln(10)
            
            # Items table
            self._add_table_header(pdf, ["Description", "Qty", "Unit Price", "Amount"])
            
            for item in items:
                self._add_table_row(pdf, [
                    item.get("description", ""),
                    str(item.get("quantity", 1)),
                    f"${float(item.get('price', 0)):.2f}",
                    f"${float(item.get('price', 0)) * int(item.get('quantity', 1)):.2f}"
                ])
            
            # Totals
            pdf.ln(10)
            self._add_two_column(pdf, "Subtotal:", f"${subtotal:.2f}", 150)
            self._add_two_column(pdf, "Tax (10%):", f"${tax:.2f}", 150)
            pdf.set_font('Arial', 'B', 12)
            self._add_two_column(pdf, "TOTAL:", f"${total:.2f}", 150)
            
            # Terms and conditions
            pdf.set_font('Arial', '', 8)
            pdf.ln(20)
            pdf.multi_cell(0, 5, "Terms & Conditions:\nPayment is due within 30 days. Please include the invoice number in your payment.")
            
            # Save the PDF
            filename = f"invoice_{invoice_number}.pdf"
            filepath = os.path.join(self.storage_path, filename)
            pdf.output(filepath)
            
            logger.info(f"Generated invoice: {filename}")
            return AgentResponse(
                success=True,
                data={
                    "document_type": "invoice",
                    "filename": filename,
                    "filepath": filepath,
                    "download_url": f"/documents/{filename}",
                    "metadata": {
                        "invoice_number": invoice_number,
                        "customer": customer.get("name"),
                        "total": total,
                        "due_date": due_date
                    }
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating invoice: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _generate_receipt(self, data: Dict[str, Any]) -> AgentResponse:
        """Generate a receipt PDF document."""
        try:
            receipt_number = data.get("receipt_number", f"RCPT-{datetime.now().strftime('%Y%m%d')}-{os.urandom(2).hex()}")
            payment = data.get("payment", {})
            items = data.get("items", [])
            company = data.get("company", {})
            
            # Calculate total
            total = sum(float(item.get("price", 0)) * int(item.get("quantity", 1)) for item in items)
            
            # Create PDF
            pdf = FPDF()
            pdf.add_page()
            
            # Add header
            pdf.set_font('Arial', 'B', 16)
            pdf.cell(0, 10, 'PAYMENT RECEIPT', 0, 1, 'C')
            pdf.ln(10)
            
            # Company and receipt info
            pdf.set_font('Arial', '', 10)
            self._add_two_column(pdf, "From:", company.get("name", "Your Company Name"), 40)
            self._add_two_column(pdf, "Receipt #:", receipt_number, 40)
            self._add_two_column(pdf, "Date:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"), 40)
            self._add_two_column(pdf, "Payment Method:", payment.get("method", "Credit Card"), 40)
            self._add_two_column(pdf, "Reference:", payment.get("reference", ""), 40)
            pdf.ln(10)
            
            # Items table
            self._add_table_header(pdf, ["Description", "Qty", "Unit Price", "Amount"])
            
            for item in items:
                self._add_table_row(pdf, [
                    item.get("description", ""),
                    str(item.get("quantity", 1)),
                    f"${float(item.get('price', 0)):.2f}",
                    f"${float(item.get('price', 0)) * int(item.get('quantity', 1)):.2f}"
                ])
            
            # Total
            pdf.ln(10)
            pdf.set_font('Arial', 'B', 12)
            self._add_two_column(pdf, "TOTAL PAID:", f"${total:.2f}", 150)
            
            # Thank you message
            pdf.set_font('Arial', '', 10)
            pdf.ln(20)
            pdf.multi_cell(0, 5, "Thank you for your business!")
            
            # Save the PDF
            filename = f"receipt_{receipt_number}.pdf"
            filepath = os.path.join(self.storage_path, filename)
            pdf.output(filepath)
            
            logger.info(f"Generated receipt: {filename}")
            return AgentResponse(
                success=True,
                data={
                    "document_type": "receipt",
                    "filename": filename,
                    "filepath": filepath,
                    "download_url": f"/documents/{filename}",
                    "metadata": {
                        "receipt_number": receipt_number,
                        "amount": total,
                        "payment_method": payment.get("method"),
                        "date": datetime.now().isoformat()
                    }
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating receipt: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _generate_packing_slip(self, data: Dict[str, Any]) -> AgentResponse:
        """Generate a packing slip PDF document."""
        try:
            order_number = data.get("order_number", f"ORD-{datetime.now().strftime('%Y%m%d')}-{os.urandom(2).hex()}")
            customer = data.get("customer", {})
            items = data.get("items", [])
            shipping = data.get("shipping", {})
            company = data.get("company", {})
            
            # Create PDF
            pdf = FPDF()
            pdf.add_page()
            
            # Add header
            pdf.set_font('Arial', 'B', 16)
            pdf.cell(0, 10, 'PACKING SLIP', 0, 1, 'C')
            pdf.ln(10)
            
            # Company and order info
            pdf.set_font('Arial', '', 10)
            self._add_two_column(pdf, "From:", company.get("name", "Your Company Name"), 40)
            self._add_two_column(pdf, "Order #:", order_number, 40)
            self._add_two_column(pdf, "Date:", datetime.now().strftime("%Y-%m-%d"), 40)
            pdf.ln(5)
            
            # Shipping info
            pdf.set_font('Arial', 'B', 10)
            pdf.cell(0, 10, 'SHIP TO:', 0, 1)
            pdf.set_font('Arial', '', 10)
            pdf.multi_cell(0, 5, f"{customer.get('name', 'Customer Name')}\n"
                              f"{customer.get('address', '')}\n"
                              f"{customer.get('city', '')}, {customer.get('state', '')} {customer.get('zip', '')}\n"
                              f"{customer.get('country', '')}\n"
                              f"Phone: {customer.get('phone', '')}")
            
            # Shipping method
            pdf.ln(5)
            self._add_two_column(pdf, "Shipping Method:", shipping.get("method", "Standard Shipping"), 40)
            self._add_two_column(pdf, "Tracking #:", shipping.get("tracking_number", "Not available"), 40)
            
            # Items table
            pdf.ln(10)
            self._add_table_header(pdf, ["Item", "Description", "Qty"])
            
            for i, item in enumerate(items, 1):
                self._add_table_row(pdf, [
                    str(i),
                    item.get("description", ""),
                    str(item.get("quantity", 1))
                ])
            
            # Notes
            pdf.ln(10)
            pdf.set_font('Arial', 'B', 10)
            pdf.cell(0, 10, 'NOTES:', 0, 1)
            pdf.set_font('Arial', '', 10)
            pdf.multi_cell(0, 5, data.get("notes", "Thank you for your order!"))
            
            # Save the PDF
            filename = f"packing_slip_{order_number}.pdf"
            filepath = os.path.join(self.storage_path, filename)
            pdf.output(filepath)
            
            logger.info(f"Generated packing slip: {filename}")
            return AgentResponse(
                success=True,
                data={
                    "document_type": "packing_slip",
                    "filename": filename,
                    "filepath": filepath,
                    "download_url": f"/documents/{filename}",
                    "metadata": {
                        "order_number": order_number,
                        "customer": customer.get("name"),
                        "item_count": len(items),
                        "shipping_method": shipping.get("method")
                    }
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating packing slip: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _generate_qr_code(self, data: Dict[str, Any]) -> AgentResponse:
        """Generate a QR code image."""
        try:
            content = data.get("content")
            if not content:
                return AgentResponse(
                    success=False,
                    error="Content is required for QR code generation"
                )
            
            # Generate QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(content)
            qr.make(fit=True)
            
            # Create an image from the QR Code instance
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Save the image
            filename = f"qrcode_{hash(content) & 0xffffffff}.png"
            filepath = os.path.join(self.storage_path, filename)
            img.save(filepath)
            
            logger.info(f"Generated QR code: {filename}")
            return AgentResponse(
                success=True,
                data={
                    "filename": filename,
                    "filepath": filepath,
                    "download_url": f"/documents/{filename}",
                    "content": content
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating QR code: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    def _add_two_column(self, pdf, label: str, value: str, label_width: int = 30):
        """Helper method to add a two-column row to the PDF."""
        pdf.cell(label_width, 6, label, 0, 0)
        pdf.multi_cell(0, 6, str(value) if value is not None else "")
    
    def _add_table_header(self, pdf, headers: list, col_widths: list = None):
        """Helper method to add a table header row."""
        if col_widths is None:
            col_widths = [0] * len(headers)
            for i in range(len(headers)):
                col_widths[i] = 190 // len(headers)  # Distribute width evenly
        
        pdf.set_font('Arial', 'B', 10)
        for i, header in enumerate(headers):
            pdf.cell(col_widths[i], 7, header, 1, 0, 'C')
        pdf.ln()
    
    def _add_table_row(self, pdf, row_data: list, col_widths: list = None):
        """Helper method to add a table data row."""
        if col_widths is None:
            col_widths = [0] * len(row_data)
            for i in range(len(row_data)):
                col_widths[i] = 190 // len(row_data)  # Distribute width evenly
        
        pdf.set_font('Arial', '', 10)
        for i, cell in enumerate(row_data):
            pdf.cell(col_widths[i], 6, str(cell), 1, 0, 'L')
        pdf.ln()
    
    async def _teardown(self):
        """Clean up resources."""
        logger.info("Cleaning up Document Agent")
