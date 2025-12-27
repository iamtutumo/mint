from sqlalchemy.orm import Session
from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.core.logging import setup_logging

logger = setup_logging()

async def init_db() -> None:
    try:
        # Drop all tables first (for development)
        Base.metadata.drop_all(bind=engine)
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
        
        # Initialize default data
        db = SessionLocal()
        try:
            await create_default_accounts(db)
            await create_default_products(db)
        finally:
            db.close()

    except Exception as e:
        logger.warning(f"Database initialization encountered an issue: {e}. Continuing...")
        # Don't raise the exception, just log it

async def create_default_accounts(db: Session):
    from app.models.account import Account
    
    default_accounts = [
        {"code": "1000", "name": "Cash", "account_type": "asset"},
        {"code": "1100", "name": "Bank", "account_type": "asset"},
        {"code": "1200", "name": "Mobile Money", "account_type": "asset"},
        {"code": "2000", "name": "Accounts Payable", "account_type": "liability"},
        {"code": "3000", "name": "Owner's Equity", "account_type": "equity"},
        {"code": "4000", "name": "Sales Revenue", "account_type": "income"},
        {"code": "5000", "name": "Cost of Goods Sold", "account_type": "expense"},
        {"code": "6000", "name": "Operating Expenses", "account_type": "expense"},
    ]
    
    try:
        for acc in default_accounts:
            existing = db.query(Account).filter(Account.code == acc["code"]).first()
            if not existing:
                account = Account(**acc)
                db.add(account)
        db.commit()
        logger.info("Default accounts created")
    except Exception as e:
        # Fallback: attempt to create tables and insert defaults if the query failed (e.g., relation missing)
        logger.warning(f"Could not query accounts table during defaults init: {e}. Attempting to create tables and insert defaults.")
        Base.metadata.create_all(bind=engine, checkfirst=True)
        db.rollback()
        for acc in default_accounts:
            account = Account(**acc)
            db.add(account)
        db.commit()
        logger.info("Default accounts created (fallback)")

async def create_default_products(db: Session):
    # Add sample products if needed
    pass