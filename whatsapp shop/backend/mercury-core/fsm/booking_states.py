from app.models.booking import BookingStatus

BOOKING_STATE_TRANSITIONS = {
    BookingStatus.PENDING: [
        BookingStatus.CONFIRMED,
        BookingStatus.CANCELLED
    ],
    BookingStatus.CONFIRMED: [
        BookingStatus.COMPLETED,
        BookingStatus.NO_SHOW,
        BookingStatus.CANCELLED
    ],
    BookingStatus.COMPLETED: [],
    BookingStatus.CANCELLED: [],
    BookingStatus.NO_SHOW: []
}

def can_transition_booking(from_state: BookingStatus, to_state: BookingStatus) -> bool:
    """Check if booking transition is valid"""
    allowed = BOOKING_STATE_TRANSITIONS.get(from_state, [])
    return to_state in allowed

def get_allowed_booking_transitions(current_state: BookingStatus) -> list:
    """Get all allowed transitions from current booking state"""
    return BOOKING_STATE_TRANSITIONS.get(current_state, [])