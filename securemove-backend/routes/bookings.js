const crypto = require('crypto');
const express = require('express');

const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');

const router = express.Router();

router.post('/reserve', authenticateToken, async (req, res) => {
  const { trip_id, total_amount } = req.body ?? {};

  if (!trip_id || total_amount == null) {
    return res.status(400).json({ error: 'trip_id and total_amount are required' });
  }

  try {
    const tripResult = await pool.query('SELECT trip_id FROM trips WHERE trip_id = $1', [trip_id]);

    if (tripResult.rowCount === 0) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const bookingReference = buildBookingReference();
    const result = await pool.query(
      `INSERT INTO bookings (user_id, trip_id, booking_reference, total_amount, status)
       VALUES ($1, $2, $3, $4, 'reserved')
       RETURNING booking_id, user_id, trip_id, booking_reference, total_amount, status, created_at, updated_at`,
      [req.user.user_id, trip_id, bookingReference, total_amount]
    );

    return res.status(201).json({ booking: result.rows[0] });
  } catch (err) {
    console.error('Reserve booking error:', err.message);
    return res.status(500).json({ error: 'Unable to create booking' });
  }
});

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.booking_id, b.user_id, b.trip_id, b.booking_reference, b.total_amount,
              CASE WHEN b.status = 'paid' THEN 'paid' ELSE 'cancelled' END AS status,
              b.created_at, b.updated_at,
              t.departure_time, t.status AS trip_status,
              rs.origin, rs.destination,
              c.name AS company_name
       FROM bookings b
       INNER JOIN trips t ON t.trip_id = b.trip_id
       LEFT JOIN route_schedules rs ON rs.schedule_id = t.schedule_id
       LEFT JOIN companies c ON c.company_id = rs.company_id
       WHERE b.user_id = $1
       ORDER BY b.created_at DESC`,
      [req.user.user_id]
    );

    return res.json({ bookings: result.rows });
  } catch (err) {
    console.error('Fetch my bookings error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch bookings' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  const bookingId = Number.parseInt(req.params.id, 10);

  if (!Number.isInteger(bookingId) || bookingId <= 0) {
    return res.status(400).json({ error: 'A valid booking id is required' });
  }

  try {
    const result = await pool.query(
      `SELECT booking_id, user_id, trip_id, booking_reference, total_amount,
              CASE WHEN status = 'paid' THEN 'paid' ELSE 'cancelled' END AS status,
              created_at, updated_at
       FROM bookings
       WHERE booking_id = $1 AND user_id = $2`,
      [bookingId, req.user.user_id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    return res.json({ booking: result.rows[0] });
  } catch (err) {
    console.error('Fetch booking error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch booking' });
  }
});

router.post('/:id/cancel', authenticateToken, async (req, res) => {
  const bookingId = Number.parseInt(req.params.id, 10);

  if (!Number.isInteger(bookingId) || bookingId <= 0) {
    return res.status(400).json({ error: 'A valid booking id is required' });
  }

  try {
    const result = await pool.query(
      `UPDATE bookings
       SET status = 'cancelled', updated_at = NOW()
       WHERE booking_id = $1 AND user_id = $2
       RETURNING booking_id, status, updated_at`,
      [bookingId, req.user.user_id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    return res.json({ booking: result.rows[0] });
  } catch (err) {
    console.error('Cancel booking error:', err.message);
    return res.status(500).json({ error: 'Unable to cancel booking' });
  }
});

function buildBookingReference() {
  return `SM-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
}

module.exports = router;
