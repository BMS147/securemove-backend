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

const router = express.Router();

async function ensureTicketsForBooking(bookingId) {
  const existing = await pool.query(
    'SELECT ticket_id FROM tickets WHERE booking_id = $1 LIMIT 1',
    [bookingId]
  );

  if (existing.rowCount > 0) {
    return;
  }

  const bookingResult = await pool.query(
    `SELECT b.booking_id, b.booking_reference, u.name AS passenger_name
     FROM bookings b
     INNER JOIN users u ON u.user_id = b.user_id
     WHERE b.booking_id = $1`,
    [bookingId]
  );

  if (bookingResult.rowCount === 0) {
    return;
  }

  const booking = bookingResult.rows[0];
  await pool.query(
    `INSERT INTO tickets (
      booking_id,
      passenger_name,
      seat_number,
      ticket_number,
      qr_code_hash,
      status
    )
    VALUES ($1, $2, $3, $4, $5, 'active')
    ON CONFLICT (booking_id, seat_number) DO NOTHING`,
    [
      booking.booking_id,
      booking.passenger_name || 'SecureMove passenger',
      'AUTO-1',
      `SMT-${booking.booking_reference}`,
      booking.booking_reference,
    ]
  );
}

function getMobileMoneyMode() {
  return (process.env.MOBILE_MONEY_MODE || 'mock').trim().toLowerCase();
}

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
  const mode = getMobileMoneyMode();
  const enabled = Boolean(mtn.enabled || airtel.enabled || mode === 'mock');
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

  return res.json({
    provider: mtn.enabled ? 'MTN Mobile Money' : 'Airtel Money',
    merchantCode: process.env.MOBILE_MONEY_MERCHANT_CODE || 'not-configured',
    currency: 'ZMW',
    enabled: true,
    mode,
    providers: {
      mtn: { enabled: Boolean(mtn.enabled), simulated: mode === 'mock' && !mtn.enabled },
      airtel: { enabled: Boolean(airtel.enabled), simulated: mode === 'mock' && !airtel.enabled },
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

    let paymentResult;
    if (mobileMoneyMode === 'live' && normalizedProvider === 'mtn') {
      paymentResult = await requestToPay({
        amount: parsedAmount,
        phoneNumber: String(phoneNumber).trim(),
        externalId: booking.booking_id,
        payerMessage: 'SecureMove bus ticket payment',
        payeeNote: `Booking ${booking.booking_id}`,
      });
    } else if (mobileMoneyMode === 'live' && normalizedProvider === 'airtel') {
      paymentResult = await requestAirtelPayment({
        amount: parsedAmount,
        phoneNumber: String(phoneNumber).trim(),
        externalId: booking.booking_id,
      });
    } else {
      paymentResult = initiateMockPayment({ provider: normalizedProvider });
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
        paymentResult.referenceId,
      ]
    );

    return res.status(202).json({
      payment: insertResult.rows[0],
      providerStatus: paymentResult.status,
      message:
        mobileMoneyMode === 'live'
          ? 'Payment request submitted. Awaiting customer approval.'
          : 'Mock mobile money request created. It will settle automatically after a short delay.',
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

    let providerStatus;
    if (mobileMoneyMode === 'live' && payment.provider === 'mtn') {
      providerStatus = await getRequestToPayStatus(payment.transaction_reference);
    } else if (mobileMoneyMode === 'live' && payment.provider === 'airtel') {
      providerStatus = await getAirtelPaymentStatus(payment.transaction_reference);
    } else {
      providerStatus = getMockPaymentStatus(payment);
    }
    const nextStatus = providerStatus.status;

    await pool.query(
      `UPDATE payments
       SET status = $1,
           updated_at = NOW()
       WHERE payment_id = $2`,
      [nextStatus, payment.payment_id]
    );

    if (nextStatus === 'successful') {
      await pool.query(
        `UPDATE bookings
         SET status = 'paid',
             updated_at = NOW()
         WHERE booking_id = $1`,
        [payment.booking_id]
      );
      await ensureTicketsForBooking(payment.booking_id);
    }

    const refreshed = await pool.query(
      `SELECT payment_id, booking_id, amount, payment_method, provider, phone_number, transaction_reference, status, created_at, updated_at
       FROM payments
       WHERE payment_id = $1`,
      [payment.payment_id]
    );

    return res.json({
      payment: refreshed.rows[0],
      providerStatus,
    });
  } catch (err) {
    console.error('Check payment status error:', err.message);
    return res.status(500).json({ error: err.message || 'Unable to check payment status' });
  }
});

module.exports = router;
