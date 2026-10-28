import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { Badge, Toast, TopBar, dur, iso, money, nice, parseDate, time12 } from '../ui'

const nextDays = (n) => Array.from({ length: n }, (_, i) => {
  const d = new Date()
  d.setDate(d.getDate() + i)
  return d
})

function Book({ onBooked }) {
  const [services, setServices] = useState([])
  const [svc, setSvc] = useState(null)
  const [date, setDate] = useState(iso(new Date()))
  const [slots, setSlots] = useState(null)
  const [time, setTime] = useState('')
  const [note, setNote] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    api('GET', '/services').then(setServices).catch((e) => setErr(e.message))
  }, [])

  const loadSlots = useCallback(() => {
    if (!svc) return
    setSlots(null)
    setTime('')
    api('GET', `/slots?date=${date}&service_id=${svc.id}`)
      .then((r) => setSlots(r.slots))
      .catch((e) => setErr(e.message))
  }, [svc, date])
  useEffect(loadSlots, [loadSlots])

  const confirm = async () => {
    setErr('')
    setBusy(true)
    try {
      await api('POST', '/bookings', { service_id: svc.id, date, time, note })
      onBooked()
    } catch (e) {
      setErr(e.message)
      loadSlots()
    } finally {
      setBusy(false)
    }
  }

  const step = !svc ? 1 : !time ? 2 : 3
  const stepEl = (n, label) => (
    <div className={'step ' + (step === n ? 'on' : step > n ? 'done' : '')}><i>{step > n ? '✓' : n}</i> {label}</div>
  )

  return (
    <>
      <div className="page-head">
        <h1>Book an appointment</h1>
        <p className="muted">Choose a service, then pick a day and time.</p>
      </div>
      <div className="steps">{stepEl(1, 'Service')}{stepEl(2, 'Date & time')}{stepEl(3, 'Confirm')}</div>
      {err && <div className="error" style={{ marginBottom: 16 }}>{err}</div>}

      <div className="grid book-layout">
        <div className="stack" style={{ gap: 24 }}>
          <section>
            <h2 style={{ marginBottom: 12 }}>1. Select service</h2>
            <div className="grid cols-2">
              {services.map((s) => (
                <div key={s.id} className={'card service-card' + (svc?.id === s.id ? ' selected' : '')} onClick={() => setSvc(s)}>
                  <div className="row between">
                    <h3>{s.name}</h3>
                    <span className="price">{money(s.price)}</span>
                  </div>
                  <p className="muted small" style={{ margin: '6px 0 10px' }}>{s.description}</p>
                  <span className="badge">{dur(s.duration_min)}</span>
                </div>
              ))}
              {!services.length && !err && <div className="empty">No services available yet.</div>}
            </div>
          </section>

          {svc && (
            <section>
              <h2 style={{ marginBottom: 12 }}>2. Pick date & time</h2>
              <div className="date-strip">
                {nextDays(21).map((d) => (
                  <button key={iso(d)} className={'date-chip' + (iso(d) === date ? ' selected' : '')} onClick={() => setDate(iso(d))}>
                    <small>{d.toLocaleDateString('en-IN', { weekday: 'short' })}</small>
                    <b>{d.getDate()}</b>
                    <small>{d.toLocaleDateString('en-IN', { month: 'short' })}</small>
                  </button>
                ))}
              </div>
              <div className="card" style={{ marginTop: 8 }}>
                {slots === null ? (
                  <p className="muted">Loading slots…</p>
                ) : slots.length ? (
                  <div className="slot-grid">
                    {slots.map((t) => (
                      <button key={t} className={'slot' + (time === t ? ' selected' : '')} onClick={() => setTime(t)}>{time12(t)}</button>
                    ))}
                  </div>
                ) : (
                  <div className="empty" style={{ padding: 16 }}>No free slots on this day. Try another date.</div>
                )}
              </div>
            </section>
          )}
        </div>

        <aside className="card summary stack">
          <h2>Your booking</h2>
          <dl>
            <div><dt>Service</dt><dd>{svc ? svc.name : '—'}</dd></div>
            <div><dt>Date</dt><dd>{svc ? nice(date) : '—'}</dd></div>
            <div><dt>Time</dt><dd>{time ? time12(time) : '—'}</dd></div>
            <div><dt>Duration</dt><dd>{svc ? dur(svc.duration_min) : '—'}</dd></div>
            <div><dt>Total</dt><dd className="price">{svc ? money(svc.price) : '—'}</dd></div>
          </dl>
          <div>
            <label>Note (optional)</label>
            <textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Anything we should know?" />
          </div>
          <button className="btn block" disabled={!svc || !time || busy} onClick={confirm}>
            {busy ? 'Booking…' : 'Confirm booking'}
          </button>
          <p className="muted small">Pay at the studio after your service.</p>
        </aside>
      </div>
    </>
  )
}

function MyBookings() {
  const [rows, setRows] = useState(null)
  const [toast, setToast] = useState('')
  const load = useCallback(() => api('GET', '/bookings/mine').then(setRows), [])
  useEffect(() => { load() }, [load])

  const cancel = async (id) => {
    if (!confirm('Cancel this booking?')) return
    try {
      await api('PATCH', `/bookings/${id}/cancel`)
      setToast('Booking cancelled')
      load()
    } catch (e) {
      setToast(e.message)
    }
  }

  return (
    <>
      <div className="page-head">
        <h1>My bookings</h1>
        <p className="muted">Your upcoming and past appointments.</p>
      </div>
      <div className="stack">
        {rows === null && <p className="muted">Loading…</p>}
        {rows?.length === 0 && <div className="card empty">You have no bookings yet.</div>}
        {rows?.map((b) => {
          const d = parseDate(b.date)
          return (
            <div key={b.id} className="card booking-item">
              <div className="booking-date">
                <small>{d.toLocaleDateString('en-IN', { month: 'short' })}</small>
                <b>{d.getDate()}</b>
              </div>
              <div className="booking-main">
                <h3>{b.service_name}</h3>
                <p className="muted small">{nice(b.date)} · {time12(b.start)} – {time12(b.end)} · {money(b.price)}</p>
                {b.note && <p className="small" style={{ marginTop: 4 }}>“{b.note}”</p>}
              </div>
              <Badge status={b.status} />
              {b.status === 'booked' && <button className="btn danger sm" onClick={() => cancel(b.id)}>Cancel</button>}
            </div>
          )
        })}
      </div>
      <Toast msg={toast} onDone={() => setToast('')} />
    </>
  )
}

export default function Customer({ user, onLogout }) {
  const [tab, setTab] = useState('book')
  const [toast, setToast] = useState('')
  return (
    <>
      <TopBar user={user} tab={tab} setTab={setTab} onLogout={onLogout} tabs={[['book', 'Book'], ['mine', 'My bookings']]} />
      <main className="container">
        {tab === 'book' ? (
          <Book onBooked={() => { setToast('Booking confirmed 🎉'); setTab('mine') }} />
        ) : (
          <MyBookings />
        )}
      </main>
      <Toast msg={toast} onDone={() => setToast('')} />
    </>
  )
}
