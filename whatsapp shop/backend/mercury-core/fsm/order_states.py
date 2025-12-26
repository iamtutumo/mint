from app.models.order import OrderStatus

ORDER_STATE_TRANSITIONS = {
    OrderStatus.DRAFT: [
        OrderStatus.PENDING_PAYMENT,
        OrderStatus.CANCELLED
    ],
    OrderStatus.PENDING_PAYMENT: [
        OrderStatus.PAYMENT_SUBMITTED,
        OrderStatus.CANCELLED,
        OrderStatus.EXPIRED
    ],
    OrderStatus.PAYMENT_SUBMITTED: [
        OrderStatus.CONFIRMED,
        OrderStatus.CANCELLED
    ],
    OrderStatus.CONFIRMED: [
        OrderStatus.PROCESSING,
        OrderStatus.CANCELLED
    ],
    OrderStatus.PROCESSING: [
        OrderStatus.DISPATCHED,
        OrderStatus.CANCELLED
    ],
    OrderStatus.DISPATCHED: [
        OrderStatus.COMPLETED
    ],
    OrderStatus.COMPLETED: [],
    OrderStatus.CANCELLED: [],
    OrderStatus.EXPIRED: []
}

def can_transition(from_state: OrderStatus, to_state: OrderStatus) -> bool:
    """Check if transition is valid"""
    allowed = ORDER_STATE_TRANSITIONS.get(from_state, [])
    return to_state in allowed

def get_allowed_transitions(current_state: OrderStatus) -> list:
    """Get all allowed transitions from current state"""
    return ORDER_STATE_TRANSITIONS.get(current_state, [])