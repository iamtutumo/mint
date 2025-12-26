""
Utility functions for handling money, currency, and financial calculations.
"""
from decimal import Decimal, ROUND_HALF_UP
from typing import Union, Optional, Dict, Any
import locale
import json
from datetime import datetime

# Default currency settings
DEFAULT_CURRENCY = "USD"
DEFAULT_LOCALE = "en_US.UTF-8"

# Currency symbol map
CURRENCY_SYMBOLS = {
    "USD": "$",
    "EUR": "€",
    "GBP": "£",
    "JPY": "¥",
    "INR": "₹",
    "AUD": "A$",
    "CAD": "C$",
    "CNY": "¥",
    "HKD": "HK$",
    "NZD": "NZ$",
    "SGD": "S$",
}

# Currency decimal places (ISO 4217)
CURRENCY_DECIMALS = {
    "BIF": 0, "CLP": 0, "DJF": 0, "GNF": 0, "JPY": 0,
    "KMF": 0, "KRW": 0, "MGA": 0, "PYG": 0, "RWF": 0,
    "VND": 0, "VUV": 0, "XAF": 0, "XOF": 0, "XPF": 0,
    "MRO": 1, "BHD": 3, "JOD": 3, "KWD": 3, "OMR": 3,
    "TND": 3
}

# Default decimal places for common currencies
DEFAULT_DECIMALS = 2

class Money:
    """A class to handle monetary values with proper decimal arithmetic."""
    
    def __init__(self, amount: Union[str, int, float, Decimal], currency: str = DEFAULT_CURRENCY):
        """
        Initialize a Money object.
        
        Args:
            amount: The monetary amount as a string, int, float, or Decimal
            currency: ISO 4217 currency code (default: USD)
        """
        self.currency = currency.upper()
        
        # Convert amount to Decimal for precise arithmetic
        if isinstance(amount, Decimal):
            self.amount = amount
        else:
            try:
                self.amount = Decimal(str(amount))
            except (ValueError, TypeError) as e:
                raise ValueError(f"Invalid amount: {amount}") from e
        
        # Ensure amount is properly rounded to the correct number of decimal places
        self.amount = self.amount.quantize(
            Decimal('0.' + '0' * self.decimals),
            rounding=ROUND_HALF_UP
        )
    
    @property
    def decimals(self) -> int:
        """Get the number of decimal places for the currency."""
        return CURRENCY_DECIMALS.get(self.currency, DEFAULT_DECIMALS)
    
    @property
    def symbol(self) -> str:
        """Get the currency symbol."""
        return CURRENCY_SYMBOLS.get(self.currency, self.currency)
    
    def to_decimal(self) -> Decimal:
        """Return the amount as a Decimal."""
        return self.amount
    
    def to_float(self) -> float:
        """Return the amount as a float."""
        return float(self.amount)
    
    def to_int(self) -> int:
        """Return the amount as an integer (rounded)."""
        return int(round(self.amount, 0))
    
    def format(self, locale_name: str = DEFAULT_LOCALE, with_symbol: bool = True) -> str:
        """
        Format the money amount as a localized string.
        
        Args:
            locale_name: The locale to use for formatting (e.g., 'en_US', 'de_DE')
            with_symbol: Whether to include the currency symbol
            
        Returns:
            Formatted currency string
        """
        try:
            # Save the current locale
            old_locale = locale.getlocale(locale.LC_ALL)
            
            # Set the desired locale
            try:
                locale.setlocale(locale.LC_ALL, locale_name)
            except locale.Error:
                # Fall back to default locale if the requested one is not available
                locale_name = DEFAULT_LOCALE
                locale.setlocale(locale.LC_ALL, locale_name)
            
            # Format the amount
            formatted = locale.currency(
                self.amount,
                symbol=with_symbol,
                grouping=True,
                international=False
            )
            
            # Restore the original locale
            locale.setlocale(locale.LC_ALL, old_locale)
            
            return formatted
        except Exception:
            # Fallback formatting if locale is not available
            if with_symbol:
                return f"{self.symbol}{self.amount:,.{self.decimals}f}"
            return f"{self.amount:,.{self.decimals}f}"
    
    def __str__(self) -> str:
        """Return a string representation of the money amount."""
        return self.format()
    
    def __repr__(self) -> str:
        """Return a string representation for debugging."""
        return f"Money('{self.amount}', '{self.currency}')"
    
    # Arithmetic operations
    def __add__(self, other):
        self._check_currency_compatibility(other)
        return Money(self.amount + other.amount, self.currency)
    
    def __sub__(self, other):
        self._check_currency_compatibility(other)
        return Money(self.amount - other.amount, self.currency)
    
    def __mul__(self, other):
        if isinstance(other, (int, float, Decimal)):
            return Money(self.amount * Decimal(str(other)), self.currency)
        raise TypeError(f"Unsupported operand type(s) for *: 'Money' and '{type(other).__name__}'")
    
    def __truediv__(self, other):
        if isinstance(other, (int, float, Decimal)):
            if other == 0:
                raise ZeroDivisionError("Cannot divide by zero")
            return Money(self.amount / Decimal(str(other)), self.currency)
        raise TypeError(f"Unsupported operand type(s) for /: 'Money' and '{type(other).__name__}'")
    
    def __eq__(self, other):
        if not isinstance(other, Money):
            return False
        return self.amount == other.amount and self.currency == other.currency
    
    def __lt__(self, other):
        self._check_currency_compatibility(other)
        return self.amount < other.amount
    
    def __le__(self, other):
        self._check_currency_compatibility(other)
        return self.amount <= other.amount
    
    def __gt__(self, other):
        self._check_currency_compatibility(other)
        return self.amount > other.amount
    
    def __ge__(self, other):
        self._check_currency_compatibility(other)
        return self.amount >= other.amount
    
    def _check_currency_compatibility(self, other):
        """Raise a ValueError if currencies don't match."""
        if not isinstance(other, Money):
            raise TypeError(f"Cannot compare Money with {type(other).__name__}")
        if self.currency != other.currency:
            raise ValueError(f"Currency mismatch: {self.currency} != {other.currency}")

