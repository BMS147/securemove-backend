const crypto = require('crypto');
const express = require('express');

const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');
const {
  getMtnConfig,
  getRequestToPayStatus,
  requestToPay,
} = require('../services/mtnMomoService');
const {
  getAirtelConfig,
  getPaymentStatus: getAirtelPaymentStatus,
  requestPayment: requestAirtelPayment,
} = require('../services/airtelMoneyService');
const {
  getMockPaymentStatus,
  initiateMockPayment,
} = require('../services/mockMobileMoneyService');
const {
  getLencoConfig,
  initiateCollection: lencoInitiateCollection,
  getCollectionStatus: lencoGetCollectionStatus,
} = require('../services/lencoService');
const { fulfillPaidBooking } = require('../services/bookingFulfillment');

const router = express.Router();


router.post('/create-intent', async (req, res) => {
  const { amount, currency = 'usd', description } = req.body ?? {};
  const secretKey = process.env.STRIPE_SECRET_KEY;

  if (!Number.isInteger(amount) || amount <= 0) {
    return res.status(400).json({ error: 'A positive integer amount is required' });
  }

  if (typeof currency !== 'string' || currency.trim().length !== 3) {
    return res.status(400).json({ error: 'Currency must be a 3-letter ISO code' });
  }

  if (!secretKey || secretKey === 'sk_test_your_secret_key') {
    return res.status(500).json({ error: 'Stripe is not configured. Set STRIPE_SECRET_KEY in .env' });
  }

  try {
    const payload = new URLSearchParams({
      amount: String(amount),
      currency: currency.trim().toLowerCase(),
    });

    payload.append('automatic_payment_methods[enabled]', 'true');

    if (description) {
      payload.append('description', String(description));
    }

    const stripeResponse = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: payload,
    });

    const stripeData = await stripeResponse.json();

    if (!stripeResponse.ok) {
      console.error('Stripe create intent error:', stripeData);
      return res.status(stripeResponse.status).json({
        error: stripeData.error?.message || 'Unable to create payment intent',
        code: stripeData.error?.code,
        param: stripeData.error?.param,
      });
    }

    return res.status(201).json({
      paymentIntentId: stripeData.id,
      clientSecret: stripeData.client_secret,
      amount: stripeData.amount,
      currency: stripeData.currency,
      status: stripeData.status,
    });
  } catch (err) {
    console.error('Create payment intent error:', err.message);
    return res.status(500).json({ error: 'Server error while creating payment intent' });
  }
});

router.get('/mobile-money/config', authenticateToken, async (req, res) => {
  const mtn = getMtnConfig();
  const airtel = getAirtelConfig();
  const lenco = getLencoConfig();
  const mode = getMobileMoneyMode();
  const enabled = Boolean(mtn.enabled || airtel.enabled || lenco.enabled || mode === 'mock');

  if (!enabled) {
    return res.json({
      enabled: false,
      message: 'Mobile money not configured',
      currency: 'ZMW',
      providers: {
        mtn: { enabled: false, simulated: false },
        airtel: { enabled: false, simulated: false },
      },
    });
  }

  const isMock = mode === 'mock';
  const isLenco = mode === 'lenco';

  return res.json({
    provider: isLenco ? 'Lenco' : mtn.enabled ? 'MTN Mobile Money' : 'Airtel Money',
    merchantCode: process.env.MOBILE_MONEY_MERCHANT_CODE || 'not-configured',
    currency: 'ZMW',
    enabled: true,
    mode,
    providers: {
      mtn: {
        enabled: isLenco ? true : Boolean(mtn.enabled),
        simulated: isMock && !mtn.enabled,
      },
      airtel: {
        enabled: isLenco ? true : Boolean(airtel.enabled),
        simulated: isMock && !airtel.enabled,
      },
    },
  });
});

