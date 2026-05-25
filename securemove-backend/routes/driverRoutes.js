const express = require('express');
const path = require('path');
const fs = require('fs');

const pool = require('../db');
const checkRole = require('../middleware/checkRole');

let multer = null;
let sharp = null;
try {
  multer = require('multer');
  sharp = require('sharp');
} catch {
  // Photo upload route returns 503 until optional image dependencies are installed.
}

const router = express.Router();
const driverOnly = checkRole('driver');
const upload = multer
  ? multer({
      storage: multer.memoryStorage(),
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (req, file, cb) => {
        if (!file.mimetype?.startsWith('image/')) {
          cb(new Error('Only image uploads are allowed'));
          return;
        }
        cb(null, true);
      },
    })
  : null;

router.use(driverOnly);

router.get('/me', async (req, res) => {
  try {
    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const stats = await driverStats(driver.driver_id, driver.created_at);
    return res.json({ driver: toDriverProfile(driver, stats) });
  } catch (error) {
    console.error('Driver profile error:', error.message);
    return res.status(500).json({ error: 'Unable to load driver profile' });
  }
});

router.put('/profile', async (req, res) => {
  const fullName = typeof req.body?.fullName === 'string'
    ? req.body.fullName.trim()
    : typeof req.body?.full_name === 'string'
      ? req.body.full_name.trim()
      : null;
  const phone = typeof req.body?.phone === 'string'
    ? req.body.phone.trim()
    : typeof req.body?.phone_number === 'string'
      ? req.body.phone_number.trim()
      : null;

  if (phone && !/^\+?[0-9\s-]{9,18}$/.test(phone)) {
    return res.status(400).json({ error: 'Enter a valid phone number.' });
  }

  try {
    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const result = await pool.query(
      `UPDATE drivers
       SET full_name = COALESCE($1, full_name),
           phone_number = COALESCE($2, phone_number)
       WHERE driver_id = $3
       RETURNING *`,
      [fullName || null, phone || null, driver.driver_id]
    );

    const stats = await driverStats(driver.driver_id, driver.created_at);
    return res.json({ driver: toDriverProfile(result.rows[0], stats) });
  } catch (error) {
    console.error('Driver profile update error:', error.message);
    return res.status(500).json({ error: 'Unable to update driver profile' });
  }
});

router.put('/profile/photo', upload ? upload.single('photo') : (req, res) => {
  res.status(503).json({ error: 'Photo upload dependencies are not installed. Run npm install.' });
}, async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'A profile photo image is required.' });
    }

    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const uploadDir = path.join(__dirname, '..', 'uploads', 'driver-photos');
    fs.mkdirSync(uploadDir, { recursive: true });
    const fileName = `driver-${driver.driver_id}-${Date.now()}.jpg`;
    const filePath = path.join(uploadDir, fileName);

    await sharp(req.file.buffer)
      .resize(400, 400, { fit: 'cover' })
      .jpeg({ quality: 86 })
      .toFile(filePath);

    const photoUrl = `/uploads/driver-photos/${fileName}`;
    const result = await pool.query(
      `UPDATE drivers
       SET profile_photo_url = $1
       WHERE driver_id = $2
       RETURNING *`,
      [photoUrl, driver.driver_id]
    );
    const stats = await driverStats(driver.driver_id, driver.created_at);

    return res.json({
      profilePhoto: photoUrl,
      driver: toDriverProfile(result.rows[0], stats),
    });
  } catch (error) {
    console.error('Driver photo upload error:', error.message);
    return res.status(500).json({ error: 'Unable to upload profile photo' });
  }
});

router.get('/trips', async (req, res) => {
  try {
    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const status = String(req.query.status || 'upcoming').toLowerCase();
    const params = [driver.driver_id];
    let filter = '';
    if (status === 'upcoming') {
      filter = `AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED') AND tr.departure_time >= NOW() - INTERVAL '2 hours'`;
    } else if (status === 'completed') {
      filter = `AND tr.status IN ('completed', 'COMPLETED')`;
    }

    const result = await pool.query(
      tripSelectSql(`${filter} ORDER BY tr.departure_time ASC`),
      params
    );
    return res.json({ trips: result.rows.map(toDriverTrip) });
  } catch (error) {
    console.error('Driver trips error:', error.message);
    return res.status(500).json({ error: 'Unable to load driver trips' });
  }
});

router.get('/trips/:id', async (req, res) => {
  const tripId = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(tripId) || tripId <= 0) {
    return res.status(400).json({ error: 'A valid trip id is required' });
  }

  try {
    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    const result = await pool.query(
      tripSelectSql('AND tr.trip_id = $2'),
      [driver.driver_id, tripId]
    );
    if (result.rowCount === 0) {
      return res.status(403).json({ error: 'This trip is not assigned to the current driver' });
    }

    return res.json({ trip: toDriverTrip(result.rows[0]) });
  } catch (error) {
    console.error('Driver trip detail error:', error.message);
    return res.status(500).json({ error: 'Unable to load trip detail' });
  }
});

