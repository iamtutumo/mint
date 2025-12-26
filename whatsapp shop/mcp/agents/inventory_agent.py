from typing import Dict, Any, List, Optional, Union
from datetime import datetime
import logging
import uuid
from ..config import settings
from .base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class InventoryItem(BaseAgent):
    """Represents an item in the inventory."""
    
    def __init__(self, product_id: str, sku: str, name: str, quantity: int, 
                 price: float, attributes: Optional[Dict[str, Any]] = None):
        self.product_id = product_id
        self.sku = sku
        self.name = name
        self.quantity = quantity
        self.price = price
        self.attributes = attributes or {}
        self.created_at = datetime.utcnow().isoformat()
        self.updated_at = datetime.utcnow().isoformat()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the inventory item to a dictionary."""
        return {
            "product_id": self.product_id,
            "sku": self.sku,
            "name": self.name,
            "quantity": self.quantity,
            "price": float(self.price),
            "attributes": self.attributes,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }

class InventoryAgent(BaseAgent):
    """Agent responsible for managing inventory and stock levels."""
    
    def __init__(self):
        super().__init__(
            agent_id="inventory_agent_1",
            agent_type="inventory"
        )
        self.products = {}  # product_id -> InventoryItem
        self.categories = {}  # category_id -> {name, description, products: [product_ids]}
        self.inventory_logs = []  # For tracking inventory changes
    
    async def _setup(self):
        """Initialize inventory agent resources."""
        logger.info("Initializing Inventory Agent")
        # In a real implementation, load initial inventory from database
    
    async def process(self, task: Task) -> AgentResponse:
        """Process an inventory-related task."""
        action = task.data.get("action")
        
        if action == "add_product":
            return await self._add_product(task.data)
        elif action == "update_stock":
            return await self._update_stock(task.data)
        elif action == "get_product":
            return await self._get_product(task.data.get("product_id"))
        elif action == "list_products":
            return await self._list_products(task.data)
        elif action == "check_availability":
            return await self._check_availability(task.data)
        elif action == "create_category":
            return await self._create_category(task.data)
        elif action == "add_to_category":
            return await self._add_to_category(task.data)
        else:
            return AgentResponse(
                success=False,
                error=f"Unknown action: {action}"
            )
    
    async def _add_product(self, product_data: Dict[str, Any]) -> AgentResponse:
        """Add a new product to inventory."""
        try:
            # Validate required fields
            required_fields = ["sku", "name", "quantity", "price"]
            for field in required_fields:
                if field not in product_data:
                    return AgentResponse(
                        success=False,
                        error=f"Missing required field: {field}"
                    )
            
            # Generate a unique product ID if not provided
            product_id = product_data.get("product_id") or f"prod_{str(uuid.uuid4())[:8]}"
            
            # Check if product with same SKU already exists
            existing_product = next(
                (p for p in self.products.values() if p.sku == product_data["sku"] and p.product_id != product_id),
                None
            )
            
            if existing_product:
                return AgentResponse(
                    success=False,
                    error=f"Product with SKU {product_data['sku']} already exists"
                )
            
            # Create new inventory item
            product = InventoryItem(
                product_id=product_id,
                sku=product_data["sku"],
                name=product_data["name"],
                quantity=int(product_data["quantity"]),
                price=float(product_data["price"]),
                attributes=product_data.get("attributes", {})
            )
            
            # Add to inventory
            self.products[product_id] = product
            
            # Log the addition
            self._log_inventory_change(
                product_id=product_id,
                sku=product.sku,
                change_type="addition",
                quantity=product.quantity,
                notes="Initial stock"
            )
            
            logger.info(f"Added product: {product_id} ({product.sku})")
            return AgentResponse(
                success=True,
                data={
                    "product_id": product_id,
                    "sku": product.sku,
                    "name": product.name,
                    "quantity": product.quantity,
                    "price": product.price
                }
            )
            
        except Exception as e:
            logger.error(f"Error adding product: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _update_stock(self, update_data: Dict[str, Any]) -> AgentResponse:
        """Update stock levels for a product."""
        try:
            product_id = update_data.get("product_id")
            quantity_change = update_data.get("quantity")
            action = update_data.get("action", "set")  # 'set', 'increment', or 'decrement'
            
            if not product_id or quantity_change is None:
                return AgentResponse(
                    success=False,
                    error="product_id and quantity are required"
                )
            
            if product_id not in self.products:
                return AgentResponse(
                    success=False,
                    error=f"Product not found: {product_id}"
                )
            
            product = self.products[product_id]
            old_quantity = product.quantity
            
            # Update quantity based on action
            if action == "increment":
                new_quantity = old_quantity + int(quantity_change)
                change_type = "addition"
            elif action == "decrement":
                new_quantity = old_quantity - int(quantity_change)
                change_type = "removal"
                # Prevent negative stock
                if new_quantity < 0:
                    return AgentResponse(
                        success=False,
                        error=f"Insufficient stock. Current: {old_quantity}, Requested: {quantity_change}",
                        data={"current_stock": old_quantity}
                    )
            else:  # set
                new_quantity = int(quantity_change)
                change_type = "adjustment"
            
            # Update the product
            product.quantity = new_quantity
            product.updated_at = datetime.utcnow().isoformat()
            
            # Log the change
            self._log_inventory_change(
                product_id=product_id,
                sku=product.sku,
                change_type=change_type,
                quantity=abs(new_quantity - old_quantity),
                notes=update_data.get("notes", f"Stock {action} by {abs(quantity_change)}")
            )
            
            logger.info(f"Updated stock for {product_id}: {old_quantity} -> {new_quantity}")
            return AgentResponse(
                success=True,
                data={
                    "product_id": product_id,
                    "sku": product.sku,
                    "previous_quantity": old_quantity,
                    "new_quantity": new_quantity
                }
            )
            
        except Exception as e:
            logger.error(f"Error updating stock: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _get_product(self, product_id: str) -> AgentResponse:
        """Get product details by ID."""
        if product_id not in self.products:
            return AgentResponse(
                success=False,
                error=f"Product not found: {product_id}"
            )
        
        return AgentResponse(
            success=True,
            data=self.products[product_id].to_dict()
        )
    
    async def _list_products(self, filters: Dict[str, Any] = None) -> AgentResponse:
        """List products with optional filters."""
        try:
            filters = filters or {}
            products = list(self.products.values())
            
            # Apply filters
            if "category_id" in filters:
                category = self.categories.get(filters["category_id"])
                if category:
                    product_ids = set(category.get("products", []))
                    products = [p for p in products if p.product_id in product_ids]
            
            if "min_quantity" in filters:
                min_qty = int(filters["min_quantity"])
                products = [p for p in products if p.quantity >= min_qty]
            
            if "max_quantity" in filters:
                max_qty = int(filters["max_quantity"])
                products = [p for p in products if p.quantity <= max_qty]
            
            # Convert to dicts for response
            product_dicts = [p.to_dict() for p in products]
            
            # Pagination
            limit = int(filters.get("limit", 10))
            offset = int(filters.get("offset", 0))
            paginated_products = product_dicts[offset:offset + limit]
            
            return AgentResponse(
                success=True,
                data={
                    "products": paginated_products,
                    "total": len(product_dicts),
                    "limit": limit,
                    "offset": offset
                }
            )
            
        except Exception as e:
            logger.error(f"Error listing products: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _check_availability(self, check_data: Dict[str, Any]) -> AgentResponse:
        """Check product availability and reserve stock if requested."""
        try:
            product_id = check_data.get("product_id")
            quantity = int(check_data.get("quantity", 1))
            reserve = check_data.get("reserve", False)
            
            if not product_id:
                return AgentResponse(
                    success=False,
                    error="product_id is required"
                )
            
            if product_id not in self.products:
                return AgentResponse(
                    success=False,
                    error=f"Product not found: {product_id}"
                )
            
            product = self.products[product_id]
            available = product.quantity >= quantity
            
            result = {
                "product_id": product_id,
                "sku": product.sku,
                "name": product.name,
                "requested_quantity": quantity,
                "available_quantity": product.quantity,
                "is_available": available
            }
            
            # Reserve stock if requested and available
            if available and reserve:
                reserve_result = await self._update_stock({
                    "product_id": product_id,
                    "quantity": quantity,
                    "action": "decrement",
                    "notes": f"Reserved {quantity} units"
                })
                
                if not reserve_result.success:
                    return reserve_result
                
                result["reserved"] = True
                result["reservation_id"] = f"res_{str(uuid.uuid4())[:8]}"
            
            return AgentResponse(
                success=True,
                data=result
            )
            
        except Exception as e:
            logger.error(f"Error checking availability: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _create_category(self, category_data: Dict[str, Any]) -> AgentResponse:
        """Create a new product category."""
        try:
            name = category_data.get("name")
            
            if not name:
                return AgentResponse(
                    success=False,
                    error="Category name is required"
                )
            
            # Generate a category ID
            category_id = f"cat_{str(uuid.uuid4())[:8]}"
            
            # Create the category
            self.categories[category_id] = {
                "id": category_id,
                "name": name,
                "description": category_data.get("description", ""),
                "products": [],
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }
            
            logger.info(f"Created category: {category_id} ({name})")
            return AgentResponse(
                success=True,
                data={
                    "category_id": category_id,
                    "name": name
                }
            )
            
        except Exception as e:
            logger.error(f"Error creating category: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    async def _add_to_category(self, data: Dict[str, Any]) -> AgentResponse:
        """Add products to a category."""
        try:
            category_id = data.get("category_id")
            product_ids = data.get("product_ids", [])
            
            if not category_id:
                return AgentResponse(
                    success=False,
                    error="category_id is required"
                )
            
            if category_id not in self.categories:
                return AgentResponse(
                    success=False,
                    error=f"Category not found: {category_id}"
                )
            
            category = self.categories[category_id]
            added = 0
            
            for product_id in product_ids:
                if product_id in self.products and product_id not in category["products"]:
                    category["products"].append(product_id)
                    added += 1
            
            if added > 0:
                category["updated_at"] = datetime.utcnow().isoformat()
            
            logger.info(f"Added {added} products to category: {category_id}")
            return AgentResponse(
                success=True,
                data={
                    "category_id": category_id,
                    "products_added": added,
                    "total_products": len(category["products"])
                }
            )
            
        except Exception as e:
            logger.error(f"Error adding to category: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )
    
    def _log_inventory_change(self, product_id: str, sku: str, change_type: str, 
                            quantity: int, notes: str = "") -> None:
        """Log an inventory change."""
        log_entry = {
            "log_id": f"log_{str(uuid.uuid4())[:8]}",
            "product_id": product_id,
            "sku": sku,
            "change_type": change_type,  # 'addition', 'removal', 'adjustment'
            "quantity": quantity,
            "notes": notes,
            "timestamp": datetime.utcnow().isoformat()
        }
        self.inventory_logs.append(log_entry)
    
    async def _teardown(self):
        """Clean up resources."""
        logger.info("Cleaning up Inventory Agent")
