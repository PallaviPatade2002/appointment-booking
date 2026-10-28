import { useState } from 'react'
import { getSession, setSession } from './api'
import Login from './pages/Login'
import Customer from './pages/Customer'
import Admin from './pages/Admin'

export default function App() {
  const [session, setSess] = useState(getSession())

  const onAuth = (s) => {
    setSession(s)
    setSess(s)
  }
  const logout = () => onAuth(null)

  if (!session) return <Login onAuth={onAuth} />
  return session.user.role === 'admin' ? (
    <Admin user={session.user} onLogout={logout} />
  ) : (
    <Customer user={session.user} onLogout={logout} />
  )
}
