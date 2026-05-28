const pool = require('../db');
const {
  findTodayAssignedTrip,
  verifyAndUseTicket,
} = require('../utils/ticketVerifier');
const { checkRateLimit } = require('../services/scanSecurity');

async function currentConductor(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const trip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  const assignedTrips = await findTodayAssignedTrips(conductor.conductor_id);
  return res.json({
    conductor: {
      ...conductor,
      id: conductor.conductor_id,
      name: conductor.full_name,
    },
    assignedTrip: trip,
    assignedTrips,
    assignedTripCount: assignedTrips.length,
    trip,
    message: trip ? 'Assigned trip loaded' : 'No trip assigned for today',
  });
}

async function trip(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  const assignedTrips = await findTodayAssignedTrips(conductor.conductor_id);
  if (!assignedTrip) {
    return res.json({
      trip: null,
      assignedTrips,
      assignedTripCount: assignedTrips.length,
      boardingList: [],
      boarded: 0,
      total: 0,
      stats: emptyStats(),
    });
  }

  const result = await pool.query(
    `SELECT tk.ticket_id, tk.seat_number, tk.status, tk.verified_at
     FROM tickets tk
     INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
     WHERE bk.trip_id = $1 AND bk.status = 'paid'
     ORDER BY tk.seat_number ASC`,
    [assignedTrip.trip_id]
  );

  const boarded = result.rows.filter((item) => item.status === 'used').length;
  const stats = await scanStats(conductor.conductor_id, assignedTrip.trip_id);
  return res.json({
    trip: assignedTrip,
    assignedTrips,
    assignedTripCount: assignedTrips.length,
    boardingList: result.rows.map((item) => ({
      seatNumber: item.seat_number,
      boarded: item.status === 'used',
      scannedAt: item.verified_at,
    })),
    boarded,
    total: result.rows.length,
    stats,
  });
}

async function scan(req, res) {
  const qrCode = String(req.body?.qrPayload || req.body?.qrCode || '').trim();
  if (!qrCode) {
    return res.status(400).json({ status: 'INVALID', message: 'Bad request' });
  }

  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const rate = checkRateLimit(conductor.conductor_id);
  if (rate.limited) {
    res.set('Retry-After', String(rate.retryAfter));
    return res.status(429).json({
      status: 'RATE_LIMITED',
      message: 'Too many scan attempts. Wait 1 minute.',
    });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  const result = await verifyAndUseTicket({
    pool,
    qrCode,
    conductorId: conductor.conductor_id,
    assignedTrip,
    req,
  });

  return res.json(result);
}

async function updateTripStatus(req, res) {
  const status = String(req.body?.status || '').trim().toUpperCase();
  if (!['BOARDING', 'DEPARTED', 'COMPLETED'].includes(status)) {
    return res.status(400).json({ error: 'status must be BOARDING, DEPARTED, or COMPLETED' });
  }

  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  if (!assignedTrip) {
    return res.status(404).json({ error: 'No assigned trip for today' });
  }

  const result = await pool.query(
    `UPDATE trips
     SET status = $1
     WHERE trip_id = $2 AND conductor_id = $3
     RETURNING trip_id, status`,
    [status, assignedTrip.trip_id, conductor.conductor_id]
  );

  return res.json({ trip: result.rows[0] });
}

async function stats(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  if (!assignedTrip) {
    return res.json(toSessionStats(null, 0, 0, emptyStats()));
  }

  const counts = await boardingCounts(assignedTrip.trip_id);
  return res.json({
    ...toSessionStats(
      assignedTrip,
      counts.boarded,
      counts.total,
      await scanStats(conductor.conductor_id, assignedTrip.trip_id)
    ),
  });
}

async function reportDuplicate(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.conductor_id);
  await pool.query(
    `INSERT INTO audit_logs (event_type, status, severity, email, user_id, ip_address, user_agent, details)
     VALUES ('duplicate_ticket_report', 'REPORTED', 'warning', $1, $2, $3, $4, $5)`,
    [
      req.user.email ?? null,
      req.user.user_id ?? null,
      req.ip ?? null,
      req.headers?.['user-agent'] ?? null,
      {
        conductorId: conductor.conductor_id,
        tripId: assignedTrip?.trip_id ?? null,
        ticketRef: req.body?.ticketRef ?? null,
        scannedAt: req.body?.scannedAt ?? null,
      },
    ]
  );

  return res.json({ message: 'Duplicate scan report recorded.' });
}

