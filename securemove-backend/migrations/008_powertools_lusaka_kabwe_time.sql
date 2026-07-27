WITH target_schedule AS (
  UPDATE route_schedules rs
  SET departure_time = '06:00 AM'
  FROM companies c
  WHERE c.company_id = rs.company_id
    AND c.name = 'Power Tools'
    AND LOWER(rs.origin) = LOWER('Lusaka')
    AND LOWER(rs.destination) = LOWER('Kabwe')
    AND rs.price = 'K1'
  RETURNING rs.schedule_id
)
UPDATE trips tr
SET departure_time = (tr.departure_time::date + TIME '06:00')::timestamptz,
    arrival_time = (tr.departure_time::date + TIME '08:00')::timestamptz
FROM target_schedule ts
WHERE tr.schedule_id = ts.schedule_id
  AND tr.status IN ('scheduled', 'boarding', 'BOARDING');
