const pool = require('../db');

async function dashboard(req, res) {
  const [
    companies,
    users,
    bookings,
    drivers,
    conductors,
    pendingCompanies,
    revenue,
    recentUsers,
    recentBookings,
  ] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS count FROM companies'),
    pool.query('SELECT COUNT(*)::int AS count FROM users'),
    pool.query('SELECT COUNT(*)::int AS count FROM bookings'),
    pool.query('SELECT COUNT(*)::int AS count FROM users WHERE role_id = 4'),
    pool.query('SELECT COUNT(*)::int AS count FROM users WHERE role_id = 5'),
    pool.query("SELECT COUNT(*)::int AS count FROM companies WHERE approval_status <> 'approved'"),
    pool.query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE LOWER(status) IN ('successful', 'paid')), 0)::numeric AS total
       FROM payments`
    ),
    pool.query(
      `SELECT user_id, name, email, role_id, company_id, created_at
       FROM users
       ORDER BY created_at DESC
       LIMIT 5`
    ),
    pool.query(
      `SELECT bk.booking_id, bk.booking_reference, bk.status, bk.total_amount, bk.created_at,
              u.name AS passenger_name, rs.origin, rs.destination
       FROM bookings bk
       LEFT JOIN users u ON u.user_id = bk.user_id
       LEFT JOIN trips tr ON tr.trip_id = bk.trip_id
       LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       ORDER BY bk.created_at DESC
       LIMIT 5`
    ),
  ]);

  return res.json({
    stats: {
      totalCompanies: companies.rows[0].count,
      totalUsers: users.rows[0].count,
      totalBookings: bookings.rows[0].count,
      totalDrivers: drivers.rows[0].count,
      totalConductors: conductors.rows[0].count,
      pendingCompanies: pendingCompanies.rows[0].count,
      systemRevenue: Number(revenue.rows[0].total ?? 0),
    },
    recentUsers: recentUsers.rows.map(withRoleValue),
    recentBookings: recentBookings.rows,
  });
}

async function companies(req, res) {
  const result = await pool.query(
    `SELECT c.company_id,
            c.name,
            c.approval_status,
            c.created_at,
            COUNT(DISTINCT b.bus_id)::int AS bus_count,
            COUNT(DISTINCT rs.schedule_id)::int AS route_count,
            COUNT(DISTINCT d.driver_id)::int AS driver_count,
            COUNT(DISTINCT co.conductor_id)::int AS conductor_count,
            MIN(u.name) FILTER (WHERE u.role_id = 2) AS owner_name,
            MIN(u.email) FILTER (WHERE u.role_id = 2) AS owner_email
     FROM companies c
     LEFT JOIN buses b ON b.company_id = c.company_id AND b.is_active = TRUE
     LEFT JOIN route_schedules rs ON rs.company_id = c.company_id AND rs.active = TRUE
     LEFT JOIN drivers d ON d.company_id = c.company_id AND d.is_active = TRUE
     LEFT JOIN conductors co ON co.company_id = c.company_id AND co.is_active = TRUE
     LEFT JOIN users u ON u.company_id = c.company_id
     GROUP BY c.company_id
     ORDER BY c.created_at DESC`
  );
  return res.json({ companies: result.rows });
}

async function approveCompany(req, res) {
  const result = await pool.query(
    `UPDATE companies
     SET approval_status = 'approved'
     WHERE company_id = $1
     RETURNING company_id, name, approval_status, created_at`,
    [req.params.id]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'Company not found' });
  return res.json({ company: result.rows[0] });
}

async function deleteCompany(req, res) {
  const result = await pool.query('DELETE FROM companies WHERE company_id = $1 RETURNING company_id', [req.params.id]);
  if (result.rowCount === 0) return res.status(404).json({ error: 'Company not found' });
  return res.json({ message: 'Company removed' });
}

async function users(req, res) {
  const role = req.query.role === 'all' ? null : req.query.role;
  const page = Math.max(Number.parseInt(req.query.page ?? '1', 10), 1);
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit ?? '20', 10), 1), 100);
  const search = String(req.query.search ?? '').trim();
  const params = [];
  const clauses = [];
  if (role) {
    const roleId = roleToId(role);
    if (roleId) {
      params.push(roleId);
      clauses.push(`role_id = $${params.length}`);
    }
  }
  if (search) {
    params.push(`%${search.toLowerCase()}%`);
    clauses.push(`(LOWER(name) LIKE $${params.length} OR LOWER(email) LIKE $${params.length})`);
  }
  const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  const offset = (page - 1) * limit;

  const [result, total] = await Promise.all([
    pool.query(
    `SELECT user_id, name, email, role_id, company_id, created_at
     FROM users
     ${where}
     ORDER BY created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset]
    ),
    pool.query(`SELECT COUNT(*)::int AS count FROM users ${where}`, params),
  ]);
  return res.json({
    users: result.rows.map(withRoleValue),
    total: total.rows[0].count,
    pages: Math.ceil(total.rows[0].count / limit),
    currentPage: page,
  });
}

async function updateUserRole(req, res) {
  const roleId = roleToId(req.body?.role);
  if (!roleId) return res.status(400).json({ error: 'A valid role is required' });

  const result = await pool.query(
    `UPDATE users
     SET role_id = $1
     WHERE user_id = $2
     RETURNING user_id, name, email, role_id, company_id, created_at`,
    [roleId, req.params.id]
  );
  if (result.rowCount === 0) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: withRoleValue(result.rows[0]) });
}

async function deleteUser(req, res) {
  const result = await pool.query('DELETE FROM users WHERE user_id = $1 RETURNING user_id', [req.params.id]);
  if (result.rowCount === 0) return res.status(404).json({ error: 'User not found' });
  return res.json({ message: 'User deleted' });
}

