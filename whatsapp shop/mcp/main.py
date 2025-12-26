import asyncio
import logging
import signal
from .mcp_service import create_mcp_service
from .agents.order_agent import OrderAgent
from .config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

async def main():
    # Create and configure the MCP service
    mcp = create_mcp_service()
    
    # Register agents
    mcp.register_agent(OrderAgent())
    # Add more agents here as needed
    
    # Start the MCP service
    await mcp.start()
    
    # Set up signal handlers for graceful shutdown
    loop = asyncio.get_running_loop()
    stop_event = asyncio.Event()
    
    def signal_handler():
        logger.info("Shutdown signal received, stopping MCP service...")
        stop_event.set()
    
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)
    
    # Keep the service running until stopped
    await stop_event.wait()
    
    # Clean up
    await mcp.stop()

if __name__ == "__main__":
    asyncio.run(main())
