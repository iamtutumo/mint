from typing import Any, Dict, Type, Optional
from enum import Enum
from pydantic import BaseModel, validator
from transitions import Machine

class StateMachine:
    """Base class for state machines"""
    
    def __init__(self, model: Any, state_field: str, transitions: Dict, states: list, initial_state: str):
        """
        Initialize the state machine
        
        Args:
            model: The model instance to manage state for
            state_field: Name of the state field in the model
            transitions: Dictionary of transitions
            states: List of possible states
            initial_state: Initial state of the machine
        """
        self.model = model
        self.state_field = state_field
        self.machine = Machine(
            model=model,
            states=states,
            transitions=transitions,
            initial=initial_state,
            auto_transitions=False
        )
    
    def can_transition(self, to_state: str) -> bool:
        """Check if transition to target state is valid"""
        current_state = getattr(self.model, self.state_field)
        return self.machine.get_transitions(current_state, to_state) is not None
    
    def transition(self, to_state: str, **kwargs) -> bool:
        """Attempt to transition to target state"""
        if not self.can_transition(to_state):
            return False
        
        # Get the transition method name
        current_state = getattr(self.model, self.state_field)
        transition = self.machine.get_transitions(current_state, to_state)
        
        if not transition:
            return False
            
        # Execute the transition
        transition_method = getattr(self.model, f'to_{to_state.lower()}')
        transition_method(**kwargs)
        return True
    
    def get_allowed_transitions(self) -> list:
        """Get list of allowed transitions from current state"""
        current_state = getattr(self.model, self.state_field)
        return [t.dest for t in self.machine.get_transitions(current_state)]


class StatefulModel(BaseModel):
    """Base model for stateful objects"""
    
    class Config:
        use_enum_values = True
        arbitrary_types_allowed = True
    
    @validator('*', pre=True)
    def validate_enum_fields(cls, v, field):
        if hasattr(field.type_, '__origin__') and field.type_.__origin__ is type and issubclass(field.type_.__args__[0], Enum):
            if isinstance(v, str):
                return field.type_.__args__[0][v]
        return v
