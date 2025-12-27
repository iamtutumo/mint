from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from sqlalchemy.orm import Session

from app.db.session import get_db
from models.account import Account, AccountType
from schemas.account import AccountCreate, AccountUpdate, Account as AccountSchema
from services.account import AccountService
from models.account import Account, AccountType
from schemas.account import AccountCreate, AccountUpdate, Account as AccountSchema, AccountBalance
from services.account import AccountService

router = APIRouter(prefix="/accounts", tags=["accounts"])

@router.post("/", response_model=AccountSchema, status_code=status.HTTP_201_CREATED)
async def create_account(
    account: AccountCreate,
    db: Session = Depends(get_db)
):
    """Create a new account"""
    try:
        db_account = AccountService.create_account(db, account)
        return AccountSchema.from_orm(db_account)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create account: {str(e)}")

@router.get("/", response_model=List[AccountSchema])
async def list_accounts(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    account_type: Optional[AccountType] = None,
    is_active: Optional[bool] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """List accounts with optional filters"""
    try:
        accounts = AccountService.get_accounts(
            db=db,
            skip=skip,
            limit=limit,
            account_type=account_type,
            is_active=is_active,
            search=search
        )
        return [AccountSchema.from_orm(account) for account in accounts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list accounts: {str(e)}")

@router.get("/{account_id}", response_model=AccountSchema)
async def get_account(
    account_id: str,
    db: Session = Depends(get_db)
):
    """Get an account by ID"""
    account = AccountService.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return AccountSchema.from_orm(account)

@router.put("/{account_id}", response_model=AccountSchema)
async def update_account(
    account_id: str,
    account_update: AccountUpdate,
    db: Session = Depends(get_db)
):
    """Update an account"""
    try:
        db_account = AccountService.update_account(db, account_id, account_update)
        return AccountSchema.from_orm(db_account)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update account: {str(e)}")

@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    account_id: str,
    db: Session = Depends(get_db)
):
    """Delete an account (only if no transactions)"""
    try:
        success = AccountService.delete_account(db, account_id)
        if not success:
            raise HTTPException(status_code=404, detail="Account not found")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete account: {str(e)}")

@router.get("/{account_id}/balance")
async def get_account_balance(
    account_id: str,
    db: Session = Depends(get_db)
):
    """Get current balance for an account"""
    try:
        balance = AccountService.get_account_balance(db, account_id)
        return {"account_id": account_id, "balance": balance}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get account balance: {str(e)}")

@router.get("/balances/all", response_model=List[AccountBalance])
async def get_all_account_balances(db: Session = Depends(get_db)):
    """Get balances for all active accounts"""
    try:
        balances = AccountService.get_all_account_balances(db)
        return balances
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get account balances: {str(e)}")

@router.get("/trial-balance/summary")
async def get_trial_balance(db: Session = Depends(get_db)):
    """Generate trial balance"""
    try:
        trial_balance = AccountService.get_trial_balance(db)
        return trial_balance
    except Exception as e:        raise HTTPException(status_code=500, detail=f"Failed to generate trial balance: {str(e)}")