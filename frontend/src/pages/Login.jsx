import { useState } from 'react'
import { api } from '../api'

export default function Login({ onAuth }) {
  const [mode, setMode] = useState('login')
  const [f, setF] = useState({ name: '', phone: '', password: '' })
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    setErr('')
    setBusy(true)
    try {
      const body = mode === 'login' ? { phone: f.phone, password: f.password } : f
      onAuth(await api('POST', '/auth/' + mode, body))
    } catch (x) {
      setErr(x.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth-wrap">
      <section className="auth-hero">
        <div className="brand">
          <div className="brand-mark" style={{ background: 'rgba(255,255,255,0.18)' }}>✂</div> Glow Studio
        </div>
        <div>
          <h1>Book your appointment in a few taps.</h1>
          <p>Pick a service, choose a time that suits you and you are done. No calls, no waiting.</p>
          <ul className="feature-list">
            <li><span>⚡</span> Live available time slots</li>
            <li><span>🔒</span> No double bookings, ever</li>
            <li><span>↺</span> Cancel any time from your phone</li>
          </ul>
        </div>
        <p className="small" style={{ margin: 0 }}>© Glow Studio</p>
      </section>

      <section className="auth-form">
        <form className="card auth-card stack" onSubmit={submit}>
          <div>
            <h2>{mode === 'login' ? 'Welcome back' : 'Create your account'}</h2>
            <p className="muted small" style={{ marginTop: 4 }}>
              {mode === 'login' ? 'Login to manage your bookings.' : 'It takes less than a minute.'}
            </p>
          </div>
          <div className="tabs">
            <button type="button" className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')}>Login</button>
            <button type="button" className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')}>Sign up</button>
          </div>
          {mode === 'register' && (
            <div>
              <label>Full name</label>
              <input value={f.name} onChange={set('name')} placeholder="Your name" required />
            </div>
          )}
          <div>
            <label>Phone number</label>
            <input value={f.phone} onChange={set('phone')} placeholder="10-digit mobile" inputMode="numeric" required />
          </div>
          <div>
            <label>Password</label>
            <input type="password" value={f.password} onChange={set('password')} placeholder="Min 6 characters" minLength={6} required />
          </div>
          {err && <div className="error">{err}</div>}
          <button className="btn block" disabled={busy}>{busy ? 'Please wait…' : mode === 'login' ? 'Login' : 'Create account'}</button>
          <div className="demo">
            <b>Demo logins</b> (password 123456)<br />
            Customer: 9000000003 · Admin: 9000000001
          </div>
        </form>
      </section>
    </div>
  )
}