async function transactions(req, res) {
  const result = await pool.query(
    `SELECT p.payment_id, p.amount, p.status, p.provider, p.payment_method, p.created_at,
            c.name AS company_name
     FROM payments p
     INNER JOIN bookings bk ON bk.booking_id = p.booking_id
     INNER JOIN trips tr ON tr.trip_id = bk.trip_id
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN companies c ON c.company_id = rs.company_id
     ORDER BY p.created_at DESC
     LIMIT 100`
  );
  return res.json({ transactions: result.rows });
}

async function securityLogs(req, res) {
  const result = await pool.query(
    `SELECT audit_log_id, event_type, status, severity, email, user_id, ip_address, user_agent, details, created_at
     FROM audit_logs
     ORDER BY created_at DESC
     LIMIT 100`
  );
  return res.json({ logs: result.rows });
}

async function scanLogs(req, res) {
  const params = [];
  const where = [];

  if (req.query.conductorId) {
    params.push(Number(req.query.conductorId));
    where.push(`tse.conductor_id = $${params.length}`);
  }
  if (req.query.tripId) {
    params.push(Number(req.query.tripId));
    where.push(`tse.trip_id = $${params.length}`);
  }
  if (req.query.result) {
    params.push(String(req.query.result));
    where.push(`tse.result_status = $${params.length}`);
  }
  if (req.query.fraudAlert === 'true') {
    where.push('tse.fraud_alert = TRUE');
  }
  if (req.query.from) {
    params.push(String(req.query.from));
    where.push(`tse.created_at >= $${params.length}::timestamptz`);
  }
  if (req.query.to) {
    params.push(String(req.query.to));
    where.push(`tse.created_at <= $${params.length}::timestamptz`);
  }

  const result = await pool.query(
    `SELECT tse.scan_event_id,
            tse.ticket_id,
            tse.conductor_id,
            tse.trip_id,
            tse.result_status,
            tse.ip_address,
            tse.device_info,
            tse.qr_hash,
            tse.fraud_alert,
            tse.details,
            tse.created_at,
            co.full_name AS conductor_name,
            tk.ticket_number,
            rs.origin,
            rs.destination,
            b.registration_number
     FROM ticket_scan_events tse
     LEFT JOIN conductors co ON co.conductor_id = tse.conductor_id
     LEFT JOIN tickets tk ON tk.ticket_id = tse.ticket_id
     LEFT JOIN bookings bk ON bk.booking_id = tk.booking_id
     LEFT JOIN trips tr ON tr.trip_id = COALESCE(tse.trip_id, bk.trip_id)
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     LEFT JOIN buses b ON b.bus_id = tr.bus_id
     ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
     ORDER BY tse.created_at DESC
     LIMIT 200`,
    params
  );

  return res.json({ scanLogs: result.rows });
}

async function reports(req, res) {
  const generatedAt = new Date();
  const [companyCount, userCount, bookingCount, revenue] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS count FROM companies'),
    pool.query('SELECT COUNT(*)::int AS count FROM users'),
    pool.query('SELECT COUNT(*)::int AS count FROM bookings'),
    pool.query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE LOWER(status) IN ('successful', 'paid')), 0)::numeric AS total
       FROM payments`
    ),
  ]);
  return res.json({
    report: {
      reportId: `SM-${generatedAt.toISOString().replace(/[-:T.Z]/g, '').slice(0, 14)}`,
      generatedAt: generatedAt.toISOString(),
      totalCompanies: companyCount.rows[0].count,
      totalUsers: userCount.rows[0].count,
      totalBookings: bookingCount.rows[0].count,
      revenue: Number(revenue.rows[0].total ?? 0),
    },
  });
}

async function analytics(req, res) {
  const [revenueOverTime, bookingsPerRoute, peakTravelTimes] = await Promise.all([
    pool.query(
      `SELECT DATE(created_at) AS day, COALESCE(SUM(total_amount), 0)::numeric AS revenue
       FROM bookings
       WHERE status = 'paid'
       GROUP BY DATE(created_at)
       ORDER BY day DESC
       LIMIT 30`
    ),
    pool.query(
      `SELECT rs.origin, rs.destination, COUNT(*)::int AS bookings
       FROM bookings bk
       INNER JOIN trips tr ON tr.trip_id = bk.trip_id
       LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       GROUP BY rs.origin, rs.destination
       ORDER BY bookings DESC
       LIMIT 20`
    ),
    pool.query(
      `SELECT TO_CHAR(departure_time, 'HH24:00') AS hour, COUNT(*)::int AS trips
       FROM trips
       GROUP BY TO_CHAR(departure_time, 'HH24:00')
       ORDER BY trips DESC
       LIMIT 10`
    ),
  ]);
  return res.json({
    revenueOverTime: revenueOverTime.rows,
    bookingsPerRoute: bookingsPerRoute.rows,
    peakTravelTimes: peakTravelTimes.rows,
  });
}

function roleToId(role) {
  if (role === 'passenger') return 1;
  if (role === 'company_admin') return 2;
  if (role === 'super_admin') return 3;
  if (role === 'driver') return 4;
  if (role === 'conductor') return 5;
  return Number.isInteger(Number(role)) ? Number(role) : null;
}

function withRoleValue(user) {
  const roles = { 1: 'passenger', 2: 'company_admin', 3: 'super_admin', 4: 'driver', 5: 'conductor' };
  return { ...user, role: roles[user.role_id] || 'passenger' };
}

module.exports = {
  approveCompany,
  analytics,
  companies,
  dashboard,
  deleteCompany,
  deleteUser,
  reports,
  securityLogs,
  scanLogs,
  transactions,
  updateUserRole,
  users,
};
