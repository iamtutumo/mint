from fastapi import HTTPException, status, Depends, Header
from typing import Optional
import hashlib
import secrets

from app.core.config import settings

class SecurityManager:
    
    @staticmethod
    def verify_owner_phone(phone_number: str) -> bool:
        """Verify if phone number is an authorized owner"""
        normalized = phone_number.replace("+", "").replace(" ", "").replace("-", "")
        return normalized in [p.replace("+", "").replace(" ", "").replace("-", "") 
                            for p in settings.OWNER_PHONE_NUMBERS]
    
    @staticmethod
    def verify_superuser_password(password: str) -> bool:
        """Verify superuser password for critical operations"""
        if not settings.SUPERUSER_PASSWORD:
            return False
        
        hashed = hashlib.sha256(password.encode()).hexdigest()
        expected = hashlib.sha256(settings.SUPERUSER_PASSWORD.encode()).hexdigest()
        return secrets.compare_digest(hashed, expected)
    
    @staticmethod
    def generate_secure_token(length: int = 32) -> str:
        """Generate secure random token"""
        return secrets.token_urlsafe(length)
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash password using SHA256"""
        return hashlib.sha256(password.encode()).hexdigest()

async def verify_owner_access(
    x_phone_number: Optional[str] = Header(None)
) -> str:
    """Dependency to verify owner phone number from header"""
    if not x_phone_number:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Phone number header required"
        )
    
    if not SecurityManager.verify_owner_phone(x_phone_number):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized phone number"
        )
    
    return x_phone_number

async def verify_superuser_access(
    x_phone_number: Optional[str] = Header(None),
    x_superuser_password: Optional[str] = Header(None)
) -> str:
    """Dependency for critical operations requiring superuser password"""
    phone = await verify_owner_access(x_phone_number)
    
    if not x_superuser_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Superuser password required for this operation"
        )
    
    if not SecurityManager.verify_superuser_password(x_superuser_password):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid superuser password"
        )
    
    return phone