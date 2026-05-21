// services/paymentService.js

const { 
  TICKET_STATUS, 
  isValidTransition,
  nextStateAfterPayment 
} = require('./ticketService');

/**
 * Validate that ticket can be paid
 */
function canProcessPayment(ticket, userId) {
  if (!ticket) {
    return { valid: false, reason: 'TICKET_NOT_FOUND' };
  }

  if (ticket.user_id !== userId) {
    return { valid: false, reason: 'NOT_OWNER' };
  }

  if (!isValidTransition(ticket.status, TICKET_STATUS.PAID)) {
    return { valid: false, reason: 'INVALID_STATE' };
  }

  return { valid: true };
}

/**
 * Determine ticket state updates after payment
 */
function processPaymentState(ticket) {
  return {
    status: nextStateAfterPayment(),
    paid_at: new Date(),
    activated_at: new Date()
  };
}

module.exports = {
  canProcessPayment,
  processPaymentState
};
