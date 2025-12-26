from jinja2 import Environment, FileSystemLoader, select_autoescape
import os
from pathlib import Path
from typing import Dict, Any, Optional

class TemplateRenderer:
    def __init__(self, templates_dir: Optional[str] = None):
        """Initialize the template renderer.
        
        Args:
            templates_dir: Directory containing the templates. If None, defaults to 'templates/html'.
        """
        if templates_dir is None:
            base_dir = Path(__file__).parent.parent
            templates_dir = str(base_dir / 'templates' / 'html')
            
        self.env = Environment(
            loader=FileSystemLoader(templates_dir),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Add custom filters
        self.env.filters['format_currency'] = self._format_currency
    
    def _format_currency(self, value: float) -> str:
        """Format a number as currency."""
        return f"${value:,.2f}"
    
    def render_template(self, template_name: str, context: Dict[str, Any]) -> str:
        """Render a template with the given context.
        
        Args:
            template_name: Name of the template file (e.g., 'invoice.html')
            context: Dictionary of variables to pass to the template
            
        Returns:
            Rendered HTML as a string
        """
        template = self.env.get_template(template_name)
        return template.render(**context)
    
    def render_invoice(self, invoice_data: Dict[str, Any]) -> str:
        """Render an invoice template with the given data."""
        return self.render_template('invoice.html', invoice_data)
    
    def render_receipt(self, receipt_data: Dict[str, Any]) -> str:
        """Render a receipt template with the given data."""
        return self.render_template('receipt.html', receipt_data)
    
    def render_order_confirmation(self, order_data: Dict[str, Any]) -> str:
        """Render an order confirmation template with the given data."""
        return self.render_template('order_confirmation.html', order_data)

# Default renderer instance
default_renderer = TemplateRenderer()
