'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { adminLogin } from '@/lib/api'

export default function AdminLoginPage() {
  const router = useRouter()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [errorMsg, setErrorMsg] = useState('')
  const [loading, setLoading] = useState(false)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMsg('')

    if (!username.trim() || !password.trim()) {
      setErrorMsg('Please enter both your username and password.')
      return
    }

    setLoading(true)
    try {
      const res = await adminLogin({
        username: username.trim().toLowerCase(),
        password: password.trim(),
      })

      if (res.success) {
        router.push('/admin')
      } else {
        setErrorMsg('Invalid admin credentials. Please try again.')
      }
    } catch (err: any) {
      setErrorMsg(err.message || 'Authentication failed. Please verify your credentials.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-[75vh] flex flex-col items-center justify-center py-8">
      {/* Container */}
      <div className="w-full max-w-md">
        {/* Brand Header */}
        <div className="text-center mb-8 space-y-2">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-gold/10 border border-gold/30 text-gold font-black text-xl mb-2">
            CL
          </div>
          <h1 className="text-2xl font-black text-white tracking-tight">
            Hostel Admin Portal
          </h1>
          <p className="text-xs text-slate-400">
            Sign in to manage laundry operations, student quotas &amp; kiosks
          </p>
        </div>

        {/* Login Glass Panel */}
        <div className="glass-panel p-6 sm:p-8 rounded-2xl border-white/10 shadow-2xl space-y-6">
          <form onSubmit={handleLogin} className="space-y-4">
            {/* Username Input */}
            <div>
              <label className="text-xs font-semibold uppercase tracking-wider text-slate-300 block mb-1.5">
                Username
              </label>
              <input
                type="text"
                value={username}
                onChange={(e) => {
                  setUsername(e.target.value)
                  setErrorMsg('')
                }}
                placeholder="e.g. admin or warden_b"
                autoComplete="username"
                className="w-full glass-input px-3.5 py-2.5 rounded-xl font-mono text-sm text-white placeholder-slate-500 focus:outline-none"
              />
            </div>

            {/* Password Input */}
            <div>
              <label className="text-xs font-semibold uppercase tracking-wider text-slate-300 block mb-1.5">
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value)
                  setErrorMsg('')
                }}
                placeholder="&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;"
                autoComplete="current-password"
                className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-none"
              />
            </div>

            {/* Error Message */}
            {errorMsg && (
              <div className="p-3 rounded-xl bg-terracotta/10 border border-terracotta/30 text-terracotta text-xs flex items-center gap-2">
                <span>&bull;</span>
                <span>{errorMsg}</span>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl bg-gold hover:bg-gold-light text-obsidian-950 font-bold text-xs uppercase tracking-wider transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-md"
            >
              {loading ? 'Authenticating...' : 'Sign In to Console &rarr;'}
            </button>
          </form>

          {/* Quick Credential Hints */}
          <div className="pt-4 border-t border-white/5 space-y-2 text-[11px] text-slate-500">
            <div className="font-semibold text-slate-400">Default Staff Credentials:</div>
            <div className="flex justify-between font-mono text-slate-400 bg-obsidian-900/60 p-2 rounded-lg border border-white/5">
              <span>admin</span>
              <span className="text-slate-500">admin123</span>
              <span className="text-gold text-[10px] uppercase">superadmin</span>
            </div>
            <div className="flex justify-between font-mono text-slate-400 bg-obsidian-900/60 p-2 rounded-lg border border-white/5">
              <span>warden_b</span>
              <span className="text-slate-500">warden123</span>
              <span className="text-sage text-[10px] uppercase">warden</span>
            </div>
          </div>
        </div>

        {/* Back to Role Selection */}
        <div className="text-center mt-6">
          <Link
            href="/"
            className="text-xs text-slate-400 hover:text-white transition-colors"
          >
            &larr; Return to Student Portal
          </Link>
        </div>
      </div>
    </div>
  )
}