def parse_money(amount: str, currency: str = DEFAULT_CURRENCY) -> Money:
    """
    Parse a string into a Money object, handling various input formats.
    
    Args:
        amount: The amount as a string (e.g., "$1,234.56", "1.234,56€", "1,234")
        currency: ISO 4217 currency code (default: USD)
        
    Returns:
        A Money object
    """
    # Remove all non-numeric characters except minus, decimal point, and comma
    cleaned = ''.join(c for c in amount if c.isdigit() or c in '-,. ')
    
    # Handle European-style numbers (1.234,56)
    if ',' in cleaned and '.' in cleaned:
        if cleaned.find(',') > cleaned.find('.'):
            # 1,234.56 -> 1234.56
            cleaned = cleaned.replace(',', '')
        else:
            # 1.234,56 -> 1234.56
            cleaned = cleaned.replace('.', '').replace(',', '.')
    elif ',' in cleaned:
        # Could be either 1,234 or 1,234,56
        parts = cleaned.split(',')
        if len(parts[-1]) == 2:
            # Assume it's a decimal part
            cleaned = cleaned.replace(',', '.')
        else:
            # Assume it's a thousands separator
            cleaned = cleaned.replace(',', '')
    
    # Remove any remaining spaces
    cleaned = cleaned.replace(' ', '')
    
    try:
        return Money(cleaned, currency)
    except (ValueError, TypeError) as e:
        raise ValueError(f"Could not parse '{amount}' as a valid monetary amount") from e

def format_money(amount: Union[Money, Decimal, float, int], 
                currency: str = DEFAULT_CURRENCY,
                locale_name: str = DEFAULT_LOCALE,
                with_symbol: bool = True) -> str:
    """
    Format a monetary amount as a localized string.
    
    Args:
        amount: The amount as a Money object, Decimal, float, or int
        currency: ISO 4217 currency code (ignored if amount is a Money object)
        locale_name: The locale to use for formatting (e.g., 'en_US', 'de_DE')
        with_symbol: Whether to include the currency symbol
        
    Returns:
        Formatted currency string
    """
    if isinstance(amount, Money):
        return amount.format(locale_name, with_symbol)
    
    money = Money(amount, currency)
    return money.format(locale_name, with_symbol)

def calculate_tax(amount: Union[Money, Decimal, float, int], 
                 tax_rate: float, 
                 currency: str = DEFAULT_CURRENCY) -> Money:
    """
    Calculate tax for a given amount and tax rate.
    
    Args:
        amount: The amount to calculate tax for
        tax_rate: The tax rate as a percentage (e.g., 20 for 20%)
        currency: ISO 4217 currency code (ignored if amount is a Money object)
        
    Returns:
        A Money object representing the tax amount
    """
    if not isinstance(amount, Money):
        amount = Money(amount, currency)
    
    if tax_rate < 0 or tax_rate > 100:
        raise ValueError("Tax rate must be between 0 and 100")
    
    tax_amount = (amount.to_decimal() * Decimal(str(tax_rate))) / Decimal('100')
    return Money(tax_amount, amount.currency)

def calculate_discount(amount: Union[Money, Decimal, float, int], 
                     discount_percent: float = 0.0,
                     discount_amount: Optional[Union[Money, Decimal, float, int]] = None,
                     currency: str = DEFAULT_CURRENCY) -> Money:
    """
    Calculate a discount on an amount.
    
    Args:
        amount: The original amount
        discount_percent: The discount percentage (e.g., 10 for 10%)
        discount_amount: Fixed discount amount (takes precedence over discount_percent)
        currency: ISO 4217 currency code (ignored if amount is a Money object)
        
    Returns:
        A Money object representing the discount amount
    """
    if not isinstance(amount, Money):
        amount = Money(amount, currency)
    
    if discount_amount is not None:
        if not isinstance(discount_amount, Money):
            discount_amount = Money(discount_amount, currency)
        return min(discount_amount, amount)  # Discount can't be more than the amount
    
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount percentage must be between 0 and 100")
    
    discount = (amount.to_decimal() * Decimal(str(discount_percent))) / Decimal('100')
    return Money(discount, amount.currency)

# Initialize locale for currency formatting
try:
    locale.setlocale(locale.LC_ALL, '')
except locale.Error:
    # Fallback to default locale if the system locale is not available
    locale.setlocale(locale.LC_ALL, DEFAULT_LOCALE)
