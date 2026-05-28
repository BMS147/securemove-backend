const jwt = require('jsonwebtoken');
const {
  checkReplay,
  hashQr,
  triggerFraudAlert,
} = require('../services/scanSecurity');

const DEFAULT_EXPIRY_BUFFER_MINUTES = 30;
const DEFAULT_BOARDING_WINDOW_MINUTES = 120;

function verifySignedTicket(qrCode) {
  const secret = ticketSecret();
  return jwt.verify(qrCode, secret, {
    algorithms: ['HS256'],
    issuer: 'securemove-api',
    audience: 'securemove-conductor',
  });
}

function ticketSecret() {
  const secret = process.env.TICKET_SECRET || process.env.TICKET_QR_SECRET;
  if (!secret || secret.length < 64) {
    throw new Error('TICKET_SECRET must be set and at least 64 characters long.');
  }
  return secret;
}

async function findTodayAssignedTrip(pool, conductorId) {
  const result = await pool.query(
    `SELECT tr.trip_id, tr.departure_time, tr.arrival_time, tr.status,
            rs.origin, rs.destination, b.registration_number, b.capacity
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE tr.conductor_id = $1
       AND tr.departure_time::date = CURRENT_DATE
       AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')
     ORDER BY
       CASE
         WHEN tr.status IN ('boarding', 'BOARDING') THEN 0
         WHEN tr.departure_time <= NOW()
           AND COALESCE(tr.arrival_time, tr.departure_time + INTERVAL '6 hours') >= NOW() THEN 1
         WHEN tr.departure_time > NOW() THEN 2
         ELSE 3
       END ASC,
       CASE WHEN tr.departure_time > NOW() THEN tr.departure_time END ASC,
       tr.departure_time DESC
     LIMIT 1`,
    [conductorId]
  );

  return result.rows[0] ?? null;
}

async function findAssignedTripById(pool, conductorId, tripId) {
  const result = await pool.query(
    `SELECT tr.trip_id, tr.departure_time, tr.arrival_time, tr.status,
            rs.origin, rs.destination, b.registration_number, b.capacity
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE tr.conductor_id = $1
       AND tr.trip_id = $2
       AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')
     LIMIT 1`,
    [conductorId, tripId]
  );

  return result.rows[0] ?? null;
}

