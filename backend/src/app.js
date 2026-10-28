const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const db = require('./db');
const { sign, requireAuth } = require('./auth');

const app = express();
app.use(cors());
app.use(express.json());

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const STATUSES = ['booked', 'completed', 'cancelled', 'no_show'];
const SLOT_STEP = 15; // minutes between possible start times

const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3));
const toTime = (m) => String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
const isDate = (d) => DATE_RE.test(d || '') && !Number.isNaN(Date.parse(d + 'T00:00:00Z'));
const dow = (d) => new Date(d + 'T00:00:00Z').getUTCDay();
const pad = (n) => String(n).padStart(2, '0');
const todayStr = () => {
  const n = new Date();
  return `${n.getFullYear()}-${pad(n.getMonth() + 1)}-${pad(n.getDate())}`;
};
const nowMin = () => {
  const n = new Date();
  return n.getHours() * 60 + n.getMinutes();
};

// Free start times for a service on a date. Past times and clashes with other bookings are excluded.
function freeSlots(date, service) {
  if (db.prepare('SELECT 1 FROM holidays WHERE date = ?').get(date)) return [];
  const h = db.prepare('SELECT open_min, close_min FROM business_hours WHERE dow = ?').get(dow(date));
  if (!h || h.open_min == null) return [];
  const busy = db
    .prepare("SELECT start_min, end_min FROM bookings WHERE date = ? AND status != 'cancelled'")
    .all(date);
  const out = [];
  for (let s = h.open_min; s + service.duration_min <= h.close_min; s += SLOT_STEP) {
    const e = s + service.duration_min;
    if (date < todayStr() || (date === todayStr() && s <= nowMin())) continue;
    if (busy.some((b) => s < b.end_min && e > b.start_min)) continue;
    out.push(toTime(s));
  }
  return out;
}

const view = (b) => ({ ...b, start: toTime(b.start_min), end: toTime(b.end_min) });

// ---------- Auth ----------
app.post('/api/auth/register', (req, res) => {
  const { name, phone, password } = req.body;
  if (!name || !phone || !password || password.length < 6) {
    return res.status(400).json({ error: 'name, phone and password (min 6 chars) required' });
  }
  if (db.prepare('SELECT id FROM users WHERE phone = ?').get(phone)) {
    return res.status(409).json({ error: 'Phone already registered' });
  }
  const r = db
    .prepare('INSERT INTO users (name, phone, password_hash) VALUES (?,?,?)')
    .run(name, phone, bcrypt.hashSync(password, 10));
  const user = { id: Number(r.lastInsertRowid), role: 'customer' };
  res.status(201).json({ token: sign(user), user: { ...user, name, phone } });
});

app.post('/api/auth/login', (req, res) => {
  const { phone, password } = req.body;
  const u = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
  if (!u || !bcrypt.compareSync(password || '', u.password_hash)) {
    return res.status(401).json({ error: 'Wrong phone or password' });
  }
  res.json({ token: sign(u), user: { id: u.id, name: u.name, phone: u.phone, role: u.role } });
});

// ---------- Services ----------
app.get('/api/services', (req, res) => {
  res.json(db.prepare('SELECT * FROM services WHERE active = 1 ORDER BY name').all());
});

app.get('/api/services/all', requireAuth('admin'), (req, res) => {
  res.json(db.prepare('SELECT * FROM services ORDER BY name').all());
});

app.post('/api/services', requireAuth('admin'), (req, res) => {
  const { name, description, duration_min, price } = req.body;
  if (!name || !(duration_min > 0) || !(price >= 0)) {
    return res.status(400).json({ error: 'name, duration_min (>0) and price required' });
  }
  const r = db
    .prepare('INSERT INTO services (name, description, duration_min, price) VALUES (?,?,?,?)')
    .run(name, description || null, Math.round(duration_min), price);
  res.status(201).json({ id: Number(r.lastInsertRowid) });
});

app.put('/api/services/:id', requireAuth('admin'), (req, res) => {
  const cur = db.prepare('SELECT * FROM services WHERE id = ?').get(req.params.id);
  if (!cur) return res.status(404).json({ error: 'Service not found' });
  const n = { ...cur, ...req.body };
  if (!n.name || !(n.duration_min > 0) || !(n.price >= 0)) return res.status(400).json({ error: 'Invalid values' });
  db.prepare('UPDATE services SET name=?, description=?, duration_min=?, price=?, active=? WHERE id=?').run(
    n.name, n.description || null, Math.round(n.duration_min), n.price, n.active ? 1 : 0, cur.id
  );
  res.json({ ok: true });
});

// ---------- Slots ----------
app.get('/api/slots', (req, res) => {
  const { date, service_id } = req.query;
  if (!isDate(date)) return res.status(400).json({ error: 'date must be YYYY-MM-DD' });
  const svc = db.prepare('SELECT * FROM services WHERE id = ? AND active = 1').get(service_id);
  if (!svc) return res.status(404).json({ error: 'Service not found' });
  res.json({ date, slots: freeSlots(date, svc) });
});

// ---------- Bookings (customer) ----------
app.post('/api/bookings', requireAuth('customer'), (req, res) => {
  const { service_id, date, time, note } = req.body;
  if (!isDate(date) || !TIME_RE.test(time || '')) {
    return res.status(400).json({ error: 'date (YYYY-MM-DD) and time (HH:MM) required' });
  }
  const svc = db.prepare('SELECT * FROM services WHERE id = ? AND active = 1').get(service_id);
  if (!svc) return res.status(404).json({ error: 'Service not found' });
  // node:sqlite is synchronous, so the check and insert below cannot interleave with another request
  if (!freeSlots(date, svc).includes(time)) {
    return res.status(409).json({ error: 'That time is not available. Please pick another slot.' });
  }
  const start = toMin(time);
  const r = db
    .prepare('INSERT INTO bookings (user_id, service_id, date, start_min, end_min, note) VALUES (?,?,?,?,?,?)')
    .run(req.user.id, svc.id, date, start, start + svc.duration_min, note || null);
  res.status(201).json({ id: Number(r.lastInsertRowid) });
});

