from sqlalchemy.orm import Session
from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.core.logging import setup_logging

logger = setup_logging()

async def init_db() -> None:
    try:
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
        logger.error(f"Database initialization failed: {e}")
        raise

async def create_default_accounts(db: Session):
    from app.models.account import Account
    
    default_accounts = [
        {"code": "1000", "name": "Cash", "account_type": "asset", "parent_id": None},
        {"code": "1100", "name": "Bank", "account_type": "asset", "parent_id": None},
        {"code": "1200", "name": "Mobile Money", "account_type": "asset", "parent_id": None},
        {"code": "2000", "name": "Accounts Payable", "account_type": "liability", "parent_id": None},
        {"code": "3000", "name": "Owner's Equity", "account_type": "equity", "parent_id": None},
        {"code": "4000", "name": "Sales Revenue", "account_type": "income", "parent_id": None},
        {"code": "5000", "name": "Cost of Goods Sold", "account_type": "expense", "parent_id": None},
        {"code": "6000", "name": "Operating Expenses", "account_type": "expense", "parent_id": None},
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
        Base.metadata.create_all(bind=engine)
        db.rollback()
        for acc in default_accounts:
            account = Account(**acc)
            db.add(account)
        db.commit()
        logger.info("Default accounts created (fallback)")

async def create_default_products(db: Session):
    # Add sample products if needed
    pass