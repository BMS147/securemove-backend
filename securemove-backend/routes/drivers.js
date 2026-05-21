const express = require('express');

const pool = require('../db');
const authenticateToken = require('../middleware/authenticateToken');
const {
  canManageCompany,
  isCompanyAdmin,
  isDriver,
  isSystemAdmin,
  requireManagementUser,
} = require('../middleware/authorization');

const router = express.Router();

router.get('/company/:companyId', authenticateToken, requireManagementUser, async (req, res) => {
  const companyId = Number.parseInt(req.params.companyId, 10);

  if (!Number.isInteger(companyId) || companyId <= 0) {
    return res.status(400).json({ error: 'A valid companyId is required' });
  }
  if (!canManageCompany(req.user, companyId)) {
    return res.status(403).json({ error: 'You can only manage your assigned company' });
  }

  try {
    const result = await pool.query(
      `SELECT driver_id, company_id, full_name, email, phone_number, license_number, is_active, created_at
       FROM drivers
       WHERE company_id = $1
       ORDER BY full_name ASC`,
      [companyId]
    );

    return res.json({ drivers: result.rows });
  } catch (err) {
    console.error('Fetch company drivers error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch drivers' });
  }
});

router.get('/me', authenticateToken, async (req, res) => {
  if (!isDriver(req.user)) {
    return res.status(403).json({ error: 'Driver access is required' });
  }

  try {
    const result = await pool.query(
      `SELECT d.driver_id, d.company_id, d.full_name, d.email, d.phone_number, d.license_number, d.is_active, d.created_at,
              c.name AS company_name
       FROM drivers d
       INNER JOIN companies c ON c.company_id = d.company_id
       WHERE LOWER(d.email) = LOWER($1)
       LIMIT 1`,
      [req.user.email]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    return res.json({ driver: result.rows[0] });
  } catch (err) {
    console.error('Fetch current driver error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch current driver' });
  }
});

router.get('/me/trips', authenticateToken, async (req, res) => {
  if (!isDriver(req.user)) {
    return res.status(403).json({ error: 'Driver access is required' });
  }

  try {
    const driverResult = await pool.query(
      'SELECT driver_id FROM drivers WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [req.user.email]
    );

    if (driverResult.rowCount === 0) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const driverId = driverResult.rows[0].driver_id;
    const result = await pool.query(
      `SELECT
         t.trip_id,
         t.driver_id,
         t.departure_time,
         t.arrival_time,
         t.available_seats,
         t.status,
         rs.origin,
         rs.destination,
         c.name AS company_name,
         b.registration_number,
         b.capacity,
         COUNT(DISTINCT bk.booking_id)::int AS booking_count,
         COUNT(tk.ticket_id)::int AS ticket_count,
         COUNT(tk.ticket_id) FILTER (WHERE tk.status = 'used')::int AS used_ticket_count
       FROM trips t
       LEFT JOIN route_schedules rs ON rs.schedule_id = t.schedule_id
       LEFT JOIN companies c ON c.company_id = rs.company_id
       LEFT JOIN buses b ON b.bus_id = t.bus_id
       LEFT JOIN bookings bk ON bk.trip_id = t.trip_id AND bk.status = 'paid'
       LEFT JOIN tickets tk ON tk.booking_id = bk.booking_id
       WHERE t.driver_id = $1
       GROUP BY t.trip_id, rs.origin, rs.destination, c.name, b.registration_number, b.capacity
       ORDER BY t.departure_time ASC`,
      [driverId]
    );

    return res.json({ trips: result.rows });
  } catch (err) {
    console.error('Fetch driver trips error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch driver trips' });
  }
});

