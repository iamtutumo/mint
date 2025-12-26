from typing import Dict, Any, List, Optional
from datetime import datetime
import logging
import uuid
from ..config import settings
from .base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class PaymentAgent(BaseAgent):
    """Agent responsible for handling payment processing and management."""
    
    def __init__(self):
        super().__init__(
            agent_id="payment_agent_1",
            agent_type="payment"
        )
        self.payments = {}  # In-memory storage (replace with DB in production)
        self.refunds = {}   # In-memory storage for refunds
    
    async def _setup(self):
        """Initialize payment agent resources."""
        logger.info("Initializing Payment Agent")
        # In a real implementation, initialize payment gateway clients here
        # e.g., Stripe, PayPal, etc.
    
    async def process(self, task: Task) -> AgentResponse:
        """Process a payment-related task."""
        action = task.data.get("action")
        
        if action == "process":
            return await self._process_payment(task.data)
        elif action == "refund":
            return await self._process_refund(task.data)
        elif action == "get_payment":
            return await self._get_payment(task.data.get("payment_id"))
        elif action == "list_payments":
            return await self._list_payments(task.data)
        else:
            return AgentResponse(
                success=False,
                error=f"Unknown action: {action}"
            )
    
    async def _process_payment(self, payment_data: Dict[str, Any]) -> AgentResponse:
        """Process a payment."""
        try:
            # Validate required fields
            required_fields = ["amount", "currency", "payment_method", "customer_id"]
            for field in required_fields:
                if field not in payment_data:
                    return AgentResponse(
                        success=False,
                        error=f"Missing required field: {field}"
                    )
            
            # Generate a unique payment ID
            payment_id = f"pay_{str(uuid.uuid4())[:8]}"
            
            # In a real implementation, this would call the payment gateway
            # For example:
            # payment_result = await self.payment_gateway.charge(
            #     amount=payment_data["amount"],
            #     currency=payment_data["currency"],
            #     payment_method=payment_data["payment_method"],
            #     description=payment_data.get("description", "")
            # )
            
            # For demo purposes, simulate a successful payment
            payment_result = {
                "id": payment_id,
                "status": "succeeded",
                "amount": payment_data["amount"],
                "currency": payment_data["currency"],
                "created_at": datetime.utcnow().isoformat(),
                "payment_method": payment_data["payment_method"],
                "customer_id": payment_data["customer_id"],
                "metadata": payment_data.get("metadata", {})
            }
            
            # Store the payment
            self.payments[payment_id] = payment_result
            
            logger.info(f"Processed payment: {payment_id}")
            return AgentResponse(
                success=True,
                data={
                    "payment_id": payment_id,
                    "status": payment_result["status"],
                    "amount": payment_result["amount"],
                    "currency": payment_result["currency"]
                }
            )
            
        except Exception as e:
            logger.error(f"Error processing payment: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _process_refund(self, refund_data: Dict[str, Any]) -> AgentResponse:
        """Process a refund for an existing payment."""
        try:
            payment_id = refund_data.get("payment_id")
            amount = refund_data.get("amount")
            reason = refund_data.get("reason", "requested_by_customer")
            
            if not payment_id:
                return AgentResponse(
                    success=False,
                    error="payment_id is required for refund"
                )
            
            # Check if payment exists
            if payment_id not in self.payments:
                return AgentResponse(
                    success=False,
                    error=f"Payment not found: {payment_id}"
                )
            
            payment = self.payments[payment_id]
            
            # Check if payment is eligible for refund
            if payment["status"] != "succeeded":
                return AgentResponse(
                    success=False,
                    error=f"Cannot refund payment with status: {payment['status']}"
                )
            
            # If amount is not specified, refund the full amount
            if amount is None:
                amount = payment["amount"]
            else:
                # Ensure refund amount doesn't exceed payment amount
                amount = min(float(amount), float(payment["amount"]))
            
            # In a real implementation, this would call the payment gateway
            # For example:
            # refund_result = await self.payment_gateway.refund(
            #     payment_id=payment_id,
            #     amount=amount,
            #     reason=reason
            # )
            
            # For demo purposes, simulate a successful refund
            refund_id = f"re_{str(uuid.uuid4())[:8]}"
            refund_result = {
                "id": refund_id,
                "payment_id": payment_id,
                "amount": amount,
                "currency": payment["currency"],
                "status": "succeeded",
                "reason": reason,
                "created_at": datetime.utcnow().isoformat()
            }
            
            # Store the refund
            self.refunds[refund_id] = refund_result
            
            # Update payment status if fully refunded
            if amount == payment["amount"]:
                payment["status"] = "refunded"
            else:
                payment["status"] = "partially_refunded"
            
            logger.info(f"Processed refund: {refund_id}")
            return AgentResponse(
                success=True,
                data={
                    "refund_id": refund_id,
                    "payment_id": payment_id,
                    "amount": amount,
                    "currency": payment["currency"],
                    "status": refund_result["status"]
                }
            )
            
        except Exception as e:
            logger.error(f"Error processing refund: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _get_payment(self, payment_id: str) -> AgentResponse:
        """Retrieve payment details."""
        if payment_id not in self.payments:
            return AgentResponse(
                success=False,
                error=f"Payment not found: {payment_id}"
            )
        
        return AgentResponse(
            success=True,
            data=self.payments[payment_id]
        )
    
    async def _list_payments(self, filters: Dict[str, Any] = None) -> AgentResponse:
        """List payments with optional filters."""
        try:
            filters = filters or {}
            payments = list(self.payments.values())
            
            # Apply filters
            if "customer_id" in filters:
                payments = [p for p in payments if p.get("customer_id") == filters["customer_id"]]
            
            if "status" in filters:
                payments = [p for p in payments if p.get("status") == filters["status"]]
            
            # Sort by creation date (newest first)
            payments.sort(key=lambda x: x.get("created_at", ""), reverse=True)
            
            # Pagination
            limit = int(filters.get("limit", 10))
            offset = int(filters.get("offset", 0))
            paginated_payments = payments[offset:offset + limit]
            
            return AgentResponse(
                success=True,
                data={
                    "payments": paginated_payments,
                    "total": len(payments),
                    "limit": limit,
                    "offset": offset
                }
            )
            
        except Exception as e:
            logger.error(f"Error listing payments: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _teardown(self):
        """Clean up resources."""
        logger.info("Cleaning up Payment Agent")
