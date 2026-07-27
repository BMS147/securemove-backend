UPDATE route_schedules rs
SET price = 'K1'
FROM companies c
WHERE c.company_id = rs.company_id
  AND c.name = 'Likili Motorways'
  AND LOWER(rs.origin) = LOWER('Lusaka')
  AND LOWER(rs.destination) = LOWER('Solwezi')
  AND rs.departure_time = '05:15 AM';
