const fs = require('fs');
const path = require('path');

const bcrypt = require('bcrypt');
const pool = require('../db');

const companies = [
  'Power Tools',
  'Likili Motorways',
  'Mazhandu Family Bus',
  'Shalom',
  'UBZ',
];

const demoPassword = 'SecureMove2024!';

const demoUsers = [
  user('System Admin', 'admin@securemove.dev', 3),
  user('Chanda Mwale', 'chanda@powertools.dev', 2, 'Power Tools'),
  user('Mary Phiri', 'mary@likili.dev', 2, 'Likili Motorways'),
  user('James Banda', 'james@mazhandu.dev', 2, 'Mazhandu Family Bus'),
  user('Susan Tembo', 'susan@shalom.dev', 2, 'Shalom'),
  user('Victor Zulu', 'victor@ubz.dev', 2, 'UBZ'),
  user('Benson Phiri', 'benson.phiri@securemove.dev', 4, 'Power Tools'),
  user('Ruth Mwila', 'ruth.mwila@securemove.dev', 4, 'Likili Motorways'),
  user('Peter Banda', 'peter.banda@securemove.dev', 4, 'Mazhandu Family Bus'),
  user('Grace Tembo', 'grace.tembo@securemove.dev', 4, 'Shalom'),
  user('Daniel Zulu', 'daniel.zulu@securemove.dev', 4, 'UBZ'),
  user('Officer Banda', 'officer.banda@securemove.dev', 5, 'Power Tools'),
  user('Officer Mwansa', 'officer.mwansa@securemove.dev', 5, 'Likili Motorways'),
  user('Officer Chirwa', 'officer.chirwa@securemove.dev', 5, 'Mazhandu Family Bus'),
  user('Officer Tembo', 'officer.tembo@securemove.dev', 5, 'Shalom'),
  user('Officer Zulu', 'officer.zulu@securemove.dev', 5, 'UBZ'),
  user('Temwa Banda', 'temwa@test.dev', 1),
  user('Chisomo Nkosi', 'chisomo@test.dev', 1),
  user('Mutale Mwanza', 'mutale@test.dev', 1),
  user('Lombe Kapasa', 'lombe@test.dev', 1),
];

const drivers = [
  driver('Power Tools', 'Benson Phiri', 'benson.phiri@securemove.dev', '0977000001', 'PT-DRV-001'),
  driver('Likili Motorways', 'Ruth Mwila', 'ruth.mwila@securemove.dev', '0977000002', 'LM-DRV-001'),
  driver('Mazhandu Family Bus', 'Peter Banda', 'peter.banda@securemove.dev', '0977000003', 'MF-DRV-001'),
  driver('Shalom', 'Grace Tembo', 'grace.tembo@securemove.dev', '0977000004', 'SH-DRV-001'),
  driver('UBZ', 'Daniel Zulu', 'daniel.zulu@securemove.dev', '0977000005', 'UBZ-DRV-001'),
];

const conductors = [
  conductor('Power Tools', 'Officer Banda', 'officer.banda@securemove.dev', '0977100001', 'PT-CON-001'),
  conductor('Likili Motorways', 'Officer Mwansa', 'officer.mwansa@securemove.dev', '0977100002', 'LM-CON-001'),
  conductor('Mazhandu Family Bus', 'Officer Chirwa', 'officer.chirwa@securemove.dev', '0977100003', 'MF-CON-001'),
  conductor('Shalom', 'Officer Tembo', 'officer.tembo@securemove.dev', '0977100004', 'SH-CON-001'),
  conductor('UBZ', 'Officer Zulu', 'officer.zulu@securemove.dev', '0977100005', 'UBZ-CON-001'),
];

const buses = [
  bus('Power Tools', 'BAT 1200', 52, ['Express', 'Wi-Fi', 'USB']),
  bus('Likili Motorways', 'BLM 2401', 49, ['Comfort', 'USB', 'AC']),
  bus('Mazhandu Family Bus', 'BMF 3302', 55, ['Comfort', 'Luggage', 'AC']),
  bus('Shalom', 'BSH 4403', 50, ['Popular', 'Window seats', 'AC']),
  bus('UBZ', 'BUB 5504', 48, ['Refreshments', 'USB', 'AC']),
];

