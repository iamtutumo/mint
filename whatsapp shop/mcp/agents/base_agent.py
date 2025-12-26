from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, List
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

class Task(BaseModel):
    """Represents a task that can be processed by an agent."""
    task_id: str
    task_type: str
    data: Dict[str, Any]
    metadata: Dict[str, Any] = {}

class AgentResponse(BaseModel):
    """Standard response format for agent tasks."""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    next_steps: Optional[List[str]] = None

class BaseAgent(ABC):
    """Base class for all agents in the MCP system."""
    
    def __init__(self, agent_id: str, agent_type: str):
        self.agent_id = agent_id
        self.agent_type = agent_type
        self.initialized = False
        self.logger = logging.getLogger(f"agent.{agent_type}.{agent_id}")
    
    async def initialize(self):
        """Initialize the agent with required resources."""
        if not self.initialized:
            self.logger.info(f"Initializing {self.agent_type} agent: {self.agent_id}")
            await self._setup()
            self.initialized = True
    
    @abstractmethod
    async def _setup(self):
        """Agent-specific setup logic."""
        pass
    
    @abstractmethod
    async def process(self, task: Task) -> AgentResponse:
        """Process a task and return a response.
        
        Args:
            task: The task to process
            
        Returns:
            AgentResponse: The result of processing the task
        """
        pass
    
    async def cleanup(self):
        """Clean up resources used by the agent."""
        if self.initialized:
            self.logger.info(f"Cleaning up {self.agent_type} agent: {self.agent_id}")
            await self._teardown()
            self.initialized = False
    
    async def _teardown(self):
        """Agent-specific teardown logic."""
        pass
    
    def __str__(self):
        return f"{self.agent_type.capitalize()}Agent(id='{self.agent_id}')"
