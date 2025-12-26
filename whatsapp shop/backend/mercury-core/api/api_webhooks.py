from fastapi import APIRouter, Depends, Request, BackgroundTasks
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.utils.llm_parser import LLMCommandParser
from app.services.order_service import OrderService
from app.services.accounting_service import AccountingService
from app.services.inventory_service import InventoryService
from app.core.security import SecurityManager
from app.core.logging import setup_logging

router = APIRouter()
logger = setup_logging()

@router.post("/whatsapp-owner")
async def whatsapp_owner_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Handle WhatsApp messages from shop owner"""
    
    data = await request.json()
    
    # Extract message details from Evolution API format
    message_data = data.get("data", {})
    phone_number = message_data.get("key", {}).get("remoteJid", "").replace("@s.whatsapp.net", "")
    message_text = (
        message_data.get("message", {}).get("conversation") or
        message_data.get("message", {}).get("extendedTextMessage", {}).get("text", "")
    )
    
    # Verify owner
    if not SecurityManager.verify_owner_phone(phone_number):
        return {"status": "unauthorized", "message": "Not an authorized owner"}
    
    # Parse command
    parsed = await LLMCommandParser.parse_command(message_text, phone_number)
    
    if not LLMCommandParser.validate_command(parsed):
        return {
            "status": "error",
            "message": "Could not understand command",
            "response": "Sorry, I couldn't understand that command. Try 'help' for available commands."
        }
    
    # Route to appropriate handler
    intent = parsed.get("intent")
    entities = parsed.get("entities", {})
    
    try:
        if intent == "change_order_status":
            order_number = entities.get("order_number")
            new_status = entities.get("new_status")
            
            order = OrderService.get_order_by_number(db, order_number)
            if not order:
                response = f"Order {order_number} not found"
            else:
                from app.models.order import OrderStatus
                status_enum = OrderStatus[new_status.upper()]
                
                OrderService.transition_order_state(
                    db, order.id, status_enum, phone_number
                )
                response = f"✅ Order {order_number} updated to {new_status}"
        
        elif intent == "create_expense":
            amount = entities.get("amount")
            description = entities.get("description")
            account = entities.get("account", "cash")
            
            # Get accounts
            from app.models.account import Account, AccountType
            expense_account = db.query(Account).filter(
                Account.account_type == AccountType.EXPENSE
            ).first()
            
            payment_account = db.query(Account).filter(
                Account.name.ilike(f"%{account}%")
            ).first()
            
            if not expense_account or not payment_account:
                response = "Could not find required accounts"
            else:
                AccountingService.record_expense(
                    db, amount, expense_account.id, payment_account.id,
                    description, phone_number
                )
                response = f"✅ Expense recorded: {description} - {amount}"
        
        elif intent == "check_inventory":
            product_name = entities.get("product_name")
            
            from app.models.product import Product
            product = db.query(Product).filter(
                Product.name.ilike(f"%{product_name}%")
            ).first()
            
            if not product:
                response = f"Product '{product_name}' not found"
            else:
                stock = InventoryService.get_current_stock(db, product.id)
                response = f"📦 {product.name}: {stock} units in stock"
        
        elif intent == "check_order":
            order_number = entities.get("order_number")
            order = OrderService.get_order_by_number(db, order_number)
            
            if not order:
                response = f"Order {order_number} not found"
            else:
                response = f"""
Order: {order.order_number}
Status: {order.status.value}
Customer: {order.customer.phone_number}
Total: {order.total_amount}
Items: {len(order.items)}
                """.strip()
        
        else:
            response = f"Command '{intent}' not yet implemented"
        
        return {
            "status": "success",
            "intent": intent,
            "response": response
        }
        
    except Exception as e:
        logger.error(f"Command execution error: {e}")
        return {
            "status": "error",
            "response": f"Error executing command: {str(e)}"
        }

@router.post("/whatsapp-customer")
async def whatsapp_customer_webhook(
    request: Request,
    db: Session = Depends(get_db)
):
    """Handle WhatsApp messages from customers"""
    
    data = await request.json()
    
    # Handle customer queries, order status checks, etc.
    message_data = data.get("data", {})
    phone_number = message_data.get("key", {}).get("remoteJid", "").replace("@s.whatsapp.net", "")
    message_text = (
        message_data.get("message", {}).get("conversation") or
        message_data.get("message", {}).get("extendedTextMessage", {}).get("text", "")
    )
    
    # Check if asking for order status
    if "order" in message_text.lower() and any(word in message_text.lower() for word in ["status", "where", "track"]):
        # Extract order number
        words = message_text.split()
        order_number = next((w for w in words if w.startswith("ORD-")), None)
        
        if order_number:
            order = OrderService.get_order_by_number(db, order_number)
            if order and order.customer.phone_number == phone_number:
                response = f"""
Your order {order.order_number}
Status: {order.status.value}
Total: ${order.total_amount}
                """.strip()
            else:
                response = "Order not found or doesn't belong to you"
        else:
            response = "Please provide your order number (e.g., ORD-20240101-ABC123)"
    else:
        response = "How can I help you today? You can check your order status or browse products."
    
    return {
        "status": "success",
        "response": response
    }