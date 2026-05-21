// services/ticketService.js

/**
 * SecureMove Ticket Lifecycle Service
 * Business rules only — no Express, no routes
 */

const TICKET_STATUS = {
  CREATED: 'CREATED',     // Ticket reserved but not paid
  PAID: 'PAID',           // Payment confirmed
  ACTIVE: 'ACTIVE',       // Valid for boarding
  USED: 'USED',           // Scanned by inspector
  EXPIRED: 'EXPIRED',     // Expired due to time
  CANCELLED: 'CANCELLED'  // Manually cancelled
};

/**
 * Allowed lifecycle transitions
 */
function isValidTransition(currentStatus, newStatus) {
  const transitions = {
    CREATED: ['PAID', 'CANCELLED', 'EXPIRED'],
    PAID: ['ACTIVE', 'CANCELLED'],
    ACTIVE: ['USED', 'EXPIRED'],
    USED: [],        // terminal
    EXPIRED: [],     // terminal
    CANCELLED: []    // terminal
  };

  return transitions[currentStatus]?.includes(newStatus);
}

/**
 * Validate that seat is available
 */
function canReserveSeat(existingTicket) {
  if (!existingTicket) return true;

  const blockedStatuses = [
    TICKET_STATUS.CREATED,
    TICKET_STATUS.PAID,
    TICKET_STATUS.ACTIVE
  ];

  return !blockedStatuses.includes(existingTicket.status);
}

/**
 * Check if ticket payment reservation expired
 * (e.g. 15 minute unpaid hold)
 */
function isReservationExpired(ticket) {
  if (!ticket.expires_at) return false;
  return new Date() > new Date(ticket.expires_at);
}

/**
 * Check if ticket expired based on schedule departure
 */
function isPastDeparture(scheduleDepartureTime) {
  return new Date() > new Date(scheduleDepartureTime);
}

/**
 * Validate ticket before marking USED
 */
function canBeValidated(ticket, scheduleDepartureTime) {
  if (ticket.status !== TICKET_STATUS.ACTIVE) {
    return { valid: false, reason: 'NOT_ACTIVE' };
  }

  if (isPastDeparture(scheduleDepartureTime)) {
    return { valid: false, reason: 'DEPARTED' };
  }

  return { valid: true };
}

/**
 * Ensure inspector belongs to same company
 */
function canInspectorValidate(ticketCompanyId, inspectorCompanyId) {
  return ticketCompanyId === inspectorCompanyId;
}

/**
 * Determine next state automatically after payment
 */
function nextStateAfterPayment() {
  return TICKET_STATUS.ACTIVE;
}

module.exports = {
  TICKET_STATUS,
  isValidTransition,
  canReserveSeat,
  isReservationExpired,
  isPastDeparture,
  canBeValidated,
  canInspectorValidate,
  nextStateAfterPayment
};
