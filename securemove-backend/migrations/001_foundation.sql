CREATE TABLE IF NOT EXISTS users (
  user_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role_id INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS companies (
  company_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  audit_log_id SERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  status TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info',
  email TEXT,
  user_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
  ip_address TEXT,
  user_agent TEXT,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_email_created_at
  ON audit_logs (email, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id_created_at
  ON audit_logs (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS route_schedules (
  schedule_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_time TEXT NOT NULL,
  price TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  features TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, origin, destination, departure_time)
);

CREATE INDEX IF NOT EXISTS idx_route_schedules_search
  ON route_schedules (LOWER(origin), LOWER(destination), active);

CREATE TABLE IF NOT EXISTS drivers (
  driver_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone_number TEXT,
  license_number TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_drivers_company_active
  ON drivers (company_id, is_active);

CREATE TABLE IF NOT EXISTS buses (
  bus_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  registration_number TEXT NOT NULL UNIQUE,
  capacity INTEGER NOT NULL CHECK (capacity > 0),
  features TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_buses_company_active
  ON buses (company_id, is_active);

CREATE TABLE IF NOT EXISTS trips (
  trip_id SERIAL PRIMARY KEY,
  schedule_id INTEGER REFERENCES route_schedules(schedule_id) ON DELETE SET NULL,
  bus_id INTEGER REFERENCES buses(bus_id) ON DELETE SET NULL,
  driver_id INTEGER REFERENCES drivers(driver_id) ON DELETE SET NULL,
  departure_time TIMESTAMPTZ NOT NULL,
  arrival_time TIMESTAMPTZ,
  available_seats INTEGER,
  status TEXT NOT NULL DEFAULT 'scheduled',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trips_schedule_departure
  ON trips (schedule_id, departure_time DESC);

CREATE INDEX IF NOT EXISTS idx_trips_driver_status
  ON trips (driver_id, status);

CREATE TABLE IF NOT EXISTS bookings (
  booking_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  trip_id INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
  booking_reference TEXT NOT NULL UNIQUE,
  total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
  status TEXT NOT NULL DEFAULT 'reserved',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_user_created
  ON bookings (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_trip_status
  ON bookings (trip_id, status);

CREATE TABLE IF NOT EXISTS tickets (
  ticket_id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  passenger_name TEXT NOT NULL,
  seat_number TEXT NOT NULL,
  ticket_number TEXT NOT NULL UNIQUE,
  qr_code_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  verified_at TIMESTAMPTZ,
  verified_by_driver_id INTEGER REFERENCES drivers(driver_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (booking_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_tickets_booking_status
  ON tickets (booking_id, status);

CREATE TABLE IF NOT EXISTS payments (
  payment_id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
  payment_method TEXT NOT NULL,
  provider TEXT,
  phone_number TEXT,
  transaction_reference TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_booking_status
  ON payments (booking_id, status);
