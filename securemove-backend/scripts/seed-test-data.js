/**
 * SecureMove test data seed
 *
 * Creates realistic data so every role can be tested immediately:
 *   - All user accounts (admin, company admins, conductors, passengers)
 *   - Today's trips updated to future departure times so conductor scanning works
 *   - Active tickets with valid QR codes for today's trips
 *   - 14 days of historical bookings, payments, and used tickets
 *   - Cancelled bookings and failed payments for edge-case testing
 *   - Audit log entries for the security log screen
 *
 * Run: node scripts/seed-test-data.js
 * All accounts use password: SecureMove2024!
 */

require('dotenv').config();

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const pool = require('../db');

const PASSWORD = 'SecureMove2024!';
const SALT_ROUNDS = 10;
const QR_SECRET = process.env.TICKET_SECRET || process.env.TICKET_QR_SECRET;
if (!QR_SECRET || QR_SECRET.length < 64) {
  throw new Error('TICKET_SECRET must be set and at least 64 characters long.');
}

// ---------------------------------------------------------------------------
// User definitions
// Driver and conductor emails are intentionally separate.
// ---------------------------------------------------------------------------
const TEST_USERS = [
  // Super admin
  { name: 'System Admin',   email: 'admin@securemove.dev',        role_id: 3, companyName: null },

  // Company admins (one per company)
  { name: 'Chanda Mwale',   email: 'chanda@powertools.dev',       role_id: 2, companyName: 'Power Tools' },
  { name: 'Mary Phiri',     email: 'mary@likili.dev',             role_id: 2, companyName: 'Likili Motorways' },
  { name: 'James Banda',    email: 'james@mazhandu.dev',          role_id: 2, companyName: 'Mazhandu Family Bus' },
  { name: 'Susan Tembo',    email: 'susan@shalom.dev',            role_id: 2, companyName: 'Shalom' },
  { name: 'Victor Zulu',    email: 'victor@ubz.dev',              role_id: 2, companyName: 'UBZ' },

  // Conductors — must match driver emails exactly
  { name: 'Benson Phiri',   email: 'benson.phiri@securemove.dev', role_id: 4, companyName: 'Power Tools' },
  { name: 'Ruth Mwila',     email: 'ruth.mwila@securemove.dev',   role_id: 4, companyName: 'Likili Motorways' },
  { name: 'Peter Banda',    email: 'peter.banda@securemove.dev',  role_id: 4, companyName: 'Mazhandu Family Bus' },
  { name: 'Grace Tembo',    email: 'grace.tembo@securemove.dev',  role_id: 4, companyName: 'Shalom' },
  { name: 'Daniel Zulu',    email: 'daniel.zulu@securemove.dev',  role_id: 4, companyName: 'UBZ' },

  // Conductors / transport officers - separate from driver accounts
  { name: 'Officer Banda',  email: 'officer.banda@securemove.dev',  role_id: 5, companyName: 'Power Tools' },
  { name: 'Officer Mwansa', email: 'officer.mwansa@securemove.dev', role_id: 5, companyName: 'Likili Motorways' },
  { name: 'Officer Chirwa', email: 'officer.chirwa@securemove.dev', role_id: 5, companyName: 'Mazhandu Family Bus' },
  { name: 'Officer Tembo',  email: 'officer.tembo@securemove.dev',  role_id: 5, companyName: 'Shalom' },
  { name: 'Officer Zulu',   email: 'officer.zulu@securemove.dev',   role_id: 5, companyName: 'UBZ' },

  // Passengers
  { name: 'Temwa Banda',    email: 'temwa@test.dev',              role_id: 1, companyName: null },
  { name: 'Chisomo Nkosi',  email: 'chisomo@test.dev',            role_id: 1, companyName: null },
  { name: 'Mutale Mwanza',  email: 'mutale@test.dev',             role_id: 1, companyName: null },
  { name: 'Lombe Kapasa',   email: 'lombe@test.dev',              role_id: 1, companyName: null },
];

