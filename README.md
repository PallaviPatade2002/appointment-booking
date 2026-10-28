# Glow Studio: Appointment Booking

Online appointment booking for salons, clinics, gyms and classes. One Node/Express + SQLite API, a React website (customers and owner) and a Flutter mobile app (customers).

## Features

- **Customer (website + app):** sign up / login, pick a service, pick a day (next 21 days), pick from live free time slots, add a note, see and cancel bookings
- **Owner (website):** day-wise appointment list (complete / no-show / cancel), add and hide services, weekly working hours, holidays, monthly report (bookings, cancellations, no-shows, income)
- **Rules enforced on the server:** no double booking (overlapping slots are refused), no past times, closed days and holidays have no slots, customers can only cancel their own upcoming bookings

## Run

```bash
cd backend
npm install
npm run seed     # demo users + services (password 123456)
npm start        # http://localhost:5001

cd frontend
npm install
npm run dev      # http://localhost:5174 (proxies /api to :5001)

cd mobile
flutter pub get
flutter run                                   # Android emulator talks to 10.0.2.2:5001
flutter run -d chrome                         # web build talks to localhost:5001
flutter run --dart-define=API_URL=https://your-server.com   # a deployed API
```

Demo logins (password `123456`): customer `9000000003`, owner `9000000001`.

Set `JWT_SECRET` in production. Tests: `cd backend && npm test`, `cd mobile && flutter test`.

## Build for production

`cd frontend && npm run build`: the backend then serves the website from the same server as the API.
Android APK: `cd mobile && flutter build apk --dart-define=API_URL=https://your-server.com`.

## API

| Method | Path | Who |
| --- | --- | --- |
| POST | `/api/auth/register`, `/api/auth/login` | public |
| GET | `/api/services` | public |
| GET | `/api/slots?date=YYYY-MM-DD&service_id=` | public |
| POST | `/api/bookings` | customer |
| GET | `/api/bookings/mine` | customer |
| PATCH | `/api/bookings/:id/cancel` | customer |
| GET/PATCH | `/api/admin/bookings`, `/api/admin/bookings/:id` | owner |
| GET/PUT | `/api/admin/hours`, `/api/admin/hours/:dow` | owner |
| GET/POST/DELETE | `/api/admin/holidays` | owner |
| GET | `/api/admin/report?month=YYYY-MM` | owner |
| POST/PUT | `/api/services`, `/api/services/:id` | owner |