router.get('/trips/:tripId/tickets', authenticateToken, async (req, res) => {
  if (!isDriver(req.user)) {
    return res.status(403).json({ error: 'Driver access is required' });
  }

  const tripId = Number.parseInt(req.params.tripId, 10);

  if (!Number.isInteger(tripId) || tripId <= 0) {
    return res.status(400).json({ error: 'A valid trip id is required' });
  }

  try {
    const driverResult = await pool.query(
      'SELECT driver_id FROM drivers WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [req.user.email]
    );

    if (driverResult.rowCount === 0) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const accessResult = await pool.query(
      'SELECT trip_id FROM trips WHERE trip_id = $1 AND driver_id = $2',
      [tripId, driverResult.rows[0].driver_id]
    );

    if (accessResult.rowCount === 0) {
      return res.status(403).json({ error: 'This trip is not assigned to the current driver' });
    }

    const result = await pool.query(
      `SELECT tk.ticket_id, tk.booking_id, tk.passenger_name, tk.seat_number, tk.ticket_number,
              tk.qr_code_hash, tk.status, tk.verified_at, tk.created_at,
              bk.booking_reference
       FROM tickets tk
       INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
       WHERE bk.trip_id = $1
       ORDER BY tk.created_at ASC`,
      [tripId]
    );

    return res.json({ tickets: result.rows });
  } catch (err) {
    console.error('Fetch trip tickets error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch trip tickets' });
  }
});

