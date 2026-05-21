function initiateMockPayment({ provider }) {
  return {
    referenceId: `MOCK-${provider.toUpperCase()}-${Date.now()}`,
    provider,
    status: 'PENDING',
  };
}

function getMockPaymentStatus(payment) {
  const createdAt = payment.created_at ? new Date(payment.created_at) : new Date();
  const elapsedMs = Date.now() - createdAt.getTime();

  if (elapsedMs >= 6000) {
    return {
      referenceId: payment.transaction_reference,
      status: 'successful',
      reason: null,
      financialTransactionId: payment.transaction_reference,
      externalId: payment.booking_id,
      raw: { mode: 'mock', provider: payment.provider },
    };
  }

  return {
    referenceId: payment.transaction_reference,
    status: 'pending',
    reason: null,
    financialTransactionId: null,
    externalId: payment.booking_id,
    raw: { mode: 'mock', provider: payment.provider },
  };
}

module.exports = {
  initiateMockPayment,
  getMockPaymentStatus,
};
