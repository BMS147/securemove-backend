const jwt = require('jsonwebtoken');

const DEFAULT_EXPIRY_BUFFER_MINUTES = 30;

function verifySignedTicket(qrCode) {
  const secret = process.env.TICKET_QR_SECRET || process.env.JWT_SECRET || 'supersecretkey';
  return jwt.verify(qrCode, secret);
}

async function findTodayAssignedTrip(pool, conductorId) {
  const result = await pool.query(
    `SELECT tr.trip_id, tr.departure_time, tr.arrival_time, tr.status,
            rs.origin, rs.destination, b.registration_number, b.capacity
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE (tr.conductor_id = $1 OR tr.driver_id = $1)
       AND tr.departure_time::date = CURRENT_DATE
       AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')
     ORDER BY tr.departure_time ASC
     LIMIT 1`,
    [conductorId]
  );

  return result.rows[0] ?? null;
}

async function logScan(pool, { ticketId, conductorId, status, details }) {
  await pool.query(
    `INSERT INTO ticket_scan_events (ticket_id, conductor_id, result_status, details)
     VALUES ($1, $2, $3, $4)`,
    [ticketId ?? null, conductorId ?? null, status, details ?? {}]
  );
}

function isPaidStatus(status) {
  return ['paid', 'successful', 'PAID', 'SUCCESSFUL'].includes(String(status || ''));
}

function isUsedStatus(status) {
  return ['used', 'USED'].includes(String(status || ''));
}

function isActiveStatus(status) {
  return ['active', 'ACTIVE', 'paid', 'PAID'].includes(String(status || ''));
}

function isExpired(departureTime) {
  const bufferMinutes = Number.parseInt(
    process.env.TICKET_EXPIRY_BUFFER_MINUTES || `${DEFAULT_EXPIRY_BUFFER_MINUTES}`,
    10
  );
  const expiresAt = new Date(departureTime);
  expiresAt.setMinutes(expiresAt.getMinutes() + (Number.isFinite(bufferMinutes) ? bufferMinutes : DEFAULT_EXPIRY_BUFFER_MINUTES));
  return new Date() > expiresAt;
}

async function verifyAndUseTicket({ pool, qrCode, conductorId, assignedTrip }) {
  let payload;
  try {
    payload = verifySignedTicket(qrCode);
  } catch {
    await logScan(pool, {
      conductorId,
      status: 'INVALID',
      details: { reason: 'QR signature verification failed' },
    });
    return { status: 'INVALID', message: 'Ticket not found or tampered' };
  }

  const ticketNumber = payload.ticketNumber || payload.ticket_number || payload.ticketId || payload.ticket_id;
  const result = await pool.query(
    `SELECT tk.ticket_id, tk.ticket_number, tk.status, tk.verified_at,
            tk.passenger_name, tk.seat_number,
            bk.status AS booking_status, bk.trip_id,
            tr.departure_time,
            rs.origin, rs.destination,
            b.registration_number
     FROM tickets tk
     INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
     INNER JOIN trips tr ON tr.trip_id = bk.trip_id
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE tk.ticket_number = $1 OR tk.qr_code_hash = $2 OR tk.ticket_id::text = $3
     ORDER BY tk.ticket_id ASC
     LIMIT 1`,
    [ticketNumber, qrCode, String(ticketNumber ?? '')]
  );

  if (result.rowCount === 0) {
    await logScan(pool, { conductorId, status: 'INVALID', details: { ticketNumber } });
    return { status: 'INVALID', message: 'Ticket not found or tampered' };
  }

  const ticket = result.rows[0];
  if (isUsedStatus(ticket.status)) {
    await logScan(pool, { ticketId: ticket.ticket_id, conductorId, status: 'ALREADY_USED' });
    return {
      status: 'ALREADY_USED',
      scannedAt: ticket.verified_at,
      message: 'This ticket was already scanned',
    };
  }

  if (!assignedTrip || Number(ticket.trip_id) !== Number(assignedTrip.trip_id)) {
    await logScan(pool, { ticketId: ticket.ticket_id, conductorId, status: 'WRONG_TRIP' });
    return { status: 'WRONG_TRIP', message: 'This ticket is not for your assigned trip' };
  }

  if (new Date(ticket.departure_time).toDateString() !== new Date().toDateString() || isExpired(ticket.departure_time)) {
    await logScan(pool, { ticketId: ticket.ticket_id, conductorId, status: 'EXPIRED' });
    return { status: 'EXPIRED', message: 'This ticket is for a past trip' };
  }

  if (!isPaidStatus(ticket.booking_status) || !isActiveStatus(ticket.status)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      status: 'INVALID',
      details: { bookingStatus: ticket.booking_status, ticketStatus: ticket.status },
    });
    return { status: 'INVALID', message: 'Ticket not found or tampered' };
  }

  const updateResult = await pool.query(
    `UPDATE tickets
     SET status = 'used',
         verified_at = NOW(),
         verified_by_driver_id = $1
     WHERE ticket_id = $2
       AND status <> 'used'
     RETURNING verified_at`,
    [conductorId, ticket.ticket_id]
  );

  if (updateResult.rowCount === 0) {
    await logScan(pool, { ticketId: ticket.ticket_id, conductorId, status: 'ALREADY_USED' });
    return {
      status: 'ALREADY_USED',
      scannedAt: ticket.verified_at,
      message: 'This ticket was already scanned',
    };
  }

  await logScan(pool, { ticketId: ticket.ticket_id, conductorId, status: 'VALID' });
  return {
    status: 'VALID',
    passengerName: ticket.passenger_name,
    seatNumber: ticket.seat_number,
    route: `${ticket.origin || 'Origin'} \u2192 ${ticket.destination || 'Destination'}`,
    busNumber: ticket.registration_number || 'Bus pending',
    departureTime: new Date(ticket.departure_time).toLocaleTimeString('en-GB', {
      hour: '2-digit',
      minute: '2-digit',
    }),
    message: 'Passenger may board',
  };
}

module.exports = {
  findTodayAssignedTrip,
  verifyAndUseTicket,
  verifySignedTicket,
};
