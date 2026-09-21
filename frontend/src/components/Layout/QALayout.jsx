import React, { useState } from 'react';
import { Link, useLocation, useNavigate, Outlet } from 'react-router-dom';
import {
  ShieldCheck,
  LayoutDashboard,
  AlertTriangle,
  ShieldAlert,
  History,
  User as UserIcon,
  LogOut,
  Menu,
  X,
  ChevronRight,
  Activity
} from 'lucide-react';
import { useAuth } from '../../context/useAuth';

export default function QALayout({ children, title, subtitle }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  const isRouteActive = (path) => {
    const currentPath = location.pathname;
    if (path === '/quality') {
      return currentPath === '/quality' || currentPath === '/dashboard/quality';
    }
    if (path === '/quality/quarantine/history') {
      return currentPath === '/quality/quarantine/history' || currentPath === '/dashboard/quarantine/history';
    }
    if (path === '/quality/quarantine') {
      return (
        (currentPath.startsWith('/quality/quarantine') || currentPath.startsWith('/dashboard/quarantine')) &&
        !currentPath.includes('/history')
      );
    }
    if (path === '/quality/defects') {
      return currentPath.startsWith('/quality/defects') || currentPath.startsWith('/dashboard/defects');
    }
    if (path === '/profile') {
      return currentPath === '/profile';
    }
    return currentPath === path;
  };

  const navSections = [
    {
      title: 'Quality Control',
      items: [
        { label: 'Dashboard', path: '/quality', icon: LayoutDashboard },
        { label: 'Defect Reports', path: '/quality/defects', icon: AlertTriangle },
        { label: 'Quarantine Management', path: '/quality/quarantine', icon: ShieldAlert },
        { label: 'Quarantine History', path: '/quality/quarantine/history', icon: History }
      ]
    },
    {
      title: 'Account',
      items: [
        { label: 'Profile', path: '/profile', icon: UserIcon }
      ]
    }
  ];

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex font-sans selection:bg-purple-500 selection:text-white">
      {/* Ambient background glows */}
      <div className="fixed top-0 left-64 w-96 h-96 bg-purple-600/10 rounded-full blur-[140px] pointer-events-none -z-10" />
      <div className="fixed bottom-0 right-10 w-96 h-96 bg-violet-600/10 rounded-full blur-[140px] pointer-events-none -z-10" />

      {/* Mobile Sidebar Backdrop Overlay */}
      {mobileMenuOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-40 lg:hidden backdrop-blur-sm transition-opacity"
          onClick={() => setMobileMenuOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* Left Sidebar */}
      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 w-72 bg-slate-900/90 backdrop-blur-2xl border-r border-slate-800 flex flex-col transition-transform duration-300 lg:translate-x-0 ${
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
        aria-label="Quality Control Sidebar"
      >
        {/* Brand Header */}
        <div className="p-6 border-b border-slate-800 flex items-center justify-between">
          <Link
            to="/quality"
            onClick={() => setMobileMenuOpen(false)}
            className="flex items-center gap-3 group"
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-violet-600 flex items-center justify-center shadow-lg shadow-purple-500/20 group-hover:scale-105 transition-transform text-white">
              <ShieldCheck className="w-5 h-5 stroke-[2.5]" />
            </div>
            <div>
              <span className="text-xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-slate-200">
                QUALITY CONTROL
              </span>
              <span className="block text-xs font-semibold text-purple-400 tracking-wider uppercase">
                Manufacturing QA
              </span>
            </div>
          </Link>
          <button
            onClick={() => setMobileMenuOpen(false)}
            className="lg:hidden text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition-colors"
            aria-label="Close menu"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Links */}
        <div className="flex-1 overflow-y-auto px-4 py-6 space-y-6 custom-scrollbar">
          {navSections.map((section, idx) => (
            <div key={idx} className="space-y-2">
              <h3 className="px-3 text-xs font-bold uppercase tracking-wider text-slate-400">
                {section.title}
              </h3>
              <div className="space-y-1">
                {section.items.map((item) => {
                  const Icon = item.icon;
                  const isActive = isRouteActive(item.path);
                  return (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setMobileMenuOpen(false)}
                      className={`flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-medium transition-all group ${
                        isActive
                          ? 'bg-purple-600 text-white font-bold shadow-lg shadow-purple-600/25'
                          : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/60'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <Icon
                          className={`w-4 h-4 transition-colors ${
                            isActive ? 'text-white stroke-[2.5]' : 'text-slate-400 group-hover:text-purple-400'
                          }`}
                        />
                        <span>{item.label}</span>
                      </div>
                      {isActive && <ChevronRight className="w-4 h-4 text-white/80 stroke-[2.5]" />}
                    </Link>
                  );
                })}

                {/* Place Logout in ACCOUNT section */}
                {section.title === 'Account' && (
                  <button
                    onClick={handleLogout}
                    className="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-medium text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-all group text-left"
                  >
                    <div className="flex items-center gap-3">
                      <LogOut className="w-4 h-4 text-slate-400 group-hover:text-rose-400" />
                      <span>Logout</span>
                    </div>
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>

        {/* User Profile Bar */}
        <div className="p-4 border-t border-slate-800 bg-slate-950/60">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3 overflow-hidden">
              <div className="w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center text-purple-400 font-semibold shrink-0">
                {user?.fullName ? user.fullName.charAt(0).toUpperCase() : <UserIcon className="w-4 h-4" />}
              </div>
              <div className="truncate">
                <p className="text-sm font-semibold text-white truncate">
                  {user?.fullName || 'Quality Inspector'}
                </p>
                <span className="inline-block px-2 py-0.5 text-[10px] font-medium rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/30">
                  Quality Inspector
                </span>
              </div>
            </div>
            <button
              onClick={handleLogout}
              title="Sign Out"
              className="p-2 rounded-xl text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 border border-transparent hover:border-rose-500/20 transition-all shrink-0"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 lg:pl-72">
        {/* Sticky Topbar */}
        <header className="sticky top-0 z-30 h-16 bg-slate-950/80 backdrop-blur-xl border-b border-slate-800 px-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => setMobileMenuOpen(true)}
              className="lg:hidden p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 border border-slate-800 transition-colors"
              aria-label="Open menu"
            >
              <Menu className="w-5 h-5" />
            </button>
            <div>
              <h1 className="text-lg font-bold text-white tracking-tight">
                {title || 'Quality Control'}
              </h1>
              {subtitle && <p className="text-xs text-slate-400 hidden sm:block">{subtitle}</p>}
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900 border border-slate-800 text-xs text-slate-300">
              <span className="w-2 h-2 rounded-full bg-purple-400 animate-pulse" />
              <span className="font-mono text-purple-400 font-medium">System Online</span>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 min-w-0">
          {children || <Outlet />}
        </main>
      </div>
    </div>

  );
}
