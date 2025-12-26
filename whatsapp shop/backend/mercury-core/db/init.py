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
        {"code": "1000", "name": "Cash", "type": "asset", "parent_id": None},
        {"code": "1100", "name": "Bank", "type": "asset", "parent_id": None},
        {"code": "1200", "name": "Mobile Money", "type": "asset", "parent_id": None},
        {"code": "2000", "name": "Accounts Payable", "type": "liability", "parent_id": None},
        {"code": "3000", "name": "Owner's Equity", "type": "equity", "parent_id": None},
        {"code": "4000", "name": "Sales Revenue", "type": "income", "parent_id": None},
        {"code": "5000", "name": "Cost of Goods Sold", "type": "expense", "parent_id": None},
        {"code": "6000", "name": "Operating Expenses", "type": "expense", "parent_id": None},
    ]
    
    for acc in default_accounts:
        existing = db.query(Account).filter(Account.code == acc["code"]).first()
        if not existing:
            account = Account(**acc)
            db.add(account)
    
    db.commit()
    logger.info("Default accounts created")

async def create_default_products(db: Session):
    # Add sample products if needed
    pass