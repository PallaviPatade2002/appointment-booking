const bcrypt = require('bcryptjs');
const db = require('./db');

const addUser = (name, phone, role) =>
  db.prepare('INSERT OR IGNORE INTO users (name, phone, password_hash, role) VALUES (?,?,?,?)')
    .run(name, phone, bcrypt.hashSync('123456', 10), role);

addUser('Owner', '9000000001', 'admin');
addUser('Demo Customer', '9000000003', 'customer');

if (!db.prepare('SELECT COUNT(*) c FROM services').get().c) {
  const ins = db.prepare('INSERT INTO services (name, description, duration_min, price) VALUES (?,?,?,?)');
  ins.run('Haircut', 'Wash, cut and style', 30, 200);
  ins.run('Beard Trim', 'Shape and trim', 15, 100);
  ins.run('Facial', 'Deep cleansing facial', 60, 600);
  ins.run('Hair Colour', 'Full colour with wash', 90, 1200);
}
console.log('Seeded. Logins (password 123456): admin 9000000001, customer 9000000003');
