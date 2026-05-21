const express = require('express');

const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');

const router = express.Router();

router.get('/booking/:bookingId', authenticateToken, async (req, res) => {
  const bookingId = Number.parseInt(req.params.bookingId, 10);

  if (!Number.isInteger(bookingId) || bookingId <= 0) {
    return res.status(400).json({ error: 'A valid booking id is required' });
  }

  try {
    const bookingResult = await pool.query(
      'SELECT booking_id FROM bookings WHERE booking_id = $1 AND user_id = $2',
      [bookingId, req.user.user_id]
    );

    if (bookingResult.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const result = await pool.query(
      `SELECT ticket_id, booking_id, passenger_name, seat_number, ticket_number, qr_code_hash, status, verified_at, verified_by_driver_id, created_at
       FROM tickets
       WHERE booking_id = $1
       ORDER BY ticket_id ASC`,
      [bookingId]
    );

    return res.json({ tickets: result.rows });
  } catch (err) {
    console.error('Fetch booking tickets error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch tickets' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  const ticketId = Number.parseInt(req.params.id, 10);

  if (!Number.isInteger(ticketId) || ticketId <= 0) {
    return res.status(400).json({ error: 'A valid ticket id is required' });
  }

  try {
    const result = await pool.query(
      `SELECT t.ticket_id, t.booking_id, t.passenger_name, t.seat_number, t.ticket_number, t.qr_code_hash, t.status, t.verified_at, t.verified_by_driver_id, t.created_at
       FROM tickets t
       INNER JOIN bookings b ON b.booking_id = t.booking_id
       WHERE t.ticket_id = $1 AND b.user_id = $2`,
      [ticketId, req.user.user_id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Ticket not found' });
    }

    return res.json({ ticket: result.rows[0] });
  } catch (err) {
    console.error('Fetch ticket error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch ticket' });
  }
});

module.exports = router;