const PASSENGERS = [
  { email: 'temwa@test.dev',   name: 'Temwa Banda' },
  { email: 'chisomo@test.dev', name: 'Chisomo Nkosi' },
  { email: 'mutale@test.dev',  name: 'Mutale Mwanza' },
  { email: 'lombe@test.dev',   name: 'Lombe Kapasa' },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function bookingRef() {
  return `SM-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
}

function seatLabel(index) {
  return `${String.fromCharCode(65 + Math.floor(index / 4))}${(index % 4) + 1}`;
}

function priceFromSchedule(_priceStr) {
  return 1;
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

function hoursFromNow(h) {
  return new Date(Date.now() + h * 3600 * 1000).toISOString();
}

async function upsertBooking(userId, tripId, amount, status = 'paid') {
  const ref = bookingRef();
  const result = await pool.query(
    `INSERT INTO bookings (user_id, trip_id, booking_reference, total_amount, status, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     RETURNING booking_id, booking_reference`,
    [userId, tripId, ref, amount, status]
  );
  return result.rows[0];
}

async function insertPayment(bookingId, amount, status, provider = 'airtel', daysBack = 0) {
  const createdAt = daysBack > 0 ? daysAgo(daysBack) : new Date().toISOString();
  await pool.query(
    `INSERT INTO payments (booking_id, amount, payment_method, provider, phone_number, transaction_reference, status, created_at, updated_at)
     VALUES ($1, $2, 'mobile_money', $3, '0977000099', $4, $5, $6, $6)`,
    [bookingId, amount, provider, `TXN-${crypto.randomBytes(4).toString('hex').toUpperCase()}`, status, createdAt]
  );
}

async function insertTicket(bookingId, passengerName, seatNumber, status = 'active', verifiedAt = null) {
  const ticketNumber = `SMT-${bookingRef()}`;
  const qrPayload = jwt.sign(
    {
      typ: 'securemove.ticket',
      ticketNumber,
      passengerName,
      nonce: `${ticketNumber}-${crypto.randomBytes(8).toString('hex')}`,
    },
    QR_SECRET,
    {
      algorithm: 'HS256',
      issuer: 'securemove-api',
      audience: 'securemove-conductor',
      expiresIn: '30d',
    }
  );
  await pool.query(
    `INSERT INTO tickets (booking_id, passenger_name, seat_number, ticket_number, qr_code_hash, status, verified_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (booking_id, seat_number) DO NOTHING`,
    [bookingId, passengerName, seatNumber, ticketNumber, qrPayload, status, verifiedAt]
  );
  return ticketNumber;
}

// ---------------------------------------------------------------------------
// Main seed
// ---------------------------------------------------------------------------
async function seed() {
  console.log('Seeding test data...\n');

  const passwordHash = await bcrypt.hash(PASSWORD, SALT_ROUNDS);

  // -- Companies -----------------------------------------------------------
  const { rows: companyRows } = await pool.query('SELECT company_id, name FROM companies');
  const companyMap = Object.fromEntries(companyRows.map(r => [r.name, r.company_id]));

  await pool.query("UPDATE companies SET approval_status = 'approved'");
  console.log('All companies approved');

  await pool.query("UPDATE route_schedules SET price = 'K1'");
  console.log('All route prices set to K1 for testing');

  // -- Users ---------------------------------------------------------------
  const userIds = {};
  for (const u of TEST_USERS) {
    const companyId = u.companyName ? (companyMap[u.companyName] ?? null) : null;
    const { rows } = await pool.query(
      `INSERT INTO users (name, email, password_hash, role_id, company_id)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (email) DO UPDATE
         SET name = EXCLUDED.name,
             password_hash = EXCLUDED.password_hash,
             role_id = EXCLUDED.role_id,
             company_id = EXCLUDED.company_id
       RETURNING user_id`,
      [u.name, u.email, passwordHash, u.role_id, companyId]
    );
    userIds[u.email] = rows[0].user_id;
  }
  console.log(`${TEST_USERS.length} users created / updated`);

  // -- Conductors ----------------------------------------------------------
  const { rows: conductorRows } = await pool.query(
    'SELECT conductor_id, email, company_id FROM conductors'
  );
  const conductorByEmail = Object.fromEntries(conductorRows.map(r => [r.email, r]));

  // -- Today's trips — push departure times into the future ----------------
  // Each conductor gets one scannable trip 2-4 hours from now.
  const conductorOffsets = {
    'officer.banda@securemove.dev':  2,
    'officer.mwansa@securemove.dev': 3,
    'officer.chirwa@securemove.dev': 2,
    'officer.tembo@securemove.dev':  4,
    'officer.zulu@securemove.dev':   3,
  };

  for (const [email, offsetHours] of Object.entries(conductorOffsets)) {
    const conductor = conductorByEmail[email];
    if (!conductor) continue;

    await pool.query(
      `UPDATE trips
       SET departure_time = $1,
           arrival_time   = $2,
           status         = 'scheduled'
       WHERE trip_id = (
         SELECT trip_id FROM trips
         WHERE conductor_id = $3
           AND departure_time::date = CURRENT_DATE
         ORDER BY departure_time ASC
         LIMIT 1
       )`,
      [hoursFromNow(offsetHours), hoursFromNow(offsetHours + 4), conductor.conductor_id]
    );
  }
  console.log("Today's conductor trips set to future departure times");

  // -- Fetch today's live trips -------------------------------------------
  const { rows: liveTrips } = await pool.query(
    `SELECT tr.trip_id, tr.departure_time, tr.conductor_id, tr.driver_id,
            rs.origin, rs.destination, rs.price, rs.duration_minutes,
            c.name AS company_name, b.capacity
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b          ON b.bus_id = tr.bus_id
     LEFT JOIN companies c      ON c.company_id = rs.company_id
     WHERE tr.departure_time > NOW()
       AND tr.departure_time::date = CURRENT_DATE
       AND tr.status = 'scheduled'
     ORDER BY tr.departure_time ASC`
  );

  // -- Active tickets for today's trips ------------------------------------
  let ticketCount = 0;
  for (const trip of liveTrips.slice(0, 3)) {
    const price = priceFromSchedule(trip.price);
    for (let i = 0; i < PASSENGERS.length; i++) {
      const p = PASSENGERS[i];
      const userId = userIds[p.email];
      if (!userId) continue;

      const booking = await upsertBooking(userId, trip.trip_id, price, 'paid');
      await insertPayment(booking.booking_id, price, 'successful', i % 2 === 0 ? 'airtel' : 'mtn');
      await insertTicket(booking.booking_id, p.name, seatLabel(i), 'active');
      ticketCount++;
    }
  }
  console.log(`${ticketCount} active tickets created for today's trips`);

  // -- Historical trips + bookings (last 14 days) --------------------------
  const { rows: allSchedules } = await pool.query(
    `SELECT rs.schedule_id, rs.company_id, rs.origin, rs.destination,
            rs.price, rs.duration_minutes, rs.departure_time AS dep_time,
            d.driver_id, co.conductor_id, bu.bus_id, bu.capacity
     FROM route_schedules rs
     LEFT JOIN companies c ON c.company_id = rs.company_id
     LEFT JOIN drivers d   ON d.company_id = rs.company_id AND d.is_active = TRUE
     LEFT JOIN conductors co ON co.company_id = rs.company_id AND co.is_active = TRUE
     LEFT JOIN buses bu    ON bu.company_id = rs.company_id AND bu.is_active = TRUE
     WHERE rs.active = TRUE
     ORDER BY rs.schedule_id ASC
     LIMIT 12`
  );

  let historyBookings = 0;
  let historyTickets = 0;

  for (let day = 1; day <= 14; day++) {
    const schedule = allSchedules[day % allSchedules.length];
    if (!schedule.driver_id || !schedule.conductor_id || !schedule.bus_id) continue;

    const depDate = new Date();
    depDate.setDate(depDate.getDate() - day);

    const [timePart, meridiem] = (schedule.dep_time || '08:00 AM').split(' ');
    const [hh, mm] = timePart.split(':');
    let hour = parseInt(hh, 10);
    if (meridiem === 'PM' && hour !== 12) hour += 12;
    if (meridiem === 'AM' && hour === 12) hour = 0;
    depDate.setHours(hour, parseInt(mm, 10), 0, 0);

    const arrDate = new Date(depDate.getTime() + (schedule.duration_minutes || 180) * 60000);

    const { rows: tripRows } = await pool.query(
      `INSERT INTO trips (schedule_id, bus_id, driver_id, conductor_id, departure_time, arrival_time, available_seats, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'completed')
       RETURNING trip_id`,
      [
        schedule.schedule_id,
        schedule.bus_id,
        schedule.driver_id,
        schedule.conductor_id,
        depDate.toISOString(),
        arrDate.toISOString(),
        schedule.capacity,
      ]
    );
    const tripId = tripRows[0].trip_id;
    const price = priceFromSchedule(schedule.price);

    // 2-4 passengers per historical trip
    const passengerCount = 2 + (day % 3);
    for (let i = 0; i < Math.min(passengerCount, PASSENGERS.length); i++) {
      const p = PASSENGERS[i];
      const userId = userIds[p.email];
      if (!userId) continue;

      const booking = await upsertBooking(userId, tripId, price, 'paid');
      await pool.query(
        `UPDATE bookings SET created_at = $1, updated_at = $1 WHERE booking_id = $2`,
        [depDate.toISOString(), booking.booking_id]
      );

      await insertPayment(booking.booking_id, price, 'successful', i % 2 === 0 ? 'airtel' : 'mtn', day);
      await insertTicket(booking.booking_id, p.name, seatLabel(i), 'used', arrDate.toISOString());

      historyBookings++;
      historyTickets++;
    }
  }
  console.log(`${historyBookings} historical bookings, ${historyTickets} used tickets (14-day history)`);

  // -- Cancelled bookings --------------------------------------------------
  // Give Temwa one reserved (unpaid) and one cancelled booking
  const temwaId = userIds['temwa@test.dev'];
  if (temwaId && liveTrips.length > 0) {
    const refundTrip = liveTrips[liveTrips.length - 1];
    const price = priceFromSchedule(refundTrip.price);

    const reserved = await upsertBooking(temwaId, refundTrip.trip_id, price, 'reserved');
    await insertPayment(reserved.booking_id, price, 'failed', 'mtn');

    if (liveTrips.length > 1) {
      const cancelledTrip = liveTrips[Math.floor(liveTrips.length / 2)];
      const cancelledPrice = priceFromSchedule(cancelledTrip.price);
      await upsertBooking(temwaId, cancelledTrip.trip_id, cancelledPrice, 'cancelled');
    }
  }
  console.log('Cancelled and reserved bookings added');

  // -- Audit logs ----------------------------------------------------------
  const auditEvents = [
    { eventType: 'login_success',   status: 'success',           severity: 'info',   email: 'admin@securemove.dev' },
    { eventType: 'login_success',   status: 'success',           severity: 'info',   email: 'temwa@test.dev' },
    { eventType: 'login_success',   status: 'success',           severity: 'info',   email: 'chisomo@test.dev' },
    { eventType: 'login_failed',    status: 'invalid_credentials', severity: 'medium', email: 'unknown@hacker.dev' },
    { eventType: 'login_failed',    status: 'invalid_credentials', severity: 'medium', email: 'unknown@hacker.dev' },
    { eventType: 'login_failed',    status: 'invalid_credentials', severity: 'medium', email: 'unknown@hacker.dev' },
    { eventType: 'fraud_alert',     status: 'blocked',           severity: 'high',   email: 'unknown@hacker.dev' },
    { eventType: 'register_success', status: 'success',          severity: 'info',   email: 'lombe@test.dev' },
    { eventType: 'login_success',   status: 'success',           severity: 'info',   email: 'benson.phiri@securemove.dev' },
    { eventType: 'login_success',   status: 'success',           severity: 'info',   email: 'chanda@powertools.dev' },
  ];

  for (let i = 0; i < auditEvents.length; i++) {
    const e = auditEvents[i];
    const createdAt = daysAgo(Math.floor(i / 3));
    await pool.query(
      `INSERT INTO audit_logs (event_type, status, severity, email, ip_address, user_agent, details, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        e.eventType,
        e.status,
        e.severity,
        e.email,
        `192.168.1.${10 + i}`,
        'SecureMove-App/1.0 Flutter',
        JSON.stringify({ source: 'seed' }),
        createdAt,
      ]
    );
  }
  console.log(`${auditEvents.length} audit log entries created`);

  // -- Summary -------------------------------------------------------------
  console.log('\n=== Seed complete ===\n');
  console.log('All accounts use password: SecureMove2024!\n');
  console.log('Role          | Email');
  console.log('--------------|----------------------------------------');
  console.log('Super Admin   | admin@securemove.dev');
  console.log('Company Admin | chanda@powertools.dev');
  console.log('Company Admin | mary@likili.dev');
  console.log('Conductor     | benson.phiri@securemove.dev  (Power Tools, trip in ~2h)');
  console.log('Conductor     | ruth.mwila@securemove.dev    (Likili Motorways, trip in ~3h)');
  console.log('Conductor     | peter.banda@securemove.dev   (Mazhandu Family Bus, trip in ~2h)');
  console.log('Passenger     | temwa@test.dev');
  console.log('Passenger     | chisomo@test.dev');
  console.log('Passenger     | mutale@test.dev');
  console.log('Passenger     | lombe@test.dev');
  console.log('');
  console.log(`Live trips today: ${liveTrips.length}`);
  console.log(`Scannable tickets (active): ${ticketCount}`);
  console.log(`Historical bookings (14 days): ${historyBookings}`);
}

seed()
  .then(async () => { await pool.end(); })
  .catch(async (err) => {
    console.error('Seed failed:', err.message);
    await pool.end();
    process.exit(1);
  });
