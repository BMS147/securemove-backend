const crypto = require('crypto');
const express = require('express');

const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');

const router = express.Router();

router.post('/reserve', authenticateToken, async (req, res) => {
  const { trip_id, schedule_id, travel_date, total_amount } = req.body ?? {};

  if ((!trip_id && !schedule_id) || total_amount == null) {
    return res.status(400).json({ error: 'trip_id or schedule_id, and total_amount are required' });
  }

  try {
    const tripId = trip_id
      ? await findTripId(trip_id)
      : await findOrCreateTripFromSchedule({ scheduleId: schedule_id, travelDate: travel_date });

    if (!tripId) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const bookingReference = buildBookingReference();
    const result = await pool.query(
      `INSERT INTO bookings (user_id, trip_id, booking_reference, total_amount, status)
       VALUES ($1, $2, $3, $4, 'reserved')
       RETURNING booking_id, user_id, trip_id, booking_reference, total_amount, status, created_at, updated_at`,
      [req.user.user_id, tripId, bookingReference, total_amount]
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

async function findTripId(tripId) {
  const tripResult = await pool.query('SELECT trip_id FROM trips WHERE trip_id = $1', [tripId]);
  return tripResult.rows[0]?.trip_id ?? null;
}

async function findOrCreateTripFromSchedule({ scheduleId, travelDate }) {
  const parsedScheduleId = Number.parseInt(scheduleId, 10);
  if (!Number.isInteger(parsedScheduleId) || parsedScheduleId <= 0) {
    return null;
  }

  const scheduleResult = await pool.query(
    `SELECT rs.schedule_id, rs.departure_time, rs.duration_minutes, rs.company_id,
            b.bus_id, b.capacity
     FROM route_schedules rs
     LEFT JOIN LATERAL (
       SELECT bus_id, capacity
       FROM buses
       WHERE company_id = rs.company_id AND is_active = TRUE
       ORDER BY bus_id ASC
       LIMIT 1
     ) b ON TRUE
     WHERE rs.schedule_id = $1 AND rs.active = TRUE`,
    [parsedScheduleId]
  );

  const schedule = scheduleResult.rows[0];
  if (!schedule) {
    return null;
  }

  const departureAt = buildDepartureDateTime({
    travelDate,
    departureLabel: schedule.departure_time,
  });
  if (!departureAt) {
    return null;
  }

  const existingTrip = await pool.query(
    `SELECT trip_id
     FROM trips
     WHERE schedule_id = $1
       AND departure_time::date = $2::date
       AND status IN ('scheduled', 'boarding', 'BOARDING')
     ORDER BY departure_time ASC
     LIMIT 1`,
    [parsedScheduleId, departureAt.toISOString()]
  );
  if (existingTrip.rowCount > 0) {
    return existingTrip.rows[0].trip_id;
  }

  const arrivalAt = new Date(departureAt);
  arrivalAt.setMinutes(arrivalAt.getMinutes() + Number(schedule.duration_minutes || 0));

  const createdTrip = await pool.query(
    `INSERT INTO trips (schedule_id, bus_id, departure_time, arrival_time, available_seats, status)
     VALUES ($1, $2, $3, $4, $5, 'scheduled')
     RETURNING trip_id`,
    [
      parsedScheduleId,
      schedule.bus_id ?? null,
      departureAt.toISOString(),
      arrivalAt.toISOString(),
      schedule.capacity ?? 10,
    ]
  );

  return createdTrip.rows[0]?.trip_id ?? null;
}

function buildDepartureDateTime({ travelDate, departureLabel }) {
  const dateText = String(travelDate || '').trim();
  const dateMatch = dateText.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!dateMatch) {
    return null;
  }

  const time = parseDepartureLabel(departureLabel);
  if (!time) {
    return null;
  }

  const [, year, month, day] = dateMatch;
  return new Date(Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    time.hour - 2,
    time.minute,
    0,
    0
  ));
}

function parseDepartureLabel(value) {
  const raw = String(value || '').trim();
  const twelveHour = raw.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (twelveHour) {
    let hour = Number.parseInt(twelveHour[1], 10);
    const minute = Number.parseInt(twelveHour[2], 10);
    const meridiem = twelveHour[3].toUpperCase();
    if (meridiem === 'PM' && hour !== 12) hour += 12;
    if (meridiem === 'AM' && hour === 12) hour = 0;
    return { hour, minute };
  }

  const twentyFourHour = raw.match(/^(\d{1,2}):(\d{2})/);
  if (twentyFourHour) {
    return {
      hour: Number.parseInt(twentyFourHour[1], 10),
      minute: Number.parseInt(twentyFourHour[2], 10),
    };
  }

  return null;
}

module.exports = router;
