const bcrypt = require('bcrypt');
const pool = require('../db');

function companyIdFrom(req) {
  return req.user.companyId ?? req.user.company_id;
}

async function dashboard(req, res) {
  const companyId = companyIdFrom(req);
  const [company, buses, routes, trips, staff, bookings] = await Promise.all([
    pool.query('SELECT company_id, name, approval_status, created_at FROM companies WHERE company_id = $1', [companyId]),
    pool.query('SELECT COUNT(*)::int AS count FROM buses WHERE company_id = $1 AND is_active = TRUE', [companyId]),
    pool.query('SELECT COUNT(*)::int AS count FROM route_schedules WHERE company_id = $1 AND active = TRUE', [companyId]),
    pool.query(
      `SELECT COUNT(*)::int AS count
       FROM trips tr INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       WHERE rs.company_id = $1 AND tr.departure_time::date = CURRENT_DATE`,
      [companyId]
    ),
    pool.query(
      `SELECT (
         (SELECT COUNT(*) FROM drivers WHERE company_id = $1 AND is_active = TRUE) +
         (SELECT COUNT(*) FROM conductors WHERE company_id = $1 AND is_active = TRUE)
       )::int AS count`,
      [companyId]
    ),
    pool.query(
      `SELECT COUNT(*)::int AS count, COALESCE(SUM(bk.total_amount) FILTER (WHERE bk.status = 'paid'), 0)::numeric AS revenue
       FROM bookings bk
       INNER JOIN trips tr ON tr.trip_id = bk.trip_id
       INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       WHERE rs.company_id = $1`,
      [companyId]
    ),
  ]);
  return res.json({
    company: company.rows[0],
    stats: {
      activeBuses: buses.rows[0].count,
      activeRoutes: routes.rows[0].count,
      todaysTrips: trips.rows[0].count,
      drivers: staff.rows[0].count,
      bookings: bookings.rows[0].count,
      revenue: bookings.rows[0].revenue,
    },
  });
}

async function listBuses(req, res) {
  const result = await pool.query(
    `SELECT bus_id, company_id, registration_number, capacity, type, features, is_active, created_at
     FROM buses
     WHERE company_id = $1 AND is_active = TRUE
     ORDER BY created_at DESC`,
    [companyIdFrom(req)]
  );
  return res.json({ buses: result.rows });
}

async function createBus(req, res) {
  const { plate, registration_number, capacity, type } = req.body ?? {};
  const plateValue = String(plate || registration_number || '').trim().toUpperCase();
  if (!plateValue || !Number.isInteger(Number(capacity)) || Number(capacity) <= 0) {
    return res.status(400).json({ error: 'plate and positive capacity are required' });
  }
  const result = await pool.query(
    `INSERT INTO buses (company_id, registration_number, capacity, type)
     VALUES ($1, $2, $3, $4)
     RETURNING bus_id, company_id, registration_number, capacity, type, features, is_active, created_at`,
    [companyIdFrom(req), plateValue, Number(capacity), String(type || 'Coach').trim()]
  );
  return res.status(201).json({ bus: result.rows[0] });
}