const bidirectionalRoutes = [
  {
    from: 'Lusaka',
    to: 'Kabwe',
    outbound: [
      route('Power Tools', '06:30 AM', 'K1', 120, ['Express', 'Wi-Fi', 'USB']),
      route('Mazhandu Family Bus', '09:00 AM', 'K255', 130, ['AC', 'Comfort', 'Luggage']),
      route('Shalom', '02:00 PM', 'K260', 140, ['Window seats', 'Popular', 'On time']),
    ],
    inbound: [
      route('UBZ', '06:00 AM', 'K245', 125, ['Return trip', 'USB', 'Refreshments']),
      route('Power Tools', '05:30 PM', 'K240', 125, ['Express', 'Wi-Fi', 'Evening']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Livingstone',
    outbound: [
      route('Likili Motorways', '05:45 AM', 'K410', 350, ['Morning', 'Comfort', 'USB']),
      route('Shalom', '09:00 PM', 'K420', 360, ['Night coach', 'AC', 'Snacks']),
    ],
    inbound: [
      route('Mazhandu Family Bus', '06:30 AM', 'K400', 345, ['Express', 'Luggage', 'Popular']),
      route('Likili Motorways', '08:00 PM', 'K415', 355, ['Night route', 'USB', 'Comfort']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Ndola',
    outbound: [
      route('Power Tools', '07:00 AM', 'K360', 300, ['Express', 'Wi-Fi', 'USB']),
      route('UBZ', '01:30 PM', 'K375', 320, ['Refreshments', 'Comfort', 'AC']),
    ],
    inbound: [
      route('Mazhandu Family Bus', '06:00 AM', 'K365', 305, ['Popular', 'Luggage', 'Express']),
      route('Shalom', '02:30 PM', 'K370', 315, ['Window seats', 'Daily', 'AC']),
    ],
  },
  {
    from: 'Ndola',
    to: 'Kitwe',
    outbound: [
      route('Power Tools', '07:30 AM', 'K190', 70, ['Express', 'Wi-Fi', 'Daily']),
      route('UBZ', '04:30 PM', 'K210', 80, ['Evening', 'USB', 'Comfort']),
    ],
    inbound: [
      route('Shalom', '06:45 AM', 'K195', 75, ['Daily', 'AC', 'Popular']),
      route('Mazhandu Family Bus', '05:15 PM', 'K205', 82, ['Luggage', 'Comfort', 'Return trip']),
    ],
  },
  {
    from: 'Kitwe',
    to: 'Chingola',
    outbound: [
      route('UBZ', '08:15 AM', 'K150', 55, ['Copperbelt', 'USB', 'Express']),
      route('Power Tools', '03:45 PM', 'K145', 50, ['Daily', 'Wi-Fi', 'Express']),
    ],
    inbound: [
      route('Shalom', '07:20 AM', 'K150', 55, ['Daily', 'Comfort', 'AC']),
      route('Likili Motorways', '04:10 PM', 'K148', 52, ['Evening', 'USB', 'Popular']),
    ],
  },
  {
    from: 'Kitwe',
    to: 'Mufulira',
    outbound: [
      route('Mazhandu Family Bus', '07:10 AM', 'K135', 45, ['Short haul', 'Comfort', 'Daily']),
      route('UBZ', '01:00 PM', 'K140', 48, ['USB', 'AC', 'Copperbelt']),
    ],
    inbound: [
      route('Power Tools', '06:40 AM', 'K130', 44, ['Express', 'Daily', 'Wi-Fi']),
      route('Shalom', '05:00 PM', 'K138', 46, ['Popular', 'Comfort', 'Evening']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Chipata',
    outbound: [
      route('Mazhandu Family Bus', '06:00 AM', 'K430', 420, ['Eastern route', 'Luggage', 'Express']),
      route('Shalom', '09:30 PM', 'K440', 435, ['Night coach', 'AC', 'USB']),
    ],
    inbound: [
      route('Power Tools', '05:30 AM', 'K425', 415, ['Morning', 'Wi-Fi', 'Express']),
      route('Likili Motorways', '08:30 PM', 'K438', 430, ['Night route', 'Comfort', 'USB']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Kasama',
    outbound: [
      route('UBZ', '06:15 AM', 'K520', 630, ['Long distance', 'Refreshments', 'AC']),
      route('Power Tools', '07:45 PM', 'K540', 650, ['Night route', 'Wi-Fi', 'USB']),
    ],
    inbound: [
      route('Shalom', '05:45 AM', 'K525', 635, ['Morning', 'Popular', 'Comfort']),
      route('Mazhandu Family Bus', '08:00 PM', 'K545', 655, ['Night coach', 'Luggage', 'AC']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Solwezi',
    outbound: [
      route('Likili Motorways', '05:15 AM', 'K560', 700, ['North-western', 'Comfort', 'USB']),
      route('UBZ', '07:30 PM', 'K575', 720, ['Night route', 'Refreshments', 'AC']),
    ],
    inbound: [
      route('Power Tools', '06:00 AM', 'K555', 695, ['Express', 'Wi-Fi', 'Long distance']),
      route('Shalom', '08:15 PM', 'K570', 715, ['Night coach', 'Popular', 'Comfort']),
    ],
  },
  {
    from: 'Lusaka',
    to: 'Mongu',
    outbound: [
      route('UBZ', '06:45 AM', 'K480', 500, ['Western route', 'AC', 'USB']),
      route('Likili Motorways', '08:30 PM', 'K495', 520, ['Night route', 'Comfort', 'Snacks']),
    ],
    inbound: [
      route('Power Tools', '05:50 AM', 'K475', 495, ['Morning', 'Express', 'Wi-Fi']),
      route('Mazhandu Family Bus', '07:45 PM', 'K490', 515, ['Luggage', 'Comfort', 'Night coach']),
    ],
  },
  {
    from: 'Kabwe',
    to: 'Ndola',
    outbound: [
      route('Shalom', '07:00 AM', 'K270', 185, ['Central corridor', 'Popular', 'Express']),
      route('UBZ', '02:30 PM', 'K285', 195, ['AC', 'USB', 'Evening']),
    ],
    inbound: [
      route('Power Tools', '06:20 AM', 'K268', 182, ['Express', 'Wi-Fi', 'Daily']),
      route('Likili Motorways', '03:10 PM', 'K282', 192, ['Comfort', 'USB', 'Daily']),
    ],
  },
  {
    from: 'Chipata',
    to: 'Katete',
    outbound: [
      route('Mazhandu Family Bus', '08:00 AM', 'K120', 60, ['Eastern route', 'Daily', 'Comfort']),
      route('Shalom', '04:00 PM', 'K125', 65, ['Evening', 'Popular', 'AC']),
    ],
    inbound: [
      route('Power Tools', '07:15 AM', 'K118', 58, ['Express', 'Daily', 'Wi-Fi']),
      route('UBZ', '05:00 PM', 'K122', 62, ['USB', 'Comfort', 'Return trip']),
    ],
  },
];

async function initDb() {
  await runMigrations();
  await seedBaseData();
}

async function runMigrations() {
  const migrationsDir = path.join(__dirname, '..', 'migrations');
  const files = fs.readdirSync(migrationsDir).filter((file) => file.endsWith('.sql')).sort();

  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
    if (sql.trim()) {
      await pool.query(sql);
    }
  }
}

async function seedBaseData() {
  const valuesClause = companies.map((_, index) => `($${index + 1})`).join(', ');
  await pool.query(
    `INSERT INTO companies (name)
     VALUES ${valuesClause}
     ON CONFLICT (name) DO NOTHING;`,
    companies
  );

  const companyResult = await pool.query('SELECT company_id, name FROM companies ORDER BY company_id ASC');
  const companyIds = Object.fromEntries(companyResult.rows.map((row) => [row.name, row.company_id]));

  await seedDemoUsers(companyIds);

  for (const item of drivers) {
    await upsertDriver(companyIds, item);
  }

  for (const item of conductors) {
    await upsertConductor(companyIds, item);
  }

  for (const item of buses) {
    await upsertBus(companyIds, item);
  }

  const driverMap = await buildDriverMap(companyIds);
  const conductorMap = await buildConductorMap(companyIds);
  const busMap = await buildBusMap(companyIds);

  for (const corridor of bidirectionalRoutes) {
    for (const schedule of corridor.outbound) {
      await insertSchedule(companyIds, driverMap, conductorMap, busMap, {
        ...schedule,
        origin: corridor.from,
        destination: corridor.to,
      });
    }

    for (const schedule of corridor.inbound) {
      await insertSchedule(companyIds, driverMap, conductorMap, busMap, {
        ...schedule,
        origin: corridor.to,
        destination: corridor.from,
      });
    }
  }
}

function route(companyName, departureTime, price, durationMinutes, features) {
  return { companyName, departureTime, price, durationMinutes, features };
}

function user(name, email, roleId, companyName = null) {
  return { name, email, roleId, companyName };
}

function driver(companyName, fullName, email, phoneNumber, licenseNumber) {
  return { companyName, fullName, email, phoneNumber, licenseNumber };
}

function conductor(companyName, fullName, email, phoneNumber, badgeNumber) {
  return { companyName, fullName, email, phoneNumber, badgeNumber };
}

function bus(companyName, registrationNumber, capacity, features) {
  return { companyName, registrationNumber, capacity, features };
}

async function seedDemoUsers(companyIds) {
  const passwordHash = await bcrypt.hash(demoPassword, 10);

  for (const item of demoUsers) {
    const companyId = item.companyName ? companyIds[item.companyName] : null;

    await pool.query(
      `INSERT INTO users (name, email, password_hash, role_id, company_id)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (email) DO UPDATE
       SET name = EXCLUDED.name,
           password_hash = EXCLUDED.password_hash,
           role_id = EXCLUDED.role_id,
           company_id = EXCLUDED.company_id`,
      [item.name, item.email, passwordHash, item.roleId, companyId]
    );
  }
}

async function upsertDriver(companyIds, item) {
  const companyId = companyIds[item.companyName];
  if (!companyId) {
    throw new Error(`Company not found for driver seed: ${item.companyName}`);
  }

  await pool.query(
    `INSERT INTO drivers (company_id, full_name, email, phone_number, license_number)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (license_number) DO UPDATE
     SET full_name = EXCLUDED.full_name,
         email = EXCLUDED.email,
         phone_number = EXCLUDED.phone_number,
         company_id = EXCLUDED.company_id,
         is_active = TRUE`,
    [companyId, item.fullName, item.email, item.phoneNumber, item.licenseNumber]
  );
}

async function upsertConductor(companyIds, item) {
  const companyId = companyIds[item.companyName];
  if (!companyId) {
    throw new Error(`Company not found for conductor seed: ${item.companyName}`);
  }

  await pool.query(
    `INSERT INTO conductors (company_id, full_name, email, phone_number, badge_number)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (badge_number) DO UPDATE
     SET full_name = EXCLUDED.full_name,
         email = EXCLUDED.email,
         phone_number = EXCLUDED.phone_number,
         company_id = EXCLUDED.company_id,
         is_active = TRUE`,
    [companyId, item.fullName, item.email, item.phoneNumber, item.badgeNumber]
  );
}

async function upsertBus(companyIds, item) {
  const companyId = companyIds[item.companyName];
  if (!companyId) {
    throw new Error(`Company not found for bus seed: ${item.companyName}`);
  }

  await pool.query(
    `INSERT INTO buses (company_id, registration_number, capacity, features)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (registration_number) DO UPDATE
     SET company_id = EXCLUDED.company_id,
         capacity = EXCLUDED.capacity,
         features = EXCLUDED.features,
         is_active = TRUE`,
    [companyId, item.registrationNumber, item.capacity, item.features]
  );
}

async function buildDriverMap(companyIds) {
  const entries = await Promise.all(
    Object.entries(companyIds).map(async ([companyName, companyId]) => {
      const result = await pool.query(
        `SELECT driver_id
         FROM drivers
         WHERE company_id = $1 AND is_active = TRUE
         ORDER BY driver_id ASC
         LIMIT 1`,
        [companyId]
      );

      return [companyName, result.rows[0]?.driver_id ?? null];
    })
  );

  return Object.fromEntries(entries);
}

async function buildConductorMap(companyIds) {
  const entries = await Promise.all(
    Object.entries(companyIds).map(async ([companyName, companyId]) => {
      const result = await pool.query(
        `SELECT conductor_id
         FROM conductors
         WHERE company_id = $1 AND is_active = TRUE
         ORDER BY conductor_id ASC
         LIMIT 1`,
        [companyId]
      );

      return [companyName, result.rows[0]?.conductor_id ?? null];
    })
  );

  return Object.fromEntries(entries);
}

async function buildBusMap(companyIds) {
  const entries = await Promise.all(
    Object.entries(companyIds).map(async ([companyName, companyId]) => {
      const result = await pool.query(
        `SELECT bus_id, capacity
         FROM buses
         WHERE company_id = $1 AND is_active = TRUE
         ORDER BY bus_id ASC
         LIMIT 1`,
        [companyId]
      );

      return [companyName, result.rows[0] ?? null];
    })
  );

  return Object.fromEntries(entries);
}

async function insertSchedule(companyIds, driverMap, conductorMap, busMap, schedule) {
  const companyId = companyIds[schedule.companyName];
  if (!companyId) {
    throw new Error(`Company not found for route seed: ${schedule.companyName}`);
  }

  const scheduleResult = await pool.query(
    `INSERT INTO route_schedules (
      company_id,
      origin,
      destination,
      departure_time,
      price,
      duration_minutes,
      features
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (company_id, origin, destination, departure_time)
    DO UPDATE SET
      price = EXCLUDED.price,
      duration_minutes = EXCLUDED.duration_minutes,
      features = EXCLUDED.features,
      active = TRUE
    RETURNING schedule_id`,
    [
      companyId,
      schedule.origin,
      schedule.destination,
      schedule.departureTime,
      schedule.price,
      schedule.durationMinutes,
      schedule.features,
    ]
  );

  const scheduleId = scheduleResult.rows[0].schedule_id;
  const driverId = driverMap[schedule.companyName];
  const conductorId = conductorMap[schedule.companyName];
  const busData = busMap[schedule.companyName];

  if (!driverId || !conductorId || !busData?.bus_id) {
    return;
  }

  const departureAt = buildDepartureDate(schedule.departureTime);
  const arrivalAt = new Date(departureAt.getTime() + schedule.durationMinutes * 60 * 1000);

  await pool.query(
    `INSERT INTO trips (
      schedule_id,
      bus_id,
      driver_id,
      conductor_id,
      departure_time,
      arrival_time,
      available_seats,
      status
    )
    SELECT $1, $2, $3, $4, $5, $6, $7, 'scheduled'
    WHERE NOT EXISTS (
      SELECT 1
      FROM trips
      WHERE schedule_id = $1
        AND bus_id = $2
        AND driver_id = $3
        AND conductor_id = $4
        AND departure_time = $5
    )`,
    [
      scheduleId,
      busData.bus_id,
      driverId,
      conductorId,
      departureAt.toISOString(),
      arrivalAt.toISOString(),
      busData.capacity,
    ]
  );
}

function buildDepartureDate(timeLabel) {
  const now = new Date();
  const target = new Date(now);
  target.setHours(0, 0, 0, 0);

  const [timePart, meridiem] = timeLabel.split(' ');
  const [hourLabel, minuteLabel] = timePart.split(':');
  let hour = Number.parseInt(hourLabel, 10);
  const minute = Number.parseInt(minuteLabel, 10);

  if (meridiem === 'PM' && hour !== 12) {
    hour += 12;
  }
  if (meridiem === 'AM' && hour === 12) {
    hour = 0;
  }

  target.setHours(hour, minute, 0, 0);
  return target;
}

initDb()
  .then(async () => {
    console.log('Database initialized successfully.');
    await pool.end();
  })
  .catch(async (error) => {
    console.error('Database initialization failed:', error);
    await pool.end();
    process.exit(1);
  });