router.post('/mobile-money/initiate', authenticateToken, async (req, res) => {
  const { bookingId, provider, phoneNumber, amount } = req.body ?? {};
  const normalizedProvider = String(provider || '').trim().toLowerCase();
  const parsedBookingId = Number.parseInt(bookingId, 10);
  const parsedAmount = Number.parseFloat(amount);
  const mobileMoneyMode = getMobileMoneyMode();

  if (!Number.isInteger(parsedBookingId) || parsedBookingId <= 0) {
    return res.status(400).json({ error: 'A valid bookingId is required' });
  }
  if (!phoneNumber || String(phoneNumber).trim().length < 10) {
    return res.status(400).json({ error: 'A valid phoneNumber is required' });
  }
  if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
    return res.status(400).json({ error: 'A positive amount is required' });
  }
  if (!['mtn', 'airtel'].includes(normalizedProvider)) {
    return res.status(400).json({ error: 'provider must be mtn or airtel' });
  }

  try {
    const bookingResult = await pool.query(
      `SELECT booking_id, user_id, trip_id, total_amount, status
       FROM bookings
       WHERE booking_id = $1 AND user_id = $2`,
      [parsedBookingId, req.user.user_id]
    );

    if (bookingResult.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const booking = bookingResult.rows[0];
    if (booking.status === 'paid') {
      return res.status(409).json({ error: 'This booking is already paid' });
    }

    let transactionReference;
    let providerStatusLabel;

    if (mobileMoneyMode === 'lenco') {
      // Lenco handles both MTN and Airtel — operator comes from the provider field
      const lencoRef = buildLencoReference(booking.booking_id);
      const result = await lencoInitiateCollection({
        amount: parsedAmount,
        reference: lencoRef,
        phone: String(phoneNumber).trim(),
        operator: normalizedProvider, // 'mtn' or 'airtel'
      });

      // MTN (and occasionally Airtel) can reject immediately before a USSD
      // prompt is ever sent — e.g. insufficient funds or withdrawal limit.
      // Return a 402 straight away so the app shows the real reason instead
      // of storing a doomed pending payment and waiting for polling to fail.
      if (result.status === 'failed') {
        const reason = result.reason || 'Payment was declined by the mobile money provider.';
        return res.status(402).json({ error: reason });
      }

      // Store OUR reference so we can poll /collections/status/:reference and match webhooks by data.reference
      transactionReference = result.ourReference;
      providerStatusLabel = result.status;
    } else if (mobileMoneyMode === 'live' && normalizedProvider === 'mtn') {
      const result = await requestToPay({
        amount: parsedAmount,
        phoneNumber: String(phoneNumber).trim(),
        externalId: booking.booking_id,
        payerMessage: 'SecureMove bus ticket payment',
        payeeNote: `Booking ${booking.booking_id}`,
      });
      transactionReference = result.referenceId;
      providerStatusLabel = result.status;
    } else if (mobileMoneyMode === 'live' && normalizedProvider === 'airtel') {
      const result = await requestAirtelPayment({
        amount: parsedAmount,
        phoneNumber: String(phoneNumber).trim(),
        externalId: booking.booking_id,
      });
      transactionReference = result.referenceId;
      providerStatusLabel = result.status;
    } else {
      const result = initiateMockPayment({ provider: normalizedProvider });
      transactionReference = result.referenceId;
      providerStatusLabel = result.status;
    }

    const insertResult = await pool.query(
      `INSERT INTO payments (
        booking_id,
        amount,
        payment_method,
        provider,
        phone_number,
        transaction_reference,
        status,
        updated_at
      )
      VALUES ($1, $2, 'mobile_money', $3, $4, $5, 'pending', NOW())
      RETURNING payment_id, booking_id, amount, payment_method, provider, phone_number, transaction_reference, status, created_at, updated_at`,
      [
        booking.booking_id,
        parsedAmount,
        normalizedProvider,
        String(phoneNumber).trim(),
        transactionReference,
      ]
    );

    const modeMessages = {
      lenco: 'Payment request submitted to Lenco. The customer will receive a prompt on their phone to approve.',
      live:  'Payment request submitted. Awaiting customer approval.',
      mock:  'Mock payment created. It will settle automatically after a short delay.',
    };

    return res.status(202).json({
      payment: insertResult.rows[0],
      providerStatus: providerStatusLabel,
      message: modeMessages[mobileMoneyMode] || modeMessages.mock,
    });
  } catch (err) {
    console.error('Initiate mobile money payment error:', err.message);
    return res.status(500).json({ error: err.message || 'Unable to initiate mobile money payment' });
  }
});

