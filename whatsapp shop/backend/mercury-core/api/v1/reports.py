from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from app.db.session import get_db
from services.report import ReportService

router = APIRouter(prefix="/reports", tags=["reports"])

@router.get("/sales")
async def get_sales_report(
    start_date: datetime,
    end_date: datetime,
    group_by: str = Query("day", regex="^(day|week|month)$"),
    db: Session = Depends(get_db)
):
    """Generate sales report"""
    try:
        report = ReportService.get_sales_report(db, start_date, end_date, group_by)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate sales report: {str(e)}")

@router.get("/payments")
async def get_payment_report(
    start_date: datetime,
    end_date: datetime,
    db: Session = Depends(get_db)
):
    """Generate payment report"""
    try:
        report = ReportService.get_payment_report(db, start_date, end_date)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate payment report: {str(e)}")

@router.get("/inventory")
async def get_inventory_report(db: Session = Depends(get_db)):
    """Generate inventory report"""
    try:
        report = ReportService.get_inventory_report(db)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate inventory report: {str(e)}")

@router.get("/profit-loss")
async def get_profit_loss_report(
    start_date: datetime,
    end_date: datetime,
    db: Session = Depends(get_db)
):
    """Generate profit & loss report"""
    try:
        report = ReportService.get_profit_loss_report(db, start_date, end_date)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate P&L report: {str(e)}")

@router.get("/balance-sheet")
async def get_balance_sheet_report(
    as_of_date: Optional[datetime] = None,
    db: Session = Depends(get_db)
):
    """Generate balance sheet report"""
    if as_of_date is None:
        as_of_date = datetime.utcnow()

    try:
        report = ReportService.get_balance_sheet_report(db, as_of_date)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate balance sheet: {str(e)}")

@router.get("/dashboard")
async def get_dashboard_metrics(db: Session = Depends(get_db)):
    """Get dashboard metrics"""
    try:
        metrics = ReportService.get_dashboard_metrics(db)
        return metrics
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get dashboard metrics: {str(e)}")

@router.get("/financial-summary")
async def get_financial_summary(
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db)
):
    """Get comprehensive financial summary"""
    if start_date is None:
        # Default to current month
        now = datetime.utcnow()
        start_date = datetime(now.year, now.month, 1)
    if end_date is None:
        end_date = datetime.utcnow()

    try:
        sales_report = ReportService.get_sales_report(db, start_date, end_date)
        payment_report = ReportService.get_payment_report(db, start_date, end_date)
        pl_report = ReportService.get_profit_loss_report(db, start_date, end_date)

        return {
            'period': {'start': start_date, 'end': end_date},
            'sales': sales_report['summary'],
            'payments': payment_report['summary'],
            'profit_loss': {
                'revenue': pl_report['revenue'],
                'expenses': pl_report['expenses'],
                'net_profit': pl_report['net_profit']
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate financial summary: {str(e)}")
