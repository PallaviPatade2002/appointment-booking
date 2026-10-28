const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');

const db = new DatabaseSync(process.env.DB_FILE || path.join(__dirname, '..', 'booking.db'));
db.exec('PRAGMA foreign_keys = ON');
db.exec(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));

// default hours: Mon-Sat 09:00-18:00, Sunday closed
if (!db.prepare('SELECT COUNT(*) c FROM business_hours').get().c) {
  const ins = db.prepare('INSERT INTO business_hours (dow, open_min, close_min) VALUES (?,?,?)');
  for (let d = 0; d < 7; d++) d === 0 ? ins.run(d, null, null) : ins.run(d, 9 * 60, 18 * 60);
}

module.exports = db;