app.get('/api/bookings/mine', requireAuth('customer'), (req, res) => {
  const rows = db
    .prepare(
      `SELECT b.*, s.name AS service_name, s.price FROM bookings b JOIN services s ON s.id = b.service_id
       WHERE b.user_id = ? ORDER BY b.date DESC, b.start_min DESC`
    )
    .all(req.user.id);
  res.json(rows.map(view));
});

app.patch('/api/bookings/:id/cancel', requireAuth('customer'), (req, res) => {
  const b = db.prepare('SELECT * FROM bookings WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!b) return res.status(404).json({ error: 'Booking not found' });
  if (b.status !== 'booked') return res.status(409).json({ error: 'Only upcoming bookings can be cancelled' });
  db.prepare("UPDATE bookings SET status = 'cancelled' WHERE id = ?").run(b.id);
  res.json({ ok: true });
});

// ---------- Admin ----------
app.get('/api/admin/bookings', requireAuth('admin'), (req, res) => {
  const { date } = req.query;
  if (date && !isDate(date)) return res.status(400).json({ error: 'date must be YYYY-MM-DD' });
  const rows = db
    .prepare(
      `SELECT b.*, s.name AS service_name, s.price, u.name AS customer_name, u.phone AS customer_phone
       FROM bookings b JOIN services s ON s.id = b.service_id JOIN users u ON u.id = b.user_id
       ${date ? 'WHERE b.date = ?' : ''} ORDER BY b.date, b.start_min`
    )
    .all(...(date ? [date] : []));
  res.json(rows.map(view));
});

app.patch('/api/admin/bookings/:id', requireAuth('admin'), (req, res) => {
  const { status } = req.body;
  if (!STATUSES.includes(status)) return res.status(400).json({ error: 'Invalid status' });
  const r = db.prepare('UPDATE bookings SET status = ? WHERE id = ?').run(status, req.params.id);
  if (!r.changes) return res.status(404).json({ error: 'Booking not found' });
  res.json({ ok: true });
});

app.get('/api/admin/hours', requireAuth('admin'), (req, res) => {
  const rows = db.prepare('SELECT * FROM business_hours ORDER BY dow').all();
  res.json(
    rows.map((r) => ({
      dow: r.dow,
      open: r.open_min == null ? null : toTime(r.open_min),
      close: r.close_min == null ? null : toTime(r.close_min),
    }))
  );
});

app.put('/api/admin/hours/:dow', requireAuth('admin'), (req, res) => {
  const d = Number(req.params.dow);
  const { open, close } = req.body;
  if (!Number.isInteger(d) || d < 0 || d > 6) return res.status(400).json({ error: 'dow must be 0-6' });
  if (open == null && close == null) {
    db.prepare('UPDATE business_hours SET open_min = NULL, close_min = NULL WHERE dow = ?').run(d);
    return res.json({ ok: true });
  }
  if (!TIME_RE.test(open || '') || !TIME_RE.test(close || '') || toMin(open) >= toMin(close)) {
    return res.status(400).json({ error: 'open and close (HH:MM) required, open before close' });
  }
  db.prepare('UPDATE business_hours SET open_min = ?, close_min = ? WHERE dow = ?').run(toMin(open), toMin(close), d);
  res.json({ ok: true });
});

app.get('/api/admin/holidays', requireAuth('admin'), (req, res) => {
  res.json(db.prepare('SELECT * FROM holidays ORDER BY date').all());
});

app.post('/api/admin/holidays', requireAuth('admin'), (req, res) => {
  const { date, reason } = req.body;
  if (!isDate(date)) return res.status(400).json({ error: 'date must be YYYY-MM-DD' });
  db.prepare('INSERT OR REPLACE INTO holidays (date, reason) VALUES (?,?)').run(date, reason || null);
  res.status(201).json({ ok: true });
});

app.delete('/api/admin/holidays/:date', requireAuth('admin'), (req, res) => {
  db.prepare('DELETE FROM holidays WHERE date = ?').run(req.params.date);
  res.json({ ok: true });
});

app.get('/api/admin/report', requireAuth('admin'), (req, res) => {
  const month = req.query.month || todayStr().slice(0, 7);
  const like = month + '%';
  const count = (status) =>
    db.prepare('SELECT COUNT(*) c FROM bookings WHERE date LIKE ? AND status = ?').get(like, status).c;
  res.json({
    month,
    bookings: db.prepare("SELECT COUNT(*) c FROM bookings WHERE date LIKE ? AND status != 'cancelled'").get(like).c,
    completed: count('completed'),
    cancelled: count('cancelled'),
    no_show: count('no_show'),
    income: db
      .prepare(
        "SELECT COALESCE(SUM(s.price),0) s FROM bookings b JOIN services s ON s.id = b.service_id WHERE b.date LIKE ? AND b.status = 'completed'"
      )
      .get(like).s,
  });
});

// Serve the built frontend (single-server deploy)
const dist = path.join(__dirname, '..', '..', 'frontend', 'dist');
if (fs.existsSync(dist)) {
  app.use(express.static(dist));
  app.use((req, res, next) =>
    req.method === 'GET' && !req.path.startsWith('/api') ? res.sendFile(path.join(dist, 'index.html')) : next()
  );
}

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Server error' });
});

module.exports = app;
