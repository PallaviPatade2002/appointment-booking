CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','admin')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  duration_min INTEGER NOT NULL CHECK (duration_min > 0),
  price REAL NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1
);

-- dow: 0 = Sunday ... 6 = Saturday. Minutes since midnight. open_min NULL = closed that day.
CREATE TABLE IF NOT EXISTS business_hours (
  dow INTEGER PRIMARY KEY CHECK (dow BETWEEN 0 AND 6),
  open_min INTEGER,
  close_min INTEGER
);

CREATE TABLE IF NOT EXISTS holidays (
  date TEXT PRIMARY KEY,
  reason TEXT
);

CREATE TABLE IF NOT EXISTS bookings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  service_id INTEGER NOT NULL REFERENCES services(id),
  date TEXT NOT NULL,
  start_min INTEGER NOT NULL,
  end_min INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'booked' CHECK (status IN ('booked','completed','cancelled','no_show')),
  note TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(date);
