'use client'

import { usePathname, useRouter } from 'next/navigation'
import Link from 'next/link'
import { adminLogout } from '@/lib/api'

export default function Navbar() {
  const pathname = usePathname()
  const router = useRouter()

  // Hide the Logout button on the landing/home page (/) and the login screen (/admin/login)
  const isPublicPage = pathname === '/' || pathname === '/admin/login'

  const handleLogout = async () => {
    try {
      await adminLogout()
    } catch {
      // ignore
    }
    router.push('/')
  }

  return (
    <header className="sticky top-0 z-50 glass-panel border-b border-white/5 px-4 sm:px-8 py-3.5">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
        {/* Brand Title */}
        <div>
          <Link
            href="/"
            className="text-xl sm:text-2xl font-black tracking-tight text-white hover:text-slate-200 transition-colors"
          >
            CampusLaundry
          </Link>
        </div>

        {/* Right side: Today's Date and conditional Logout button */}
        <div className="flex items-center gap-3">
          <div className="text-xs font-mono text-slate-300 px-3 py-1.5 rounded-lg bg-obsidian-900 border border-white/5">
            {new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}
          </div>
          {!isPublicPage && (
            <button
              onClick={handleLogout}
              className="text-xs font-medium px-3 py-1.5 rounded-lg bg-red-500/10 border border-red-500/40 text-red-400 hover:bg-red-500/20 hover:border-red-500 hover:text-red-300 transition-all shadow-sm cursor-pointer"
            >
              Logout
            </button>
          )}
        </div>
      </div>
    </header>
  )
}
