import io
import logging
from pathlib import Path
from typing import Optional, Union, Tuple, BinaryIO
import PyPDF2
from PyPDF2 import PdfReader, PdfWriter

logger = logging.getLogger(__name__)

class DocumentSecurity:
    """Handle document security features like password protection and encryption."""
    
    @staticmethod
    def encrypt_pdf(
        input_pdf: Union[str, Path, BinaryIO, bytes],
        password: str,
        owner_password: Optional[str] = None,
        permissions: Optional[list] = None,
        algorithm: str = 'AES-256'
    ) -> bytes:
        """Encrypt a PDF with a password.
        
        Args:
            input_pdf: Input PDF as file path, file-like object, or bytes
            password: User password for the PDF
            owner_password: Owner password (defaults to user password if None)
            permissions: List of permissions to restrict (e.g., ['print', 'modify'])
            algorithm: Encryption algorithm ('AES-256' or 'RC4-128')
            
        Returns:
            Encrypted PDF as bytes
        """
        if isinstance(input_pdf, (str, Path)):
            with open(input_pdf, 'rb') as f:
                reader = PdfReader(f)
                writer = PyPDF2.PdfWriter()
                writer.append_pages_from_reader(reader)
        elif hasattr(input_pdf, 'read'):
            reader = PdfReader(input_pdf)
            writer = PyPDF2.PdfWriter()
            writer.append_pages_from_reader(reader)
        elif isinstance(input_pdf, bytes):
            reader = PdfReader(io.BytesIO(input_pdf))
            writer = PyPDF2.PdfWriter()
            writer.append_pages_from_reader(reader)
        else:
            raise ValueError("input_pdf must be a file path, file-like object, or bytes")
        
        # Set owner password to user password if not provided
        owner_password = owner_password or password
        
        # Set up permissions
        permissions_value = 0
        if permissions:
            permission_mapping = {
                'print': PyPDF2._writer.PRINT,
                'modify': PyPDF2._writer.MODIFY,
                'copy': PyPDF2._writer.COPY,
                'annotate': PyPDF2._writer.ANNOTATE,
                'forms': PyPDF2._writer.FILL_FORMS,
                'extract': PyPDF2._writer.EXTRACT,
                'assemble': PyPDF2._writer.ASSEMBLE,
                'print_highres': PyPDF2._writer.PRINT_HIGH_RESOLUTION
            }
            for perm in permissions:
                if perm in permission_mapping:
                    permissions_value |= permission_mapping[perm]
        
        # Encrypt the PDF
        if algorithm.upper() == 'AES-256':
            writer.encrypt(
                user_password=password,
                owner_password=owner_password,
                use_128bit=False,  # Use 256-bit encryption
                permissions=permissions_value if permissions else None
            )
        else:  # Default to RC4-128 for compatibility
            writer.encrypt(
                user_password=password,
                owner_password=owner_password,
                use_128bit=True,
                permissions=permissions_value if permissions else None
            )
        
        # Write to a bytes buffer
        output = io.BytesIO()
        writer.write(output)
        return output.getvalue()
    
    @staticmethod
    def is_password_protected(input_pdf: Union[str, Path, BinaryIO, bytes]) -> bool:
        """Check if a PDF is password protected."""
        try:
            if isinstance(input_pdf, (str, Path)):
                with open(input_pdf, 'rb') as f:
                    PyPDF2.PdfReader(f)
            elif hasattr(input_pdf, 'read'):
                PyPDF2.PdfReader(input_pdf)
            elif isinstance(input_pdf, bytes):
                PyPDF2.PdfReader(io.BytesIO(input_pdf))
            return False
        except PyPDF2.PdfReadError as e:
            if 'not opened with a password' in str(e):
                return True
            raise
    
    @staticmethod
    def remove_password(
        input_pdf: Union[str, Path, BinaryIO, bytes],
        password: str
    ) -> bytes:
        """Remove password protection from a PDF.
        
        Args:
            input_pdf: Input PDF as file path, file-like object, or bytes
            password: Password to decrypt the PDF
            
        Returns:
            Unencrypted PDF as bytes
        """
        if isinstance(input_pdf, (str, Path)):
            with open(input_pdf, 'rb') as f:
                reader = PyPDF2.PdfReader(f, password=password)
                writer = PyPDF2.PdfWriter()
                writer.append_pages_from_reader(reader)
        elif hasattr(input_pdf, 'read'):
            reader = PyPDF2.PdfReader(input_pdf, password=password)
            writer = PyPDF2.PdfWriter()
            writer.append_pages_from_reader(reader)
        elif isinstance(input_pdf, bytes):
            reader = PyPDF2.PdfReader(io.BytesIO(input_pdf), password=password)
            writer = PyPDF2.PdfWriter()
            writer.append_pages_from_reader(reader)
        else:
            raise ValueError("input_pdf must be a file path, file-like object, or bytes")
        
        # Write to a bytes buffer
        output = io.BytesIO()
        writer.write(output)
        return output.getvalue()

# Default security instance
default_document_security = DocumentSecurity()