router.get('/notifications', async (req, res) => {
  try {
    const driver = await findCurrentDriver(req);
    if (!driver) {
      return res.status(404).json({ error: 'No driver profile is linked to this login email' });
    }

    await ensureLicenseReminder(driver);

    const result = await pool.query(
      `SELECT notification_id, title, message, kind, read_at, created_at
       FROM driver_notifications
       WHERE driver_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [driver.driver_id]
    );
    return res.json({ notifications: result.rows });
  } catch (error) {
    console.error('Driver notifications error:', error.message);
    return res.status(500).json({ error: 'Unable to load notifications' });
  }
});

async function findCurrentDriver(req) {
  const result = await pool.query(
    `SELECT d.*, c.name AS company_name
     FROM drivers d
     INNER JOIN companies c ON c.company_id = d.company_id
     WHERE LOWER(d.email) = LOWER($1)
       AND d.is_active = TRUE
     LIMIT 1`,
    [req.user.email]
  );
  return result.rows[0] ?? null;
}

async function driverStats(driverId, memberSince) {
  const result = await pool.query(
    `SELECT
       COUNT(*) FILTER (WHERE status IN ('completed', 'COMPLETED'))::int AS total_trips,
       COALESCE(SUM(rs.duration_minutes) FILTER (WHERE tr.status IN ('completed', 'COMPLETED')), 0)::numeric AS completed_minutes
     FROM trips tr
     LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
     WHERE tr.driver_id = $1`,
    [driverId]
  );
  const row = result.rows[0] ?? {};
  return {
    totalTrips: row.total_trips ?? 0,
    totalDistanceKm: Number(row.completed_minutes ?? 0) * 1.2,
    memberSince,
  };
}

function toDriverProfile(driver, stats) {
  return {
    id: driver.driver_id,
    driver_id: driver.driver_id,
    companyId: driver.company_id,
    company_id: driver.company_id,
    fullName: driver.full_name,
    full_name: driver.full_name,
    email: driver.email,
    phone: driver.phone_number,
    phone_number: driver.phone_number,
    nrcNumber: driver.nrc_number,
    nrc_number: driver.nrc_number,
    licenseNumber: driver.license_number,
    license_number: driver.license_number,
    licenseClass: driver.license_class,
    license_class: driver.license_class,
    licenseExpiry: driver.license_expiry,
    license_expiry: driver.license_expiry,
    profilePhoto: driver.profile_photo_url,
    profile_photo_url: driver.profile_photo_url,
    status: driver.status,
    is_active: driver.is_active,
    companyName: driver.company_name,
    company_name: driver.company_name,
    created_at: driver.created_at,
    stats: {
      totalTrips: stats.totalTrips,
      totalDistanceKm: Number(stats.totalDistanceKm || 0).toFixed(0),
      memberSince: stats.memberSince,
    },
  };
}

function tripSelectSql(extraWhere) {
  return `SELECT
      tr.trip_id,
      tr.driver_id,
      tr.conductor_id,
      tr.departure_time,
      tr.arrival_time,
      tr.available_seats,
      tr.status,
      rs.origin,
      rs.destination,
      rs.duration_minutes,
      rs.features AS stops,
      c.name AS company_name,
      b.registration_number,
      b.capacity,
      b.type AS bus_type,
      co.full_name AS conductor_name,
      co.badge_number AS conductor_badge,
      COUNT(tk.ticket_id) FILTER (WHERE tk.status = 'used')::int AS boarded_count,
      COUNT(tk.ticket_id)::int AS passenger_count
    FROM trips tr
    LEFT JOIN route_schedules rs ON rs.schedule_id = tr.schedule_id
    LEFT JOIN companies c ON c.company_id = rs.company_id
    LEFT JOIN buses b ON b.bus_id = tr.bus_id
    LEFT JOIN conductors co ON co.conductor_id = tr.conductor_id
    LEFT JOIN bookings bk ON bk.trip_id = tr.trip_id AND bk.status = 'paid'
    LEFT JOIN tickets tk ON tk.booking_id = bk.booking_id
    WHERE tr.driver_id = $1
    ${extraWhere}
    GROUP BY tr.trip_id, rs.origin, rs.destination, rs.duration_minutes, rs.features,
             c.name, b.registration_number, b.capacity, b.type,
             co.full_name, co.badge_number`;
}

function toDriverTrip(row) {
  return {
    ...row,
    status_label: tripStatus(row.status, row.departure_time),
  };
}

function tripStatus(status, departureTime) {
  const value = String(status || '').toUpperCase();
  if (value === 'COMPLETED') return 'COMPLETED';
  if (value === 'CANCELLED') return 'CANCELLED';
  if (value === 'DEPARTED' || value === 'BOARDING') return 'IN PROGRESS';
  if (departureTime && new Date(departureTime) < new Date()) return 'IN PROGRESS';
  return 'UPCOMING';
}

async function ensureLicenseReminder(driver) {
  if (!driver.license_expiry) return;
  const expiry = new Date(driver.license_expiry);
  const days = Math.ceil((expiry.getTime() - Date.now()) / (24 * 60 * 60 * 1000));
  if (days < 0 || days > 30) return;

  await pool.query(
    `INSERT INTO driver_notifications (driver_id, title, message, kind)
     SELECT $1, 'License expiry reminder', $2, 'warning'
     WHERE NOT EXISTS (
       SELECT 1
       FROM driver_notifications
       WHERE driver_id = $1
         AND title = 'License expiry reminder'
         AND created_at >= NOW() - INTERVAL '1 day'
     )`,
    [driver.driver_id, `Your driver's license expires in ${days} day${days === 1 ? '' : 's'}.`]
  );
}

module.exports = router;
