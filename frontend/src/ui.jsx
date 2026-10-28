import { useEffect } from 'react'

export const money = (n) => '₹' + Number(n).toLocaleString('en-IN')

export const dur = (m) => (m >= 60 ? `${Math.floor(m / 60)}h${m % 60 ? ' ' + (m % 60) + 'm' : ''}` : `${m} min`)

export const iso = (d) => {
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

// 'YYYY-MM-DD' -> local Date (avoids the UTC shift of new Date('YYYY-MM-DD'))
export const parseDate = (s) => {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export const nice = (s) => parseDate(s).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })

export const time12 = (t) => {
  const [h, m] = t.split(':').map(Number)
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`
}

export const STATUS_LABEL = { booked: 'Upcoming', completed: 'Completed', cancelled: 'Cancelled', no_show: 'No-show' }

export function Badge({ status }) {
  return <span className={'badge ' + status}>{STATUS_LABEL[status] || status}</span>
}

export function Toast({ msg, onDone }) {
  useEffect(() => {
    if (!msg) return
    const t = setTimeout(onDone, 2800)
    return () => clearTimeout(t)
  }, [msg, onDone])
  return msg ? <div className="toast">{msg}</div> : null
}

export function TopBar({ user, tabs, tab, setTab, onLogout }) {
  return (
    <header className="topbar">
      <div className="topbar-inner">
        <div className="brand">
          <div className="brand-mark">✂</div> Glow Studio
        </div>
        <nav className="nav">
          {tabs.map(([k, label]) => (
            <button key={k} className={tab === k ? 'active' : ''} onClick={() => setTab(k)}>
              {label}
            </button>
          ))}
          <button onClick={onLogout} title={user.name}>
            Logout
          </button>
        </nav>
      </div>
    </header>
  )
}
