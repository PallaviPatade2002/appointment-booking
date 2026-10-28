process.env.DB_FILE = ':memory:';
const test = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const app = require('../src/app');
const db = require('../src/db');

let server, base;
test.before(
  () =>
    new Promise((resolve) => {
      server = app.listen(0, () => {
        base = 'http://localhost:' + server.address().port;
        resolve();
      });
    })
);
test.after(() => server.close());

const call = async (method, path, body, token) => {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: 'Bearer ' + token }) },
    body: body && JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
};

// a Monday far in the future (business is open Mon-Sat by default)
const MONDAY = '2099-01-05';
const SUNDAY = '2099-01-04';

test('booking flow, double-booking and admin controls', async () => {
  db.prepare("INSERT INTO users (name, phone, password_hash, role) VALUES ('Owner','1',?,'admin')").run(
    bcrypt.hashSync('secret1', 4)
  );
  const adm = (await call('POST', '/api/auth/login', { phone: '1', password: 'secret1' })).body.token;

  const svc = await call('POST', '/api/services', { name: 'Haircut', duration_min: 30, price: 200 }, adm);
  assert.equal(svc.status, 201);
  const sid = svc.body.id;

  const a = (await call('POST', '/api/auth/register', { name: 'A', phone: '2', password: 'abcdef' })).body.token;
  const b = (await call('POST', '/api/auth/register', { name: 'B', phone: '3', password: 'abcdef' })).body.token;

  // customers cannot manage services
  assert.equal((await call('POST', '/api/services', { name: 'x', duration_min: 10, price: 1 }, a)).status, 403);

  const slots = (await call('GET', `/api/slots?date=${MONDAY}&service_id=${sid}`)).body.slots;
  assert.equal(slots[0], '09:00');
  assert.equal(slots.at(-1), '17:30');

  const first = await call('POST', '/api/bookings', { service_id: sid, date: MONDAY, time: '10:00' }, a);
  assert.equal(first.status, 201);

  // same slot and overlapping slots are refused, adjacent ones are fine
  assert.equal((await call('POST', '/api/bookings', { service_id: sid, date: MONDAY, time: '10:00' }, b)).status, 409);
  assert.equal((await call('POST', '/api/bookings', { service_id: sid, date: MONDAY, time: '10:15' }, b)).status, 409);
  assert.equal((await call('POST', '/api/bookings', { service_id: sid, date: MONDAY, time: '10:30' }, b)).status, 201);

  // cancelling frees the slot
  assert.equal((await call('PATCH', `/api/bookings/${first.body.id}/cancel`, null, a)).status, 200);
  assert.equal((await call('POST', '/api/bookings', { service_id: sid, date: MONDAY, time: '10:00' }, b)).status, 201);

  // a customer cannot cancel someone else's booking
  const mine = (await call('GET', '/api/bookings/mine', null, b)).body;
  assert.equal(mine.length, 2);
  assert.equal((await call('PATCH', `/api/bookings/${mine[0].id}/cancel`, null, a)).status, 404);

  // closed day has no slots; past dates are refused
  assert.deepEqual((await call('GET', `/api/slots?date=${SUNDAY}&service_id=${sid}`)).body.slots, []);
  assert.equal((await call('POST', '/api/bookings', { service_id: sid, date: '2020-01-06', time: '10:00' }, a)).status, 409);

  // admin sees bookings and can complete one; report counts income
  const all = (await call('GET', `/api/admin/bookings?date=${MONDAY}`, null, adm)).body;
  assert.equal(all.filter((x) => x.status === 'booked').length, 2);
  const active = all.find((x) => x.status === 'booked');
  assert.equal((await call('PATCH', `/api/admin/bookings/${active.id}`, { status: 'completed' }, adm)).status, 200);
  const rep = (await call('GET', '/api/admin/report?month=2099-01', null, adm)).body;
  assert.equal(rep.completed, 1);
  assert.equal(rep.income, 200);
  assert.equal(rep.cancelled, 1);

  // holiday empties the day
  await call('POST', '/api/admin/holidays', { date: MONDAY, reason: 'Festival' }, adm);
  assert.deepEqual((await call('GET', `/api/slots?date=${MONDAY}&service_id=${sid}`)).body.slots, []);
});
