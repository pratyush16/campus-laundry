import type { Metadata } from 'next'
import './globals.css'
import Navbar from '@/components/Navbar'

export const metadata: Metadata = {
  title: 'CampusLaundry',
  description: 'Smart college hostel laundry quota tracking, drop point drop-off, and cycle management system.',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="dark">
      <body className="bg-obsidian-950 text-slate-100 min-h-screen flex flex-col relative selection:bg-sage/20 selection:text-sage-light">
        {/* Subtle Ambient Background Glows */}
        <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
          <div className="absolute -top-40 right-10 w-96 h-96 bg-sage/10 rounded-full blur-3xl"></div>
          <div className="absolute top-1/3 -left-32 w-80 h-80 bg-terracotta/10 rounded-full blur-3xl"></div>
          <div className="absolute -bottom-20 right-1/4 w-96 h-96 bg-gold/5 rounded-full blur-3xl"></div>
        </div>

        {/* Global Navigation Header */}
        <Navbar />

        {/* Main Content Area */}
        <main className="flex-1 relative z-10 max-w-7xl w-full mx-auto px-4 sm:px-8 py-6 sm:py-8">
          {children}
        </main>

        {/* Footer */}
        <footer className="relative z-10 glass-panel border-t border-white/5 py-4 text-center text-xs text-slate-500">
          <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2">
            <span>&copy; {new Date().getFullYear()} CampusLaundry System</span>
            <div className="flex gap-4">
              <span className="text-slate-400">Policy: 30 Cycles/Year</span>
              <span className="text-slate-400">Standard Turnaround: 72 hrs</span>
            </div>
          </div>
        </footer>
      </body>
    </html>
  )
}
