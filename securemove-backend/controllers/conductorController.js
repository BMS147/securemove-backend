const pool = require('../db');
const {
  findTodayAssignedTrip,
  verifyAndUseTicket,
} = require('../utils/ticketVerifier');

async function currentConductor(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const trip = await findTodayAssignedTrip(pool, conductor.driver_id);
  return res.json({
    conductor: {
      ...conductor,
      id: conductor.driver_id,
      name: conductor.full_name,
    },
    assignedTrip: trip,
    trip,
    message: trip ? 'Assigned trip loaded' : 'No trip assigned for today',
  });
}

async function trip(req, res) {
  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.driver_id);
  if (!assignedTrip) {
    return res.json({ trip: null, boardingList: [], boarded: 0, total: 0 });
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
  return res.json({
    trip: assignedTrip,
    boardingList: result.rows.map((item) => ({
      seatNumber: item.seat_number,
      boarded: item.status === 'used',
      scannedAt: item.verified_at,
    })),
    boarded,
    total: result.rows.length,
  });
}

async function scan(req, res) {
  const qrCode = String(req.body?.qrCode || '').trim();
  if (!qrCode) {
    return res.status(400).json({ status: 'INVALID', message: 'Ticket not found or tampered' });
  }

  const conductor = await findConductor(req);
  if (!conductor) {
    return res.status(404).json({ error: 'No conductor profile is linked to this login email' });
  }

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.driver_id);
  const result = await verifyAndUseTicket({
    pool,
    qrCode,
    conductorId: conductor.driver_id,
    assignedTrip,
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

  const assignedTrip = await findTodayAssignedTrip(pool, conductor.driver_id);
  if (!assignedTrip) {
    return res.status(404).json({ error: 'No assigned trip for today' });
  }

  const result = await pool.query(
    `UPDATE trips
     SET status = $1
     WHERE trip_id = $2 AND (conductor_id = $3 OR driver_id = $3)
     RETURNING trip_id, status`,
    [status, assignedTrip.trip_id, conductor.driver_id]
  );

  return res.json({ trip: result.rows[0] });
}

async function findConductor(req) {
  const result = await pool.query(
    `SELECT d.driver_id, d.company_id, d.full_name, d.email, d.phone_number, d.license_number, d.is_active, c.name AS company_name
     FROM drivers d
     INNER JOIN companies c ON c.company_id = d.company_id
     WHERE LOWER(d.email) = LOWER($1)
     LIMIT 1`,
    [req.user.email]
  );
  return result.rows[0] ?? null;
}

module.exports = {
  currentConductor,
  scan,
  trip,
  updateTripStatus,
};
