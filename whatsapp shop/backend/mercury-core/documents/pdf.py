from typing import Optional, Union, BinaryIO
import os
import tempfile
from pathlib import Path
import logging
from weasyprint import HTML, CSS
from weasyprint.text.fonts import FontConfiguration

logger = logging.getLogger(__name__)

class PDFGenerator:
    """Generate PDF documents from HTML content."""
    
    def __init__(self, base_url: Optional[str] = None):
        """Initialize the PDF generator.
        
        Args:
            base_url: Base URL for resolving relative URLs in the HTML
        """
        self.base_url = base_url or os.getcwd()
        self.font_config = FontConfiguration()
    
    def generate_pdf(
        self,
        html_content: str,
        output_path: Optional[Union[str, Path]] = None,
        stylesheets: Optional[list] = None,
        pdf_kwargs: Optional[dict] = None
    ) -> Optional[bytes]:
        """Generate a PDF from HTML content.
        
        Args:
            html_content: HTML content to convert to PDF
            output_path: If provided, save the PDF to this path
            stylesheets: List of CSS stylesheets or CSS strings
            pdf_kwargs: Additional arguments to pass to WeasyPrint's write_pdf()
            
        Returns:
            PDF content as bytes if output_path is not provided, else None
        """
        try:
            html = HTML(string=html_content, base_url=self.base_url)
            pdf_kwargs = pdf_kwargs or {}
            
            # Add default PDF generation options
            pdf_kwargs.setdefault('optimize_size', ('fonts', 'images'))
            
            # Generate PDF
            pdf_bytes = html.write_pdf(
                stylesheets=stylesheets,
                font_config=self.font_config,
                **pdf_kwargs
            )
            
            # Save to file if output path is provided
            if output_path:
                with open(output_path, 'wb') as f:
                    f.write(pdf_bytes)
                logger.info(f"PDF saved to {output_path}")
                return None
                
            return pdf_bytes
            
        except Exception as e:
            logger.error(f"Error generating PDF: {str(e)}")
            raise
    
    def generate_pdf_from_template(
        self,
        template_name: str,
        context: dict,
        output_path: Optional[Union[str, Path]] = None,
        stylesheets: Optional[list] = None,
        pdf_kwargs: Optional[dict] = None
    ) -> Optional[bytes]:
        """Generate a PDF from a template.
        
        Args:
            template_name: Name of the template file
            context: Variables to pass to the template
            output_path: If provided, save the PDF to this path
            stylesheets: List of CSS stylesheets or CSS strings
            pdf_kwargs: Additional arguments to pass to WeasyPrint's write_pdf()
            
        Returns:
            PDF content as bytes if output_path is not provided, else None
        """
        from .renderer import TemplateRenderer
        
        renderer = TemplateRenderer()
        html_content = renderer.render_template(template_name, context)
        return self.generate_pdf(html_content, output_path, stylesheets, pdf_kwargs)

# Default PDF generator instance
default_pdf_generator = PDFGenerator()
