const bcrypt = require('bcrypt');
const pool = require('../db');

const PASSWORD = 'SecureMove2024!';

const drivers = [
  ['benson.phiri@securemove.dev', 'Power Tools'],
  ['ruth.mwila@securemove.dev', 'Likili Motorways'],
  ['peter.banda@securemove.dev', 'Mazhandu Family Bus'],
  ['grace.tembo@securemove.dev', 'Shalom'],
  ['daniel.zulu@securemove.dev', 'UBZ'],
];

const conductors = [
  ['Power Tools', 'Officer Banda', 'officer.banda@securemove.dev', '0977100001', 'PT-CON-001'],
  ['Likili Motorways', 'Officer Mwansa', 'officer.mwansa@securemove.dev', '0977100002', 'LM-CON-001'],
  ['Mazhandu Family Bus', 'Officer Chirwa', 'officer.chirwa@securemove.dev', '0977100003', 'MF-CON-001'],
  ['Shalom', 'Officer Tembo', 'officer.tembo@securemove.dev', '0977100004', 'SH-CON-001'],
  ['UBZ', 'Officer Zulu', 'officer.zulu@securemove.dev', '0977100005', 'UBZ-CON-001'],
];

async function main() {
  const passwordHash = await bcrypt.hash(PASSWORD, 10);

  await pool.query(
    `INSERT INTO roles (role_id, role_name)
     VALUES (4, 'driver'), (5, 'conductor')
     ON CONFLICT (role_id) DO UPDATE
     SET role_name = EXCLUDED.role_name`
  );

  for (const [email] of drivers) {
    await pool.query(
      `UPDATE users
       SET role_id = 4
       WHERE LOWER(email) = LOWER($1)`,
      [email]
    );
  }

  for (const [companyName, fullName, email, phone, badge] of conductors) {
    const company = await pool.query(
      'SELECT company_id FROM companies WHERE name = $1',
      [companyName]
    );
    const companyId = company.rows[0]?.company_id;
    if (!companyId) continue;

    const conductor = await pool.query(
      `INSERT INTO conductors (company_id, full_name, email, phone_number, badge_number)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (badge_number) DO UPDATE
       SET company_id = EXCLUDED.company_id,
           full_name = EXCLUDED.full_name,
           email = EXCLUDED.email,
           phone_number = EXCLUDED.phone_number,
           is_active = TRUE
       RETURNING conductor_id`,
      [companyId, fullName, email, phone, badge]
    );

    await pool.query(
      `INSERT INTO users (name, email, password_hash, role_id, company_id)
       VALUES ($1, $2, $3, 5, $4)
       ON CONFLICT (email) DO UPDATE
       SET name = EXCLUDED.name,
           password_hash = EXCLUDED.password_hash,
           role_id = 5,
           company_id = EXCLUDED.company_id`,
      [fullName, email, passwordHash, companyId]
    );

    await pool.query(
      `UPDATE trips tr
       SET conductor_id = $1
       FROM route_schedules rs
       WHERE rs.schedule_id = tr.schedule_id
         AND rs.company_id = $2
         AND tr.status IN ('scheduled', 'boarding', 'BOARDING', 'DEPARTED')`,
      [conductor.rows[0].conductor_id, companyId]
    );
  }

  await pool.query(
    `UPDATE conductors
     SET is_active = FALSE
     WHERE badge_number LIKE 'LEGACY-CON-%'`
  );

  console.log('Driver and conductor accounts are now split.');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