router.get('/:paymentId/status', authenticateToken, async (req, res) => {
  const paymentId = Number.parseInt(req.params.paymentId, 10);
  const mobileMoneyMode = getMobileMoneyMode();
  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ error: 'A valid paymentId is required' });
  }

  try {
    const paymentResult = await pool.query(
      `SELECT p.payment_id, p.booking_id, p.amount, p.payment_method, p.provider, p.phone_number, p.transaction_reference, p.status, p.created_at,
              b.user_id, b.status AS booking_status
       FROM payments p
       INNER JOIN bookings b ON b.booking_id = p.booking_id
       WHERE p.payment_id = $1 AND b.user_id = $2`,
      [paymentId, req.user.user_id]
    );

    if (paymentResult.rowCount === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    const payment = paymentResult.rows[0];

    // For Lenco, the webhook is the primary update mechanism.
    // Polling still calls the Lenco API as a fallback for missed webhooks.
    let providerStatus;
    if (mobileMoneyMode === 'lenco') {
      if (['successful', 'failed'].includes(payment.status)) {
        // Already in a terminal state — return DB value without calling Lenco
        providerStatus = { status: payment.status, reason: null };
      } else {
        providerStatus = await lencoGetCollectionStatus(payment.transaction_reference);
      }
    } else if (mobileMoneyMode === 'live' && payment.provider === 'mtn') {
      providerStatus = await getRequestToPayStatus(payment.transaction_reference);
    } else if (mobileMoneyMode === 'live' && payment.provider === 'airtel') {
      providerStatus = await getAirtelPaymentStatus(payment.transaction_reference);
    } else {
      providerStatus = getMockPaymentStatus(payment);
    }

    const nextStatus = providerStatus.status;

    // Only write to DB if status actually changed (avoid unnecessary updates)
    if (nextStatus !== payment.status) {
      await pool.query(
        `UPDATE payments
         SET status = $1, updated_at = NOW()
         WHERE payment_id = $2`,
        [nextStatus, payment.payment_id]
      );

      if (nextStatus === 'successful') {
        try {
          await fulfillPaidBooking(payment.booking_id, providerStatus.financialTransactionId || null);
        } catch (fulfillErr) {
          console.error(
            `[Payment polling] Fulfillment failed for booking ${payment.booking_id}:`,
            fulfillErr.message
          );
          await pool.query(
            `INSERT INTO audit_logs (event_type, status, severity, details)
             VALUES ('ticket_fulfillment_failed', 'failed', 'high', $1)`,
            [JSON.stringify({
              bookingId: payment.booking_id,
              paymentId: payment.payment_id,
              error: fulfillErr.message,
            })]
          ).catch(() => {});
        }
      }
    }

    const refreshed = await pool.query(
      `SELECT payment_id, booking_id, amount, payment_method, provider, phone_number, transaction_reference, status, created_at, updated_at
       FROM payments
       WHERE payment_id = $1`,
      [payment.payment_id]
    );

    const response = { payment: refreshed.rows[0], providerStatus };

    // When payment succeeds, include the generated tickets so the client can
    // immediately display QR codes without an extra round-trip.
    if (refreshed.rows[0].status === 'successful') {
      const ticketsResult = await pool.query(
        `SELECT ticket_id, passenger_name, seat_number, ticket_number, status, created_at
         FROM tickets
         WHERE booking_id = $1
         ORDER BY ticket_id ASC`,
        [payment.booking_id]
      );
      response.tickets = ticketsResult.rows;
    }

    return res.json(response);
  } catch (err) {
    console.error('Check payment status error:', err.message);
    return res.status(500).json({ error: err.message || 'Unable to check payment status' });
  }
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildLencoReference(bookingId) {
  // Lenco accepts alphanumeric, hyphen, dot, underscore — max length not documented
  return `SM-BK${bookingId}-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
}

function getMobileMoneyMode() {
  return (process.env.MOBILE_MONEY_MODE || 'mock').trim().toLowerCase();
}

module.exports = router;
