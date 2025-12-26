from datetime import datetime
from decimal import Decimal
from typing import Dict, Any, List, Optional
import logging
import uuid
from ..config import settings
from .base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class AccountingAgent(BaseAgent):
    """Agent responsible for financial record keeping and reporting."""
    
    def __init__(self):
        super().__init__(
            agent_id="accounting_agent_1",
            agent_type="accounting"
        )
        self.journal_entries = []
        self.accounts = {
            "cash": {"name": "Cash", "type": "asset", "balance": Decimal('0')},
            "accounts_receivable": {"name": "Accounts Receivable", "type": "asset", "balance": Decimal('0')},
            "inventory": {"name": "Inventory", "type": "asset", "balance": Decimal('0')},
            "accounts_payable": {"name": "Accounts Payable", "type": "liability", "balance": Decimal('0')},
            "revenue": {"name": "Sales Revenue", "type": "revenue", "balance": Decimal('0')},
            "cogs": {"name": "Cost of Goods Sold", "type": "expense", "balance": Decimal('0')},
            "expenses": {"name": "Operating Expenses", "type": "expense", "balance": Decimal('0')}
        }
    
    async def _setup(self):
        """Initialize accounting agent resources."""
        logger.info("Initializing Accounting Agent")
    
    async def process(self, task: Task) -> AgentResponse:
        """Process an accounting-related task."""
        action = task.data.get("action")
        
        if action == "record_transaction":
            return await self._record_transaction(task.data)
        elif action == "get_balance_sheet":
            return await self._get_balance_sheet()
        elif action == "get_income_statement":
            return await self._get_income_statement(task.data)
        elif action == "list_transactions":
            return await self._list_transactions(task.data)
        else:
            return AgentResponse(
                success=False,
                error=f"Unknown action: {action}"
            )
    
    async def _record_transaction(self, data: Dict[str, Any]) -> AgentResponse:
        """Record a financial transaction."""
        try:
            entries = data.get("entries", [])
            if not entries:
                return AgentResponse(
                    success=False,
                    error="At least one journal entry is required"
                )
            
            # Validate the transaction is balanced
            total_debit = sum(Decimal(str(e.get("amount", 0))) for e in entries if e.get("type") == "debit")
            total_credit = sum(Decimal(str(e.get("amount", 0))) for e in entries if e.get("type") == "credit")
            
            if total_debit != total_credit:
                return AgentResponse(
                    success=False,
                    error=f"Transaction is not balanced. Debits ({total_debit}) must equal credits ({total_credit})"
                )
            
            # Create transaction record
            transaction_id = f"txn_{str(uuid.uuid4())[:8]}"
            timestamp = datetime.utcnow().isoformat()
            
            # Process each entry
            for entry in entries:
                account = entry.get("account")
                amount = Decimal(str(entry.get("amount", 0)))
                entry_type = entry.get("type")
                
                # Validate account exists
                if account not in self.accounts:
                    return AgentResponse(
                        success=False,
                        error=f"Invalid account: {account}"
                    )
                
                # Update account balance
                if entry_type == "debit":
                    self.accounts[account]["balance"] += amount
                elif entry_type == "credit":
                    self.accounts[account]["balance"] -= amount
                
                # Create journal entry
                journal_entry = {
                    "id": f"je_{str(uuid.uuid4())[:8]}",
                    "transaction_id": transaction_id,
                    "account": account,
                    "type": entry_type,
                    "amount": float(amount),
                    "currency": entry.get("currency", "USD"),
                    "description": entry.get("description", ""),
                    "reference_id": entry.get("reference_id"),
                    "reference_type": entry.get("reference_type"),
                    "timestamp": timestamp,
                    "metadata": entry.get("metadata", {})
                }
                
                self.journal_entries.append(journal_entry)
            
            logger.info(f"Recorded transaction: {transaction_id}")
            return AgentResponse(
                success=True,
                data={"transaction_id": transaction_id}
            )
            
        except Exception as e:
            logger.error(f"Error recording transaction: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _get_balance_sheet(self) -> AgentResponse:
        """Generate a balance sheet report."""
        try:
            assets = {k: v for k, v in self.accounts.items() if v["type"] == "asset"}
            liabilities = {k: v for k, v in self.accounts.items() if v["type"] == "liability"}
            equity = {k: v for k, v in self.accounts.items() if v["type"] == "equity"}
            
            total_assets = sum(acc["balance"] for acc in assets.values())
            total_liabilities = sum(acc["balance"] for acc in liabilities.values())
            total_equity = sum(acc["balance"] for acc in equity.values())
            
            return AgentResponse(
                success=True,
                data={
                    "as_of": datetime.utcnow().isoformat(),
                    "assets": {k: {"name": v["name"], "balance": float(v["balance"])} for k, v in assets.items()},
                    "liabilities": {k: {"name": v["name"], "balance": float(v["balance"])} for k, v in liabilities.items()},
                    "equity": {k: {"name": v["name"], "balance": float(v["balance"])} for k, v in equity.items()},
                    "total_assets": float(total_assets),
                    "total_liabilities": float(total_liabilities),
                    "total_equity": float(total_equity),
                    "balance_check": float(total_assets - (total_liabilities + total_equity))  # Should be 0
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating balance sheet: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _get_income_statement(self, params: Dict[str, Any]) -> AgentResponse:
        """Generate an income statement report."""
        try:
            start_date = params.get("start_date")
            end_date = params.get("end_date", datetime.utcnow().isoformat())
            
            # Filter entries by date range
            filtered_entries = [
                e for e in self.journal_entries
                if (not start_date or e["timestamp"] >= start_date) and e["timestamp"] <= end_date
            ]
            
            # Calculate revenue and expenses
            revenue = sum(
                Decimal(str(e["amount"])) for e in filtered_entries 
                if self.accounts[e["account"]]["type"] == "revenue"
            )
            
            expenses = sum(
                Decimal(str(e["amount"])) for e in filtered_entries 
                if self.accounts[e["account"]]["type"] == "expense"
            )
            
            net_income = revenue - expenses
            
            return AgentResponse(
                success=True,
                data={
                    "start_date": start_date,
                    "end_date": end_date,
                    "revenue": float(revenue),
                    "expenses": float(expenses),
                    "net_income": float(net_income)
                }
            )
            
        except Exception as e:
            logger.error(f"Error generating income statement: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _list_transactions(self, params: Dict[str, Any]) -> AgentResponse:
        """List journal entries with optional filters."""
        try:
            account = params.get("account")
            start_date = params.get("start_date")
            end_date = params.get("end_date")
            reference_type = params.get("reference_type")
            reference_id = params.get("reference_id")
            
            filtered_entries = self.journal_entries
            
            if account:
                filtered_entries = [e for e in filtered_entries if e["account"] == account]
            if start_date:
                filtered_entries = [e for e in filtered_entries if e["timestamp"] >= start_date]
            if end_date:
                filtered_entries = [e for e in filtered_entries if e["timestamp"] <= end_date]
            if reference_type:
                filtered_entries = [e for e in filtered_entries if e.get("reference_type") == reference_type]
            if reference_id:
                filtered_entries = [e for e in filtered_entries if e.get("reference_id") == reference_id]
            
            # Group entries by transaction
            transactions = {}
            for entry in filtered_entries:
                txn_id = entry["transaction_id"]
                if txn_id not in transactions:
                    transactions[txn_id] = {
                        "transaction_id": txn_id,
                        "timestamp": entry["timestamp"],
                        "entries": []
                    }
                transactions[txn_id]["entries"].append(entry)
            
            # Convert to list and sort by timestamp (newest first)
            transaction_list = sorted(
                transactions.values(),
                key=lambda x: x["timestamp"],
                reverse=True
            )
            
            # Pagination
            limit = int(params.get("limit", 10))
            offset = int(params.get("offset", 0))
            paginated_transactions = transaction_list[offset:offset + limit]
            
            return AgentResponse(
                success=True,
                data={
                    "transactions": paginated_transactions,
                    "total": len(transaction_list),
                    "limit": limit,
                    "offset": offset
                }
            )
            
        except Exception as e:
            logger.error(f"Error listing transactions: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _teardown(self):
        """Clean up resources."""
        logger.info("Cleaning up Accounting Agent")
