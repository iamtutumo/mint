import httpx
import json
from typing import Dict, Any, Optional
from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

class LLMCommandParser:
    """Parse natural language commands using Ollama LLM"""
    
    SYSTEM_PROMPT = """You are a command parser for a WhatsApp-based commerce platform.
Parse user messages into structured commands.

Available commands:
- change_order_status: Change order state (pending, confirmed, dispatched, completed, cancelled)
- create_expense: Record business expense
- transfer_funds: Move money between accounts
- check_inventory: Check stock levels
- generate_report: Create business reports
- adjust_inventory: Modify stock (requires superuser)
- create_product: Add new product
- check_order: Get order status

Extract:
1. Command intent
2. Entities (order numbers, amounts, accounts, products)
3. Parameters

Return JSON only. Example:
{
  "intent": "change_order_status",
  "confidence": 0.95,
  "entities": {
    "order_number": "ORD-20240101-ABC123",
    "new_status": "dispatched"
  }
}"""
    
    @staticmethod
    async def parse_command(message: str, phone_number: str) -> Dict[str, Any]:
        """Parse natural language command"""
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{settings.OLLAMA_BASE_URL}/api/generate",
                    json={
                        "model": settings.OLLAMA_MODEL,
                        "prompt": f"{LLMCommandParser.SYSTEM_PROMPT}\n\nUser message: {message}",
                        "stream": False,
                        "format": "json"
                    }
                )
                
                if response.status_code != 200:
                    logger.error(f"Ollama API error: {response.status_code}")
                    return LLMCommandParser._default_response()
                
                result = response.json()
                command_json = json.loads(result.get("response", "{}"))
                
                # Add metadata
                command_json["raw_message"] = message
                command_json["phone_number"] = phone_number
                
                logger.info(f"Parsed command: {command_json.get('intent')}")
                return command_json
                
        except Exception as e:
            logger.error(f"LLM parsing error: {e}")
            return LLMCommandParser._default_response()
    
    @staticmethod
    def _default_response() -> Dict[str, Any]:
        """Default response when parsing fails"""
        return {
            "intent": "unknown",
            "confidence": 0.0,
            "entities": {},
            "error": "Failed to parse command"
        }
    
    @staticmethod
    def validate_command(parsed: Dict[str, Any]) -> bool:
        """Validate parsed command structure"""
        required = ["intent", "confidence", "entities"]
        return all(key in parsed for key in required) and parsed["confidence"] > 0.6