async function updateBus(req, res) {
  const { plate, registration_number, capacity, type, is_active } = req.body ?? {};
  const result = await pool.query(
    `UPDATE buses SET
       registration_number = COALESCE($1, registration_number),
       capacity = COALESCE($2, capacity),
       type = COALESCE($3, type),
       is_active = COALESCE($4, is_active)
     WHERE bus_id = $5 AND company_id = $6
     RETURNING bus_id, company_id, registration_number, capacity, type, features, is_active, created_at`,
    [
      plate || registration_number ? String(plate || registration_number).trim().toUpperCase() : null,
      capacity == null ? null : Number(capacity),
      type == null ? null : String(type).trim(),
      typeof is_active === 'boolean' ? is_active : null,
      req.params.id,
      companyIdFrom(req),
    ]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Bus not found' });
  return res.json({ bus: result.rows[0] });
}

async function deleteBus(req, res) {
  const result = await pool.query(
    `UPDATE buses SET is_active = FALSE WHERE bus_id = $1 AND company_id = $2 RETURNING bus_id`,
    [req.params.id, companyIdFrom(req)]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Bus not found' });
  return res.json({ message: 'Bus removed' });
}

async function listRoutes(req, res) {
  const result = await pool.query(
    `SELECT schedule_id, company_id, origin, destination, departure_time, price, duration_minutes, features, active, created_at
     FROM route_schedules
     WHERE company_id = $1 AND active = TRUE
     ORDER BY origin, destination, departure_time`,
    [companyIdFrom(req)]
  );
  return res.json({ routes: result.rows });
}

async function createRoute(req, res) {
  const { origin, destination, stops, price, departure_time, duration_minutes } = req.body ?? {};
  if (!origin || !destination || !price) return res.status(400).json({ error: 'origin, destination, and price are required' });
  const result = await pool.query(
    `INSERT INTO route_schedules (company_id, origin, destination, departure_time, price, duration_minutes, features)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING schedule_id, company_id, origin, destination, departure_time, price, duration_minutes, features, active, created_at`,
    [
      companyIdFrom(req),
      String(origin).trim(),
      String(destination).trim(),
      String(departure_time || '08:00 AM').trim(),
      String(price).trim(),
      Number(duration_minutes || 60),
      Array.isArray(stops) ? stops : [],
    ]
  );
  return res.status(201).json({ route: result.rows[0] });
}

async function updateRoute(req, res) {
  const { origin, destination, stops, price, departure_time, duration_minutes, active } = req.body ?? {};
  const result = await pool.query(
    `UPDATE route_schedules SET
       origin = COALESCE($1, origin),
       destination = COALESCE($2, destination),
       departure_time = COALESCE($3, departure_time),
       price = COALESCE($4, price),
       duration_minutes = COALESCE($5, duration_minutes),
       features = COALESCE($6, features),
       active = COALESCE($7, active)
     WHERE schedule_id = $8 AND company_id = $9
     RETURNING schedule_id, company_id, origin, destination, departure_time, price, duration_minutes, features, active, created_at`,
    [
      origin == null ? null : String(origin).trim(),
      destination == null ? null : String(destination).trim(),
      departure_time == null ? null : String(departure_time).trim(),
      price == null ? null : String(price).trim(),
      duration_minutes == null ? null : Number(duration_minutes),
      Array.isArray(stops) ? stops : null,
      typeof active === 'boolean' ? active : null,
      req.params.id,
      companyIdFrom(req),
    ]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Route not found' });
  return res.json({ route: result.rows[0] });
}

async function deleteRoute(req, res) {
  const result = await pool.query(
    `UPDATE route_schedules SET active = FALSE WHERE schedule_id = $1 AND company_id = $2 RETURNING schedule_id`,
    [req.params.id, companyIdFrom(req)]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Route not found' });
  return res.json({ message: 'Route removed' });
}

async function listSchedules(req, res) {
  const result = await pool.query(
    `SELECT tr.trip_id, tr.schedule_id, tr.bus_id, tr.driver_id, tr.conductor_id, tr.departure_time,
            tr.arrival_time, tr.available_seats, tr.status,
            rs.origin, rs.destination, b.registration_number,
            d.full_name AS driver_name,
            co.full_name AS conductor_name
     FROM trips tr
     INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     LEFT JOIN drivers d ON d.driver_id = tr.driver_id
     LEFT JOIN conductors co ON co.conductor_id = tr.conductor_id
     WHERE rs.company_id = $1 AND tr.status <> 'cancelled'
     ORDER BY tr.departure_time ASC`,
    [companyIdFrom(req)]
  );
  return res.json({ schedules: result.rows });
}

async function createSchedule(req, res) {
  const { route, route_id, bus, bus_id, driver, driver_id, conductor, conductor_id, departure_time, date } = req.body ?? {};
  const scheduleId = Number(route_id || route);
  const busId = Number(bus_id || bus);
  const driverId = Number(driver_id || driver);
  const conductorId = Number(conductor_id || conductor);
  if (!scheduleId || !busId || !driverId || !departure_time) {
    return res.status(400).json({ error: 'route, bus, driver, and departure_time are required' });
  }
  if (!conductorId) {
    return res.status(400).json({ error: 'A conductor is required for scanner access' });
  }
  const departureValue = String(departure_time).trim().replace(' ', 'T');
  const departureAt = date
    ? new Date(`${date}T${departureValue.slice(0, 5)}:00`)
    : new Date(departureValue);
  if (Number.isNaN(departureAt.getTime())) {
    return res.status(400).json({ error: 'Use a valid departure date and time' });
  }
  const result = await pool.query(
    `INSERT INTO trips (schedule_id, bus_id, driver_id, conductor_id, departure_time, available_seats, status)
     SELECT $1, $2, $3, $4, $5, capacity, 'scheduled'
     FROM buses WHERE bus_id = $2 AND company_id = $6
       AND EXISTS (
         SELECT 1 FROM conductors WHERE conductor_id = $4 AND company_id = $6 AND is_active = TRUE
       )
     RETURNING trip_id, schedule_id, bus_id, driver_id, conductor_id, departure_time, available_seats, status`,
    [scheduleId, busId, driverId, conductorId, departureAt.toISOString(), companyIdFrom(req)]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Bus not found for this company' });
  return res.status(201).json({ schedule: result.rows[0] });
}

async function updateSchedule(req, res) {
  const { departure_time, status } = req.body ?? {};
  const result = await pool.query(
    `UPDATE trips tr SET
       departure_time = COALESCE($1, tr.departure_time),
       status = COALESCE($2, tr.status)
     FROM route_schedules rs
     WHERE rs.schedule_id = tr.schedule_id
       AND rs.company_id = $3
       AND tr.trip_id = $4
     RETURNING tr.trip_id, tr.schedule_id, tr.bus_id, tr.driver_id, tr.conductor_id, tr.departure_time, tr.status`,
    [departure_time ? new Date(departure_time).toISOString() : null, status ?? null, companyIdFrom(req), req.params.id]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Schedule not found' });
  return res.json({ schedule: result.rows[0] });
}

async function deleteSchedule(req, res) {
  const result = await pool.query(
    `UPDATE trips tr SET status = 'cancelled'
     FROM route_schedules rs
     WHERE rs.schedule_id = tr.schedule_id AND rs.company_id = $1 AND tr.trip_id = $2
     RETURNING tr.trip_id`,
    [companyIdFrom(req), req.params.id]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Schedule not found' });
  return res.json({ message: 'Trip cancelled' });
}

async function listStaff(req, res) {
  const result = await pool.query(
    `SELECT driver_id AS staff_id,
            'driver' AS staff_role,
            company_id,
            full_name,
            email,
            phone_number,
            license_number AS badge_or_license,
            is_active,
            created_at
     FROM drivers
     WHERE company_id = $1 AND is_active = TRUE
     UNION ALL
     SELECT conductor_id AS staff_id,
            'conductor' AS staff_role,
            company_id,
            full_name,
            email,
            phone_number,
            badge_number AS badge_or_license,
            is_active,
            created_at
     FROM conductors
     WHERE company_id = $1 AND is_active = TRUE
     ORDER BY full_name`,
    [companyIdFrom(req)]
  );
  return res.json({ staff: result.rows });
}

async function createStaff(req, res) {
  const { name, full_name, email, phone_number, role, license_number, password } = req.body ?? {};
  const staffName = String(name || full_name || '').trim();
  if (!staffName) return res.status(400).json({ error: 'Staff name is required' });
  const staffRole = String(role || 'driver').trim().toLowerCase() === 'conductor'
    ? 'conductor'
    : 'driver';
  const badgeOrLicense = String(license_number || `${staffRole.toUpperCase()}-${Date.now()}`).trim().toUpperCase();
  const normalizedEmail = email && String(email).trim()
    ? String(email).trim().toLowerCase()
    : null;

  const result = staffRole === 'conductor'
    ? await pool.query(
        `INSERT INTO conductors (company_id, full_name, email, phone_number, badge_number)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING conductor_id AS staff_id, company_id, full_name, email, phone_number, badge_number AS badge_or_license, is_active, created_at`,
        [companyIdFrom(req), staffName, normalizedEmail, phone_number || null, badgeOrLicense]
      )
    : await pool.query(
        `INSERT INTO drivers (company_id, full_name, email, phone_number, license_number)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING driver_id AS staff_id, company_id, full_name, email, phone_number, license_number AS badge_or_license, is_active, created_at`,
        [companyIdFrom(req), staffName, normalizedEmail, phone_number || null, badgeOrLicense]
      );

  if (normalizedEmail && password && String(password).trim()) {
    const passwordHash = await bcrypt.hash(String(password), 10);
    await pool.query(
      `INSERT INTO users (name, email, password_hash, role_id, company_id)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (email) DO UPDATE SET role_id = EXCLUDED.role_id, company_id = EXCLUDED.company_id`,
      [staffName, normalizedEmail, passwordHash, staffRole === 'conductor' ? 5 : 4, companyIdFrom(req)]
    );
  }
  return res.status(201).json({ staff: { ...result.rows[0], staff_role: staffRole } });
}

async function deleteStaff(req, res) {
  const driverResult = await pool.query(
    `UPDATE drivers SET is_active = FALSE WHERE driver_id = $1 AND company_id = $2 RETURNING driver_id`,
    [req.params.id, companyIdFrom(req)]
  );
  if (driverResult.rowCount === 0) {
    const conductorResult = await pool.query(
      `UPDATE conductors SET is_active = FALSE WHERE conductor_id = $1 AND company_id = $2 RETURNING conductor_id`,
      [req.params.id, companyIdFrom(req)]
    );
    if (conductorResult.rowCount === 0) return res.status(404).json({ error: 'Staff member not found' });
  }
  return res.json({ message: 'Staff member removed' });
}

async function bookings(req, res) {
  const result = await pool.query(
    `SELECT bk.booking_id, bk.booking_reference, bk.total_amount, bk.status, bk.created_at,
            u.name AS passenger_name, tr.trip_id, tr.departure_time, rs.origin, rs.destination
     FROM bookings bk
     INNER JOIN users u ON u.user_id = bk.user_id
     INNER JOIN trips tr ON tr.trip_id = bk.trip_id
     INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     WHERE rs.company_id = $1
     ORDER BY bk.created_at DESC
     LIMIT 100`,
    [companyIdFrom(req)]
  );
  return res.json({ bookings: result.rows });
}

module.exports = {
  bookings,
  createBus,
  createRoute,
  createSchedule,
  createStaff,
  dashboard,
  deleteBus,
  deleteRoute,
  deleteSchedule,
  deleteStaff,
  listBuses,
  listRoutes,
  listSchedules,
  listStaff,
  updateBus,
  updateRoute,
  updateSchedule,
};
