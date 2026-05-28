const express = require('express');

const pool = require('../db');

const router = express.Router();

router.get('/search', async (req, res) => {
  const from = String(req.query.from ?? '').trim();
  const to = String(req.query.to ?? '').trim();

  if (!from || !to) {
    return res.status(400).json({
      error: 'Both from and to query parameters are required',
    });
  }

  try {
    const result = await pool.query(
      `SELECT
         rs.schedule_id,
         t.trip_id,
         t.driver_id,
         c.name AS company,
         rs.origin,
         rs.destination,
         rs.departure_time,
         rs.price,
         rs.duration_minutes,
         rs.features,
         t.departure_time AS trip_departure_time,
         t.available_seats,
         d.full_name AS driver_name,
         d.phone_number AS driver_phone,
         d.license_number,
         b.registration_number
       FROM route_schedules rs
       INNER JOIN companies c ON c.company_id = rs.company_id
       LEFT JOIN trips t ON t.schedule_id = rs.schedule_id
         AND t.status IN ('scheduled', 'boarding', 'BOARDING')
         AND t.departure_time >= NOW() - INTERVAL '30 minutes'
       LEFT JOIN drivers d ON d.driver_id = t.driver_id
       LEFT JOIN buses b ON b.bus_id = t.bus_id
       WHERE rs.active = TRUE
         AND LOWER(rs.origin) = LOWER($1)
         AND LOWER(rs.destination) = LOWER($2)
       ORDER BY t.departure_time ASC NULLS LAST, rs.departure_time ASC, t.trip_id ASC`,
      [from, to]
    );

    return res.json({ routes: result.rows });
  } catch (err) {
    console.error('Route search error:', err.message);
    return res.status(500).json({ error: 'Unable to search routes' });
  }
});

module.exports = router;