router.post('/tickets/verify', authenticateToken, async (req, res) => {
  const code = String(req.body?.code ?? '').trim();

  if (!code) {
    return res.status(400).json({ error: 'A ticket code or booking reference is required' });
  }

  try {
    const driverResult = await pool.query(
      'SELECT driver_id FROM drivers WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [req.user.email]
    );

    if (isDriver(req.user) && driverResult.rowCount === 0) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const driverId = driverResult.rows[0]?.driver_id ?? null;
    const ticketResult = await pool.query(
      `SELECT tk.ticket_id, tk.booking_id, tk.passenger_name, tk.seat_number, tk.ticket_number,
              tk.qr_code_hash, tk.status, tk.verified_at, tk.created_at,
              bk.booking_reference, bk.trip_id, tr.driver_id, rs.company_id
       FROM tickets tk
       INNER JOIN bookings bk ON bk.booking_id = tk.booking_id
       INNER JOIN trips tr ON tr.trip_id = bk.trip_id
       INNER JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
       WHERE tk.ticket_number = $1
          OR tk.qr_code_hash = $1
          OR bk.booking_reference = $1
       ORDER BY tk.ticket_id ASC
       LIMIT 1`,
      [code]
    );

    if (ticketResult.rowCount === 0) {
      return res.status(404).json({ error: 'Ticket not found' });
    }

    const ticket = ticketResult.rows[0];
    const canVerifyAsDriver = isDriver(req.user) && ticket.driver_id === driverId;
    const canVerifyAsManager = (isSystemAdmin(req.user) || isCompanyAdmin(req.user))
      && canManageCompany(req.user, ticket.company_id);

    if (!canVerifyAsDriver && !canVerifyAsManager) {
      return res.status(403).json({ error: 'This ticket belongs to another driver trip' });
    }
    if (ticket.status === 'used') {
      return res.status(409).json({ error: 'Ticket has already been verified' });
    }
    if (ticket.status !== 'active') {
      return res.status(409).json({ error: `Ticket is ${ticket.status}` });
    }

    const result = await pool.query(
      `UPDATE tickets
       SET status = 'used',
           verified_at = NOW(),
           verified_by_driver_id = $1
       WHERE ticket_id = $2
       RETURNING ticket_id, booking_id, passenger_name, seat_number, ticket_number,
                 qr_code_hash, status, verified_at, created_at`,
      [driverId, ticket.ticket_id]
    );

    return res.json({
      ticket: {
        ...result.rows[0],
        booking_reference: ticket.booking_reference,
      },
      message: 'Ticket verified successfully',
    });
  } catch (err) {
    console.error('Verify ticket error:', err.message);
    return res.status(500).json({ error: 'Unable to verify ticket' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  const driverId = Number.parseInt(req.params.id, 10);

  if (!Number.isInteger(driverId) || driverId <= 0) {
    return res.status(400).json({ error: 'A valid driver id is required' });
  }

  try {
    const result = await pool.query(
      `SELECT d.driver_id, d.company_id, d.full_name, d.email, d.phone_number, d.license_number, d.is_active, d.created_at,
              c.name AS company_name
       FROM drivers d
       INNER JOIN companies c ON c.company_id = d.company_id
       WHERE d.driver_id = $1`,
      [driverId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    return res.json({ driver: result.rows[0] });
  } catch (err) {
    console.error('Fetch driver error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch driver' });
  }
});

router.post('/', authenticateToken, requireManagementUser, async (req, res) => {
  const { company_id, full_name, email, phone_number, license_number } = req.body ?? {};

  if (!company_id || !full_name || !license_number) {
    return res.status(400).json({ error: 'company_id, full_name, and license_number are required' });
  }
  if (!canManageCompany(req.user, company_id)) {
    return res.status(403).json({ error: 'You can only manage drivers for your assigned company' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO drivers (company_id, full_name, email, phone_number, license_number)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING driver_id, company_id, full_name, email, phone_number, license_number, is_active, created_at`,
      [
        company_id,
        String(full_name).trim(),
        email ? String(email).trim().toLowerCase() : null,
        phone_number ? String(phone_number).trim() : null,
        String(license_number).trim().toUpperCase(),
      ]
    );

    return res.status(201).json({ driver: result.rows[0] });
  } catch (err) {
    console.error('Create driver error:', err.message);
    return res.status(500).json({ error: 'Unable to create driver' });
  }
});

router.patch('/:id', authenticateToken, requireManagementUser, async (req, res) => {
  const driverId = Number.parseInt(req.params.id, 10);
  const { full_name, email, phone_number, license_number, is_active } = req.body ?? {};

  if (!Number.isInteger(driverId) || driverId <= 0) {
    return res.status(400).json({ error: 'A valid driver id is required' });
  }

  try {
    const existing = await pool.query('SELECT company_id FROM drivers WHERE driver_id = $1', [driverId]);
    if (existing.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    if (!canManageCompany(req.user, existing.rows[0].company_id)) {
      return res.status(403).json({ error: 'You can only update drivers for your assigned company' });
    }

    const result = await pool.query(
      `UPDATE drivers
       SET full_name = COALESCE($1, full_name),
           email = COALESCE($2, email),
           phone_number = COALESCE($3, phone_number),
           license_number = COALESCE($4, license_number),
           is_active = COALESCE($5, is_active)
       WHERE driver_id = $6
       RETURNING driver_id, company_id, full_name, email, phone_number, license_number, is_active, created_at`,
      [
        full_name ? String(full_name).trim() : null,
        email ? String(email).trim().toLowerCase() : null,
        phone_number ? String(phone_number).trim() : null,
        license_number ? String(license_number).trim().toUpperCase() : null,
        typeof is_active === 'boolean' ? is_active : null,
        driverId,
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    return res.json({ driver: result.rows[0] });
  } catch (err) {
    console.error('Update driver error:', err.message);
    return res.status(500).json({ error: 'Unable to update driver' });
  }
});

router.delete('/:id', authenticateToken, requireManagementUser, async (req, res) => {
  const driverId = Number.parseInt(req.params.id, 10);

  if (!Number.isInteger(driverId) || driverId <= 0) {
    return res.status(400).json({ error: 'A valid driver id is required' });
  }

  try {
    const existing = await pool.query('SELECT company_id FROM drivers WHERE driver_id = $1', [driverId]);
    if (existing.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    if (!canManageCompany(req.user, existing.rows[0].company_id)) {
      return res.status(403).json({ error: 'You can only update drivers for your assigned company' });
    }

    const result = await pool.query(
      `UPDATE drivers
       SET is_active = FALSE
       WHERE driver_id = $1
       RETURNING driver_id`,
      [driverId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    return res.json({ message: 'Driver deactivated successfully' });
  } catch (err) {
    console.error('Delete driver error:', err.message);
    return res.status(500).json({ error: 'Unable to delete driver' });
  }
});

module.exports = router;
