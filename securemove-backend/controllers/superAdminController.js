const pool = require('../db');

async function dashboard(req, res) {
  const [companies, users, bookings, revenue, trips] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS count FROM companies'),
    pool.query('SELECT COUNT(*)::int AS count FROM users'),
    pool.query('SELECT COUNT(*)::int AS count FROM bookings'),
    pool.query("SELECT COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0)::numeric AS total FROM bookings"),
    pool.query("SELECT COUNT(*)::int AS count FROM trips WHERE status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')"),
  ]);

  return res.json({
    stats: {
      totalCompanies: companies.rows[0].count,
      totalUsers: users.rows[0].count,
      totalBookings: bookings.rows[0].count,
      revenue: revenue.rows[0].total,
      activeTrips: trips.rows[0].count,
    },
  });
}

async function companies(req, res) {
  const result = await pool.query(
    `SELECT company_id, name, approval_status, created_at
     FROM companies
     ORDER BY created_at DESC`
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
  const role = req.query.role;
  const params = [];
  let where = '';
  if (role) {
    const roleId = roleToId(role);
    where = 'WHERE role_id = $1';
    params.push(roleId);
  }

  const result = await pool.query(
    `SELECT user_id, name, email, role_id, company_id, created_at
     FROM users
     ${where}
     ORDER BY created_at DESC`,
    params
  );
  return res.json({ users: result.rows.map(withRoleValue) });
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

async function reports(req, res) {
  const [companyCount, bookingCount, revenue] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS count FROM companies'),
    pool.query('SELECT COUNT(*)::int AS count FROM bookings'),
    pool.query("SELECT COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0)::numeric AS total FROM bookings"),
  ]);
  return res.json({
    report: {
      generatedAt: new Date().toISOString(),
      totalCompanies: companyCount.rows[0].count,
      totalBookings: bookingCount.rows[0].count,
      revenue: revenue.rows[0].total,
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
  transactions,
  updateUserRole,
  users,
};