async function logScan(pool, {
  ticketId,
  conductorId,
  tripId,
  status,
  details,
  req,
  qrHash,
  fraudAlert = false,
}) {
  const enrichedDetails = {
    ...(details ?? {}),
    ipAddress: req?.ip,
    userAgent: req?.headers?.['user-agent'],
  };

  await pool.query(
    `INSERT INTO ticket_scan_events (
       ticket_id,
       conductor_id,
       trip_id,
       result_status,
       details,
       ip_address,
       device_info,
       qr_hash,
       fraud_alert
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [
      ticketId ?? null,
      conductorId ?? null,
      tripId ?? null,
      status,
      enrichedDetails,
      req?.ip ?? null,
      req?.headers?.['user-agent'] ?? null,
      qrHash ?? null,
      fraudAlert,
    ]
  );

  await pool.query(
    `INSERT INTO audit_logs (event_type, status, severity, email, user_id, ip_address, user_agent, details)
     VALUES ('ticket_scan', $1, $2, $3, $4, $5, $6, $7)`,
    [
      status,
      status === 'VALID_BOARD' || status === 'ALREADY_USED' ? 'info' : 'warning',
      req?.user?.email ?? null,
      req?.user?.user_id ?? null,
      req?.ip ?? null,
      req?.headers?.['user-agent'] ?? null,
      {
        ticketId: ticketId ?? null,
        conductorId: conductorId ?? null,
        tripId: tripId ?? null,
        qrHash: qrHash ?? null,
        fraudAlert,
        ...enrichedDetails,
      },
    ]
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

function isPastTripDay(departureTime) {
  const departureDay = startOfDay(new Date(departureTime));
  const today = startOfDay(new Date());
  return departureDay < today;
}

function isBeforeBoardingWindow(departureTime) {
  const windowMinutes = Number.parseInt(
    process.env.TICKET_BOARDING_WINDOW_MINUTES || `${DEFAULT_BOARDING_WINDOW_MINUTES}`,
    10
  );
  const startsAt = new Date(departureTime);
  startsAt.setMinutes(
    startsAt.getMinutes() -
      (Number.isFinite(windowMinutes) ? windowMinutes : DEFAULT_BOARDING_WINDOW_MINUTES)
  );
  return new Date() < startsAt;
}

function boardingStartsAt(departureTime) {
  const windowMinutes = Number.parseInt(
    process.env.TICKET_BOARDING_WINDOW_MINUTES || `${DEFAULT_BOARDING_WINDOW_MINUTES}`,
    10
  );
  const startsAt = new Date(departureTime);
  startsAt.setMinutes(
    startsAt.getMinutes() -
      (Number.isFinite(windowMinutes) ? windowMinutes : DEFAULT_BOARDING_WINDOW_MINUTES)
  );
  return startsAt;
}

function startOfDay(date) {
  const day = new Date(date);
  day.setHours(0, 0, 0, 0);
  return day;
}

function extractTicketLookup(qrCode) {
  const raw = String(qrCode || '').trim();
  let signedPayload = null;

  try {
    signedPayload = verifySignedTicket(raw);
  } catch {
    signedPayload = null;
  }

  let uriRef = null;
  try {
    const parsed = new URL(raw);
    uriRef =
      parsed.searchParams.get('ref') ||
      parsed.searchParams.get('ticket') ||
      parsed.searchParams.get('ticketNumber');
  } catch {
    uriRef = null;
  }

  return {
    raw,
    rawHash: hashQr(raw),
    signed: Boolean(signedPayload),
    ticketNumber:
      signedPayload?.ticketNumber ||
      signedPayload?.ticket_number ||
      signedPayload?.ticketId ||
      signedPayload?.ticket_id ||
      null,
    bookingReference:
      signedPayload?.bookingReference ||
      signedPayload?.booking_reference ||
      uriRef ||
      null,
  };
}

async function verifyAndUseTicket({ pool, qrCode, conductorId, assignedTrip, req }) {
  const lookup = extractTicketLookup(qrCode);
  if (!lookup.signed && !lookup.bookingReference && !lookup.raw) {
    await logScan(pool, {
      conductorId,
      tripId: assignedTrip?.trip_id,
      status: 'INVALID_INPUT',
      details: { reason: 'Empty QR payload' },
      qrHash: lookup.rawHash,
      req,
    });
    return { status: 'INVALID', message: 'Ticket not found or tampered' };
  }

  if (!lookup.signed) {
    await logScan(pool, {
      conductorId,
      tripId: assignedTrip?.trip_id,
      status: 'FAKE_SIGNATURE',
      details: { reason: 'QR signature verification failed' },
      qrHash: lookup.rawHash,
      fraudAlert: true,
      req,
    });
    await triggerFraudAlert(pool, {
      conductorId,
      tripId: assignedTrip?.trip_id,
      rawQrHash: lookup.rawHash,
      ipAddress: req?.ip,
      reason: 'QR signature verification failed',
      req,
    });
    return {
      status: 'FAKE',
      message: 'QR signature verification failed - ticket is fraudulent',
    };
  }

  const result = await pool.query(
    `SELECT tk.ticket_id, tk.ticket_number, tk.status, tk.verified_at,
            tk.passenger_name, tk.seat_number,
            bk.status AS booking_status, bk.trip_id, bk.booking_reference,
            tr.departure_time,
            rs.origin, rs.destination, rs.departure_time AS scheduled_departure_label,
            b.registration_number
     FROM tickets tk
     INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
     INNER JOIN trips tr ON tr.trip_id = bk.trip_id
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     WHERE tk.ticket_number = $1
        OR tk.qr_code_hash = $2
        OR tk.ticket_id::text = $3
        OR bk.booking_reference = $4
     ORDER BY tk.ticket_id ASC
     LIMIT 1`,
    [
      lookup.ticketNumber,
      lookup.raw,
      String(lookup.ticketNumber ?? ''),
      lookup.bookingReference,
    ]
  );

  if (result.rowCount === 0) {
    await logScan(pool, {
      conductorId,
      tripId: assignedTrip?.trip_id,
      status: 'NOT_FOUND',
      details: {
        reason: 'No matching ticket',
        rawHash: lookup.rawHash,
        ticketNumber: lookup.ticketNumber,
        bookingReference: lookup.bookingReference,
      },
      qrHash: lookup.rawHash,
      req,
    });
    return { status: 'INVALID', message: 'Ticket not found or tampered' };
  }

  const ticket = result.rows[0];
  if (checkReplay(ticket.ticket_id, lookup.rawHash)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'REPLAY_ATTEMPT',
      details: { rawHash: lookup.rawHash },
      qrHash: lookup.rawHash,
      fraudAlert: true,
      req,
    });
    await triggerFraudAlert(pool, {
      conductorId,
      ticketId: ticket.ticket_id,
      tripId: ticket.trip_id,
      rawQrHash: lookup.rawHash,
      ipAddress: req?.ip,
      reason: 'Same QR submitted inside replay window',
      req,
    });
    return {
      status: 'ALREADY_USED',
      message: 'Possible replay attack detected',
    };
  }

  if (isUsedStatus(ticket.status)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'ALREADY_USED',
      details: { rawHash: lookup.rawHash },
      qrHash: lookup.rawHash,
      req,
    });
    return {
      status: 'ALREADY_USED',
      scannedAt: ticket.verified_at,
      message: 'This ticket was already scanned',
    };
  }

  const ticketAssignedTrip =
    assignedTrip && Number(ticket.trip_id) === Number(assignedTrip.trip_id)
      ? assignedTrip
      : await findAssignedTripById(pool, conductorId, ticket.trip_id);

  if (!ticketAssignedTrip) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'WRONG_TRIP',
      details: {
        assignedTripId: assignedTrip?.trip_id ?? null,
        rawHash: lookup.rawHash,
        correctRoute: `${ticket.origin || 'Origin'} -> ${ticket.destination || 'Destination'}`,
        assignedRoute: assignedTrip
          ? `${assignedTrip.origin || 'Origin'} -> ${assignedTrip.destination || 'Destination'}`
          : null,
      },
      qrHash: lookup.rawHash,
      req,
    });
    return {
      status: 'WRONG_TRIP',
      correctRoute: `${ticket.origin || 'Origin'} -> ${ticket.destination || 'Destination'}`,
      assignedRoute: assignedTrip
        ? `${assignedTrip.origin || 'Origin'} -> ${assignedTrip.destination || 'Destination'}`
        : 'No assigned trip',
      message: 'This ticket is not for your assigned trip',
    };
  }

  const effectiveDepartureTime = resolveEffectiveDepartureTime(ticket);
  const departureLabel = ticket.scheduled_departure_label || formatTime(effectiveDepartureTime);

  if (isPastTripDay(effectiveDepartureTime) || isExpired(effectiveDepartureTime)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'EXPIRED',
      details: {
        rawHash: lookup.rawHash,
        departureTime: effectiveDepartureTime.toISOString(),
        scheduledDepartureLabel: departureLabel,
      },
      qrHash: lookup.rawHash,
      req,
    });
    return {
      status: 'EXPIRED',
      departureTime: effectiveDepartureTime.toISOString(),
      departureLabel,
      message: 'This ticket is for a past trip',
    };
  }

  if (isBeforeBoardingWindow(effectiveDepartureTime)) {
    const startsAt = boardingStartsAt(effectiveDepartureTime);
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'SCHEDULED_LATER',
      details: {
        rawHash: lookup.rawHash,
        departureTime: effectiveDepartureTime.toISOString(),
        scheduledDepartureLabel: departureLabel,
        boardingStartsAt: startsAt.toISOString(),
      },
      qrHash: lookup.rawHash,
      req,
    });
    return {
      status: 'SCHEDULED_LATER',
      route: `${ticket.origin || 'Origin'} -> ${ticket.destination || 'Destination'}`,
      departureTime: effectiveDepartureTime.toISOString(),
      departureLabel,
      boardingStartsAt: startsAt.toISOString(),
      boardingStartsAtLabel: formatTime(startsAt),
      message: 'Trip is scheduled for a later time',
    };
  }

  if (!isPaidStatus(ticket.booking_status)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'UNPAID',
      details: {
        bookingStatus: ticket.booking_status,
        ticketStatus: ticket.status,
        rawHash: lookup.rawHash,
      },
      qrHash: lookup.rawHash,
      req,
    });
    return { status: 'INVALID', message: 'Ticket not paid' };
  }

  if (!isActiveStatus(ticket.status)) {
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'INVALID',
      details: { ticketStatus: ticket.status, rawHash: lookup.rawHash },
      qrHash: lookup.rawHash,
      req,
    });
    return { status: 'INVALID', message: `Ticket is ${ticket.status}` };
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
    await logScan(pool, {
      ticketId: ticket.ticket_id,
      conductorId,
      tripId: ticket.trip_id,
      status: 'ALREADY_USED',
      details: { rawHash: lookup.rawHash },
      qrHash: lookup.rawHash,
      req,
    });
    return {
      status: 'ALREADY_USED',
      scannedAt: ticket.verified_at,
      message: 'This ticket was already scanned',
    };
  }

  await logScan(pool, {
    ticketId: ticket.ticket_id,
    conductorId,
    tripId: ticket.trip_id,
    status: 'VALID_BOARD',
    details: { rawHash: lookup.rawHash, signedQr: lookup.signed },
    qrHash: lookup.rawHash,
    req,
  });
  return {
    status: 'VALID',
    passengerName: ticket.passenger_name,
    seatNumber: ticket.seat_number,
    route: `${ticket.origin || 'Origin'} \u2192 ${ticket.destination || 'Destination'}`,
    busNumber: ticket.registration_number || 'Bus pending',
    ticketRef: ticket.ticket_number,
    departureTime: departureLabel,
    message: 'Passenger may board',
  };
}

function resolveEffectiveDepartureTime(ticket) {
  const scheduled = parseScheduleTimeForTripDate(
    ticket.scheduled_departure_label,
    ticket.departure_time
  );
  return scheduled ?? new Date(ticket.departure_time);
}

function parseScheduleTimeForTripDate(label, tripDate) {
  if (!label) return null;
  const match = String(label)
    .trim()
    .match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (!match) return null;

  let hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  const meridiem = match[3].toUpperCase();
  if (meridiem === 'PM' && hour !== 12) hour += 12;
  if (meridiem === 'AM' && hour === 12) hour = 0;

  const date = new Date(tripDate);
  if (Number.isNaN(date.getTime())) return null;

  return new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
    hour - 2,
    minute,
    0,
    0
  ));
}

function formatTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Time pending';
  return date.toLocaleTimeString('en-GB', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Africa/Lusaka',
  });
}

module.exports = {
  findAssignedTripById,
  findTodayAssignedTrip,
  verifyAndUseTicket,
  verifySignedTicket,
};
