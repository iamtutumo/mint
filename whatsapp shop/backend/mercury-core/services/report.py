from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, extract
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from collections import defaultdict

from app.models.order import Order
from app.models.payment import Payment
from app.models.product import Product
from app.models.transaction import Transaction, TransactionType
from app.models.account import Account, AccountType
from app.services.accounting import AccountingService
from app.core.logging import setup_logging

logger = setup_logging()

class ReportService:
    @staticmethod
    def get_sales_report(
        db: Session,
        start_date: datetime,
        end_date: datetime,
        group_by: str = "day"  # day, week, month
    ) -> Dict[str, Any]:
        """Generate sales report"""
        # Get orders in date range
        orders = db.query(Order).filter(
            and_(Order.created_at >= start_date, Order.created_at <= end_date)
        ).all()

        total_orders = len(orders)
        total_revenue = sum(order.total_amount for order in orders if order.total_amount)

        # Group by time period
        grouped_data = defaultdict(lambda: {'orders': 0, 'revenue': 0.0})

        for order in orders:
            if group_by == "day":
                key = order.created_at.date().isoformat()
            elif group_by == "week":
                # Get week start (Monday)
                week_start = order.created_at.date() - timedelta(days=order.created_at.weekday())
                key = week_start.isoformat()
            elif group_by == "month":
                key = f"{order.created_at.year}-{order.created_at.month:02d}"
            else:
                key = "total"

            grouped_data[key]['orders'] += 1
            if order.total_amount:
                grouped_data[key]['revenue'] += order.total_amount

        return {
            'period': {'start': start_date, 'end': end_date},
            'summary': {
                'total_orders': total_orders,
                'total_revenue': total_revenue,
                'avg_order_value': total_revenue / total_orders if total_orders > 0 else 0
            },
            'data': dict(grouped_data),
            'grouped_by': group_by
        }

    @staticmethod
    def get_payment_report(
        db: Session,
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Generate payment report"""
        payments = db.query(Payment).filter(
            and_(Payment.created_at >= start_date, Payment.created_at <= end_date)
        ).all()

        total_payments = len(payments)
        total_amount = sum(payment.amount for payment in payments)

        # Group by payment method
        method_summary = defaultdict(lambda: {'count': 0, 'amount': 0.0})

        for payment in payments:
            method = payment.payment_method.value if hasattr(payment.payment_method, 'value') else str(payment.payment_method)
            method_summary[method]['count'] += 1
            method_summary[method]['amount'] += payment.amount

        # Group by status
        status_summary = defaultdict(int)
        for payment in payments:
            status = payment.status.value if hasattr(payment.status, 'value') else str(payment.status)
            status_summary[status] += 1

        return {
            'period': {'start': start_date, 'end': end_date},
            'summary': {
                'total_payments': total_payments,
                'total_amount': total_amount
            },
            'by_method': dict(method_summary),
            'by_status': dict(status_summary)
        }

    @staticmethod
    def get_inventory_report(db: Session) -> Dict[str, Any]:
        """Generate inventory report"""
        products = db.query(Product).all()

        total_products = len(products)
        in_stock = sum(1 for p in products if p.inventory_quantity > 0)
        out_of_stock = sum(1 for p in products if p.inventory_quantity <= 0)
        low_stock = sum(1 for p in products if p.reorder_level and p.inventory_quantity <= p.reorder_level)

        total_value = sum(p.price * p.inventory_quantity for p in products if p.inventory_quantity)

        # Group by category
        category_summary = defaultdict(lambda: {'count': 0, 'value': 0.0, 'quantity': 0})

        for product in products:
            category = product.category or 'Uncategorized'
            category_summary[category]['count'] += 1
            category_summary[category]['quantity'] += product.inventory_quantity or 0
            category_summary[category]['value'] += (product.price or 0) * (product.inventory_quantity or 0)

        return {
            'summary': {
                'total_products': total_products,
                'in_stock': in_stock,
                'out_of_stock': out_of_stock,
                'low_stock': low_stock,
                'total_value': total_value
            },
            'by_category': dict(category_summary)
        }

    @staticmethod
    def get_profit_loss_report(
        db: Session,
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Generate profit & loss report"""
        # Revenue accounts (income)
        revenue_accounts = db.query(Account).filter(Account.account_type == AccountType.INCOME).all()
        revenue_total = 0

        for account in revenue_accounts:
            credits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.CREDIT,
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_date <= end_date
                )
            ).scalar() or 0
            revenue_total += credits

        # Expense accounts
        expense_accounts = db.query(Account).filter(Account.account_type == AccountType.EXPENSE).all()
        expense_total = 0

        for account in expense_accounts:
            debits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.DEBIT,
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_date <= end_date
                )
            ).scalar() or 0
            expense_total += debits

        net_profit = revenue_total - expense_total

        return {
            'period': {'start': start_date, 'end': end_date},
            'revenue': revenue_total,
            'expenses': expense_total,
            'net_profit': net_profit,
            'revenue_accounts': [{'id': a.id, 'name': a.name, 'code': a.code} for a in revenue_accounts],
            'expense_accounts': [{'id': a.id, 'name': a.name, 'code': a.code} for a in expense_accounts]
        }

    @staticmethod
    def get_balance_sheet_report(db: Session, as_of_date: datetime) -> Dict[str, Any]:
        """Generate balance sheet report"""
        # Assets
        asset_accounts = db.query(Account).filter(Account.account_type == AccountType.ASSET).all()
        total_assets = 0

        asset_details = []
        for account in asset_accounts:
            # Calculate balance as of date
            debits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.DEBIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            credits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.CREDIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            balance = debits - credits
            total_assets += balance

            asset_details.append({
                'id': account.id,
                'name': account.name,
                'code': account.code,
                'balance': balance
            })

        # Liabilities
        liability_accounts = db.query(Account).filter(Account.account_type == AccountType.LIABILITY).all()
        total_liabilities = 0

        liability_details = []
        for account in liability_accounts:
            credits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.CREDIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            debits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.DEBIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            balance = credits - debits
            total_liabilities += balance

            liability_details.append({
                'id': account.id,
                'name': account.name,
                'code': account.code,
                'balance': balance
            })

        # Equity
        equity_accounts = db.query(Account).filter(Account.account_type == AccountType.EQUITY).all()
        total_equity = 0

        equity_details = []
        for account in equity_accounts:
            credits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.CREDIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            debits = db.query(func.sum(Transaction.amount)).filter(
                and_(
                    Transaction.account_id == account.id,
                    Transaction.transaction_type == TransactionType.DEBIT,
                    Transaction.transaction_date <= as_of_date
                )
            ).scalar() or 0

            balance = credits - debits
            total_equity += balance

            equity_details.append({
                'id': account.id,
                'name': account.name,
                'code': account.code,
                'balance': balance
            })

        return {
            'as_of_date': as_of_date,
            'assets': {
                'total': total_assets,
                'accounts': asset_details
            },
            'liabilities': {
                'total': total_liabilities,
                'accounts': liability_details
            },
            'equity': {
                'total': total_equity,
                'accounts': equity_details
            },
            'total_liabilities_equity': total_liabilities + total_equity
        }

    @staticmethod
    def get_dashboard_metrics(db: Session) -> Dict[str, Any]:
        """Get key metrics for dashboard"""
        # Today's sales
        today = datetime.utcnow().date()
        today_start = datetime(today.year, today.month, today.day)
        today_end = today_start + timedelta(days=1)

        today_orders = db.query(func.count(Order.id)).filter(
            and_(Order.created_at >= today_start, Order.created_at < today_end)
        ).scalar() or 0

        today_revenue = db.query(func.sum(Order.total_amount)).filter(
            and_(Order.created_at >= today_start, Order.created_at < today_end)
        ).scalar() or 0

        # This month's metrics
        month_start = datetime(today.year, today.month, 1)
        month_orders = db.query(func.count(Order.id)).filter(
            Order.created_at >= month_start
        ).scalar() or 0

        month_revenue = db.query(func.sum(Order.total_amount)).filter(
            Order.created_at >= month_start
        ).scalar() or 0

        # Pending payments
        pending_payments = db.query(func.count(Payment.id)).filter(
            Payment.status == 'pending'
        ).scalar() or 0

        # Low stock items
        low_stock = db.query(func.count(Product.id)).filter(
            and_(Product.reorder_level.isnot(None), Product.inventory_quantity <= Product.reorder_level)
        ).scalar() or 0

        return {
            'today': {
                'orders': today_orders,
                'revenue': float(today_revenue)
            },
            'month': {
                'orders': month_orders,
                'revenue': float(month_revenue)
            },
            'pending_payments': pending_payments,
            'low_stock_alerts': low_stock
}
