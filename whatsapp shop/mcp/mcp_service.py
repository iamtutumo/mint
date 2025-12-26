import asyncio
import logging
from typing import Dict, Optional, List
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uuid

from .config.settings import settings
from .agents.base_agent import BaseAgent, Task, AgentResponse

logger = logging.getLogger(__name__)

class MCPService:
    def __init__(self):
        self.app = FastAPI(title="MCP Service", version="1.0.0")
        self.agents: Dict[str, BaseAgent] = {}
        self.task_queue = asyncio.Queue()
        self.active_tasks: Dict[str, asyncio.Task] = {}
        
        self._setup_middleware()
        self._setup_routes()
    
    def _setup_middleware(self):
        """Configure CORS and other middleware."""
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    
    def _setup_routes(self):
        """Set up FastAPI routes."""
        @self.app.get("/health")
        async def health_check():
            return {"status": "healthy", "agents": len(self.agents)}
        
        @self.app.post("/tasks")
        async def create_task(task_request: dict):
            task_id = str(uuid.uuid4())
            task = Task(
                task_id=task_id,
                task_type=task_request.get("type"),
                data=task_request.get("data", {}),
                metadata=task_request.get("metadata", {})
            )
            
            # Add task to queue
            await self.task_queue.put(task)
            return {"task_id": task_id, "status": "queued"}
        
        @self.app.get("/tasks/{task_id}")
        async def get_task_status(task_id: str):
            if task_id in self.active_tasks:
                return {"task_id": task_id, "status": "processing"}
            return {"task_id": task_id, "status": "unknown"}
    
    def register_agent(self, agent: BaseAgent):
        """Register a new agent with the MCP service."""
        if agent.agent_id in self.agents:
            raise ValueError(f"Agent with ID {agent.agent_id} already registered")
        self.agents[agent.agent_id] = agent
        logger.info(f"Registered agent: {agent}")
    
    async def start(self):
        """Start the MCP service and all registered agents."""
        logger.info("Starting MCP service...")
        
        # Initialize all agents
        for agent in self.agents.values():
            try:
                await agent.initialize()
            except Exception as e:
                logger.error(f"Failed to initialize agent {agent.agent_id}: {e}")
                raise
        
        # Start task processing loop
        asyncio.create_task(self._process_tasks())
        
        logger.info("MCP service started successfully")
    
    async def stop(self):
        """Stop the MCP service and clean up resources."""
        logger.info("Stopping MCP service...")
        
        # Cancel all active tasks
        for task_id, task in self.active_tasks.items():
            if not task.done():
                task.cancel()
        
        # Clean up all agents
        for agent in self.agents.values():
            try:
                await agent.cleanup()
            except Exception as e:
                logger.error(f"Error cleaning up agent {agent.agent_id}: {e}")
        
        logger.info("MCP service stopped")
    
    async def _process_tasks(self):
        """Background task to process queued tasks."""
        while True:
            try:
                task = await self.task_queue.get()
                task_id = task.task_id
                
                # Find an agent that can handle this task type
                agent = self._find_agent_for_task(task)
                if not agent:
                    logger.warning(f"No agent found to handle task type: {task.task_type}")
                    continue
                
                # Process the task
                task_future = asyncio.create_task(self._execute_task(agent, task))
                self.active_tasks[task_id] = task_future
                
                # Clean up completed tasks
                task_future.add_done_callback(
                    lambda f, tid=task_id: self.active_tasks.pop(tid, None)
                )
                
            except asyncio.CancelledError:
                logger.info("Task processing loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing task: {e}", exc_info=True)
    
    def _find_agent_for_task(self, task: Task) -> Optional[BaseAgent]:
        """Find an agent that can handle the given task type."""
        # Simple implementation - can be enhanced with more sophisticated routing
        for agent in self.agents.values():
            if agent.agent_type == task.task_type:
                return agent
        return None
    
    async def _execute_task(self, agent: BaseAgent, task: Task) -> AgentResponse:
        """Execute a task with the given agent."""
        try:
            logger.info(f"Executing task {task.task_id} with agent {agent.agent_id}")
            return await agent.process(task)
        except Exception as e:
            logger.error(f"Error executing task {task.task_id}: {e}", exc_info=True)
            return AgentResponse(
                success=False,
                error=str(e)
            )

def create_mcp_service() -> MCPService:
    """Create and configure an MCP service instance."""
    return MCPService()
