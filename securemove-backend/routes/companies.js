const express = require('express');
const router = express.Router();
const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');
const {
  canManageCompany,
  isCompanyAdmin,
  isSystemAdmin,
  requireManagementUser,
} = require('../middleware/authorization');

router.get('/', authenticateToken, requireManagementUser, async (req, res) => {
  try {
    if (isCompanyAdmin(req.user)) {
      if (!req.user.company_id) {
        return res.status(403).json({ error: 'No company is linked to this admin account' });
      }

      const result = await pool.query(
        'SELECT * FROM companies WHERE company_id = $1 ORDER BY company_id ASC',
        [req.user.company_id]
      );
      return res.json(result.rows);
    }

    const result = await pool.query(
      'SELECT * FROM companies ORDER BY company_id ASC'
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Fetch companies error:', err.message);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:companyId/dashboard', authenticateToken, async (req, res) => {
  const companyId = Number.parseInt(req.params.companyId, 10);

  if (!Number.isInteger(companyId) || companyId <= 0) {
    return res.status(400).json({ error: 'A valid companyId is required' });
  }
  if (!canManageCompany(req.user, companyId)) {
    return res.status(403).json({ error: 'You can only manage your assigned company' });
  }

  try {
    const [companyResult, busResult, driverResult, tripResult, bookingResult] = await Promise.all([
      pool.query('SELECT company_id, name, created_at FROM companies WHERE company_id = $1', [companyId]),
      pool.query('SELECT COUNT(*)::int AS count FROM buses WHERE company_id = $1 AND is_active = TRUE', [companyId]),
      pool.query('SELECT COUNT(*)::int AS count FROM drivers WHERE company_id = $1 AND is_active = TRUE', [companyId]),
      pool.query(
        `SELECT
           COUNT(*)::int AS total_trips,
           COUNT(*) FILTER (WHERE status = 'scheduled')::int AS scheduled_trips
         FROM trips t
         INNER JOIN route_schedules rs ON rs.schedule_id = t.schedule_id
         WHERE rs.company_id = $1`,
        [companyId]
      ),
      pool.query(
        `SELECT
           COUNT(*)::int AS total_bookings,
           COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0)::numeric AS paid_revenue
         FROM bookings b
         INNER JOIN trips t ON t.trip_id = b.trip_id
         INNER JOIN route_schedules rs ON rs.schedule_id = t.schedule_id
         WHERE rs.company_id = $1`,
        [companyId]
      ),
    ]);

    if (companyResult.rowCount === 0) {
      return res.status(404).json({ error: 'Company not found' });
    }

    return res.json({
      company: companyResult.rows[0],
      stats: {
        totalBuses: busResult.rows[0].count,
        totalDrivers: driverResult.rows[0].count,
        totalTrips: tripResult.rows[0].total_trips,
        scheduledTrips: tripResult.rows[0].scheduled_trips,
        totalBookings: bookingResult.rows[0].total_bookings,
        paidRevenue: bookingResult.rows[0].paid_revenue,
      },
    });
  } catch (err) {
    console.error('Company dashboard error:', err.message);
    res.status(500).json({ error: 'Unable to load company dashboard' });
  }
});

router.get('/:companyId/schedules', authenticateToken, requireManagementUser, async (req, res) => {
  const companyId = Number.parseInt(req.params.companyId, 10);

  if (!Number.isInteger(companyId) || companyId <= 0) {
    return res.status(400).json({ error: 'A valid companyId is required' });
  }
  if (!canManageCompany(req.user, companyId)) {
    return res.status(403).json({ error: 'You can only manage your assigned company' });
  }

  try {
    const result = await pool.query(
      `SELECT schedule_id, company_id, origin, destination, departure_time, price, duration_minutes, features, active, created_at
       FROM route_schedules
       WHERE company_id = $1
       ORDER BY origin ASC, destination ASC, departure_time ASC`,
      [companyId]
    );

    return res.json({ schedules: result.rows });
  } catch (err) {
    console.error('Fetch company schedules error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch company schedules' });
  }
});

router.patch('/:companyId/schedules/:scheduleId', authenticateToken, requireManagementUser, async (req, res) => {
  const companyId = Number.parseInt(req.params.companyId, 10);
  const scheduleId = Number.parseInt(req.params.scheduleId, 10);
  const { price, active } = req.body ?? {};

  if (!Number.isInteger(companyId) || companyId <= 0 || !Number.isInteger(scheduleId) || scheduleId <= 0) {
    return res.status(400).json({ error: 'A valid companyId and scheduleId are required' });
  }
  if (!canManageCompany(req.user, companyId)) {
    return res.status(403).json({ error: 'You can only manage your assigned company' });
  }
  if (price != null && String(price).trim().isEmpty) {
    return res.status(400).json({ error: 'Price cannot be empty' });
  }

  try {
    const result = await pool.query(
      `UPDATE route_schedules
       SET price = COALESCE($1, price),
           active = COALESCE($2, active)
       WHERE schedule_id = $3
         AND company_id = $4
       RETURNING schedule_id, company_id, origin, destination, departure_time, price, duration_minutes, features, active, created_at`,
      [
        price == null ? null : String(price).trim(),
        typeof active === 'boolean' ? active : null,
        scheduleId,
        companyId,
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Schedule not found for this company' });
    }

    return res.json({ schedule: result.rows[0] });
  } catch (err) {
    console.error('Update company schedule error:', err.message);
    return res.status(500).json({ error: 'Unable to update schedule' });
  }
});

router.get('/:companyId/tickets', authenticateToken, requireManagementUser, async (req, res) => {
  const companyId = Number.parseInt(req.params.companyId, 10);

  if (!Number.isInteger(companyId) || companyId <= 0) {
    return res.status(400).json({ error: 'A valid companyId is required' });
  }
  if (!canManageCompany(req.user, companyId)) {
    return res.status(403).json({ error: 'You can only manage your assigned company' });
  }

  try {
    const result = await pool.query(
      `SELECT tk.ticket_id, tk.booking_id, tk.passenger_name, tk.seat_number, tk.ticket_number,
              tk.status, tk.verified_at, tk.created_at,
              b.booking_reference, b.total_amount, b.status AS booking_status,
              tr.trip_id, tr.departure_time,
              rs.origin, rs.destination,
              d.full_name AS driver_name
       FROM tickets tk
       INNER JOIN bookings b ON b.booking_id = tk.booking_id
       INNER JOIN trips tr ON tr.trip_id = b.trip_id
       INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       LEFT JOIN drivers d ON d.driver_id = tr.driver_id
       WHERE rs.company_id = $1
       ORDER BY tk.created_at DESC
       LIMIT 100`,
      [companyId]
    );

    return res.json({ tickets: result.rows });
  } catch (err) {
    console.error('Fetch company tickets error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch company tickets' });
  }
});

module.exports = router;
