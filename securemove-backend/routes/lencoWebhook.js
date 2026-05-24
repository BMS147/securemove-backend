/**
 * Lenco webhook handler
 *
 * Mounted at POST /webhooks/lenco BEFORE express.json() so that the raw
 * request body is available for HMAC-SHA512 signature verification.
 *
 * Lenco sends:
 *   Header: X-Lenco-Signature = HMAC-SHA512(SHA256(secretKey), JSON.stringify(body))
 *   Body:   { event: "collection.successful"|"collection.failed"|"collection.settled",
 *             data: { id, reference, status, ... } }
 *
 *   data.reference = OUR reference string (e.g. SM-BK42-A1B2C3D4)
 *   data.id        = Lenco's internal UUID (not stored by us)
 *
 * Security:
 *   - Signature verified with constant-time comparison before any DB work.
 *   - Responds 200 immediately after queueing the DB update (Lenco retries on non-2xx for 24 h).
 *   - All DB writes are idempotent — safe if Lenco delivers the same event twice.
 */

const express = require('express');
const pool = require('../db');
const { verifyWebhookSignature } = require('../services/lencoService');
const { fulfillPaidBooking } = require('../services/bookingFulfillment');

const router = express.Router();

// express.raw() is applied by server.js for this route path — body arrives as Buffer
router.post('/', async (req, res) => {
  const rawBody = req.body; // Buffer, set by express.raw()
  const signature = req.headers['x-lenco-signature'];

  // --- 1. Verify signature -------------------------------------------------
  if (!signature || !verifyWebhookSignature(rawBody, signature)) {
    console.warn('[Lenco webhook] Invalid or missing X-Lenco-Signature — rejecting');
    return res.status(401).json({ error: 'Invalid webhook signature' });
  }

  // --- 2. Parse body -------------------------------------------------------
  let event;
  try {
    event = JSON.parse(rawBody.toString('utf8'));
  } catch {
    return res.status(400).json({ error: 'Malformed JSON body' });
  }

  const eventType = event.event;
  const data = event.data || {};

  // Our reference is stored in data.reference (what we sent when initiating the collection)
  const ourReference = data.reference;
  const lencoStatus = String(data.status || '').toLowerCase();

  console.log(`[Lenco webhook] event=${eventType} reference=${ourReference} status=${lencoStatus}`);

  // Acknowledge immediately — Lenco retries on non-2xx for 24 hours
  res.status(200).json({ received: true });

  // --- 3. Process asynchronously after response is sent -------------------
  // collection.settled fires after funds actually move; treat like successful
  if (!['collection.successful', 'collection.failed', 'collection.settled'].includes(eventType)) {
    console.log(`[Lenco webhook] Ignoring unhandled event type: ${eventType}`);
    return;
  }

  if (!ourReference) {
    console.warn('[Lenco webhook] Event missing data.reference — cannot correlate payment');
    return;
  }

  try {
    // Find the payment by OUR reference stored in transaction_reference
    const paymentResult = await pool.query(
      `SELECT p.payment_id, p.booking_id, p.status AS payment_status,
              b.status AS booking_status
       FROM payments p
       INNER JOIN bookings b ON b.booking_id = p.booking_id
       WHERE p.transaction_reference = $1
       LIMIT 1`,
      [ourReference]
    );

    if (paymentResult.rowCount === 0) {
      console.warn(`[Lenco webhook] No payment found for reference ${ourReference}`);
      return;
    }

    const payment = paymentResult.rows[0];

    // Map Lenco event to our internal status
    const nextStatus =
      eventType === 'collection.failed' ? 'failed' : 'successful';

    // Skip if already in a terminal state (idempotency guard)
    if (['successful', 'failed'].includes(payment.payment_status)) {
      console.log(
        `[Lenco webhook] Payment ${payment.payment_id} already terminal (${payment.payment_status}) — skipping`
      );
      return;
    }

    // Update payment status
    await pool.query(
      `UPDATE payments
       SET status = $1, updated_at = NOW()
       WHERE payment_id = $2`,
      [nextStatus, payment.payment_id]
    );

    // If successful → mark booking paid + issue ticket
    if (nextStatus === 'successful') {
      await fulfillPaidBooking(
        payment.booking_id,
        data.transactionReference || data.nipSessionId || null
      );
      console.log(`[Lenco webhook] Booking ${payment.booking_id} fulfilled — ticket issued`);
    }

    console.log(`[Lenco webhook] Payment ${payment.payment_id} updated to ${nextStatus}`);
  } catch (err) {
    console.error('[Lenco webhook] Processing error:', err.message);
  }
});

module.exports = router;