async function findConductor(req) {
  const result = await pool.query(
    `SELECT co.conductor_id,
            co.company_id,
            co.full_name,
            co.email,
            co.phone_number,
            co.badge_number,
            co.is_active,
            c.name AS company_name
     FROM conductors co
     INNER JOIN companies c ON c.company_id = co.company_id
     WHERE LOWER(co.email) = LOWER($1)
       AND co.is_active = TRUE
     LIMIT 1`,
    [req.user.email]
  );
  return result.rows[0] ?? null;
}

async function findTodayAssignedTrips(conductorId) {
  const result = await pool.query(
    `SELECT tr.trip_id, tr.departure_time, tr.arrival_time, tr.status,
            rs.origin, rs.destination, b.registration_number, b.capacity
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE tr.conductor_id = $1
       AND tr.departure_time::date = CURRENT_DATE
       AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')
     ORDER BY tr.departure_time ASC`,
    [conductorId]
  );

  return result.rows;
}

async function scanStats(conductorId, tripId) {
  const result = await pool.query(
    `SELECT
       COUNT(*)::int AS scans,
       COUNT(*) FILTER (WHERE result_status = 'VALID_BOARD')::int AS valid,
       COUNT(*) FILTER (WHERE result_status = 'ALREADY_USED')::int AS already_used,
       COUNT(*) FILTER (WHERE result_status = 'EXPIRED')::int AS expired,
       COUNT(*) FILTER (WHERE result_status = 'WRONG_TRIP')::int AS wrong_trip,
       COUNT(*) FILTER (WHERE result_status = 'FAKE_SIGNATURE')::int AS fake,
       COUNT(*) FILTER (WHERE result_status IN ('INVALID', 'INVALID_INPUT', 'NOT_FOUND', 'UNPAID'))::int AS invalid,
       COUNT(*) FILTER (WHERE fraud_alert = TRUE)::int AS fraud_alerts
     FROM ticket_scan_events
     WHERE conductor_id = $1
       AND created_at::date = CURRENT_DATE
       AND (
         ticket_id IS NULL
         OR ticket_id IN (
           SELECT tk.ticket_id
           FROM tickets tk
           INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
           WHERE bk.trip_id = $2
         )
       )`,
    [conductorId, tripId]
  );

  return result.rows[0] ?? emptyStats();
}

function emptyStats() {
  return {
    scans: 0,
    valid: 0,
    already_used: 0,
    expired: 0,
    wrong_trip: 0,
    fake: 0,
    invalid: 0,
    fraud_alerts: 0,
  };
}

async function boardingCounts(tripId) {
  const result = await pool.query(
    `SELECT
       COUNT(*)::int AS total,
       COUNT(*) FILTER (WHERE tk.status = 'used')::int AS boarded
     FROM tickets tk
     INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
     WHERE bk.trip_id = $1 AND bk.status = 'paid'`,
    [tripId]
  );

  return {
    boarded: result.rows[0]?.boarded ?? 0,
    total: result.rows[0]?.total ?? 0,
  };
}

function toSessionStats(trip, boarded, total, stats) {
  const route = trip ? `${trip.origin || 'Origin'} -> ${trip.destination || 'Destination'}` : null;
  return {
    trip,
    tripId: trip?.trip_id ?? null,
    route,
    totalCapacity: trip?.capacity ?? total,
    boarded,
    remaining: Math.max((trip?.capacity ?? total) - boarded, 0),
    scanBreakdown: {
      valid: stats.valid ?? 0,
      alreadyUsed: stats.already_used ?? 0,
      expired: stats.expired ?? 0,
      wrongTrip: stats.wrong_trip ?? 0,
      fake: stats.fake ?? 0,
      invalid: stats.invalid ?? 0,
    },
    fraudAlertsThisSession: stats.fraud_alerts ?? 0,
    sessionStarted: trip?.departure_time ?? null,
    stats,
  };
}

module.exports = {
  currentConductor,
  reportDuplicate,
  scan,
  stats,
  trip,
  updateTripStatus,
};
