/**
 * bookingFulfillment.js
 *
 * Single place that marks a booking as paid and issues tickets.
 * Called by both the payment status polling endpoint and the Lenco webhook
 * so that a payment confirmed via webhook is reflected exactly the same way
 * as one confirmed via polling.
 */

const pool = require('../db');
const jwt = require('jsonwebtoken');

/**
 * Mark a booking as paid and create its ticket if not already done.
 * Safe to call multiple times — all writes are idempotent.
 *
 * On success sets fulfillment_status = 'fulfilled'.
 * On failure sets fulfillment_status = 'failed' + fulfillment_error, then
 * rethrows so the caller (webhook / polling handler) can log to audit_logs.
 *
 * @param {number} bookingId
 * @param {string|null} financialTransactionId  Optional provider transaction ID.
 * @returns {Promise<void>}
 */
async function fulfillPaidBooking(bookingId, financialTransactionId = null) {
  await pool.query(
    `UPDATE bookings
     SET status = 'paid', updated_at = NOW()
     WHERE booking_id = $1 AND status <> 'paid'`,
    [bookingId]
  );

  try {
    await ensureTicketExists(bookingId);

    // Mark fulfillment as successful (idempotent — safe to set again if already fulfilled)
    await pool.query(
      `UPDATE bookings
       SET fulfillment_status = 'fulfilled', fulfillment_error = NULL, updated_at = NOW()
       WHERE booking_id = $1`,
      [bookingId]
    );
  } catch (err) {
    // Persist the failure so admins can see it and retry
    await pool.query(
      `UPDATE bookings
       SET fulfillment_status = 'failed',
           fulfillment_error  = $2,
           updated_at         = NOW()
       WHERE booking_id = $1`,
      [bookingId, err.message]
    ).catch(() => {}); // never let the audit write mask the original error

    throw err; // rethrow so webhook / polling handlers can log to audit_logs
  }
}

async function cancelUnpaidBooking(bookingId) {
  await pool.query(
    `UPDATE bookings
     SET status = 'cancelled', updated_at = NOW()
     WHERE booking_id = $1 AND status <> 'paid'`,
    [bookingId]
  );
}

/**
 * Create one ticket for a booking if none exists yet.
 * Uses ON CONFLICT DO NOTHING so it's safe to call repeatedly.
 */
async function ensureTicketExists(bookingId) {
  const existing = await pool.query(
    'SELECT ticket_id FROM tickets WHERE booking_id = $1 LIMIT 1',
    [bookingId]
  );

  if (existing.rowCount > 0) return;

  const bookingResult = await pool.query(
    `SELECT b.booking_id, b.booking_reference, u.name AS passenger_name
     FROM bookings b
     INNER JOIN users u ON u.user_id = b.user_id
     WHERE b.booking_id = $1`,
    [bookingId]
  );

  if (bookingResult.rowCount === 0) return;

  const booking = bookingResult.rows[0];
  const ticketNumber = `SMT-${booking.booking_reference}`;
  const qrPayload = buildTicketQrPayload({
    ticketNumber,
    bookingReference: booking.booking_reference,
  });

  await pool.query(
    `INSERT INTO tickets (booking_id, passenger_name, seat_number, ticket_number, qr_code_hash, status)
     VALUES ($1, $2, 'AUTO-1', $3, $4, 'active')
     ON CONFLICT (booking_id, seat_number) DO NOTHING`,
    [
      booking.booking_id,
      booking.passenger_name || 'SecureMove Passenger',
      ticketNumber,
      qrPayload,
    ]
  );
}

function buildTicketQrPayload({ ticketNumber, bookingReference }) {
  const secret = process.env.TICKET_SECRET || process.env.TICKET_QR_SECRET;
  if (!secret || secret.length < 64) {
    throw new Error('TICKET_SECRET must be set and at least 64 characters long.');
  }

  return jwt.sign(
    {
      typ: 'securemove.ticket',
      ticketNumber,
      bookingReference,
      nonce: `${ticketNumber}-${Date.now()}`,
    },
    secret,
    {
      algorithm: 'HS256',
      issuer: 'securemove-api',
      audience: 'securemove-conductor',
      expiresIn: process.env.TICKET_QR_TTL || '36h',
    }
  );
}

module.exports = { cancelUnpaidBooking, fulfillPaidBooking };
