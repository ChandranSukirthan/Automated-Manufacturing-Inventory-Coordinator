import React, { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  ShoppingCart,
  Building2,
  CheckSquare,
  BarChart3,
  LogOut,
  Menu,
  X,
  Bell,
  ChevronRight,
  ShieldCheck,
  UserCheck
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import purchaseOrderService from '../../services/purchaseOrderService';

export default function AppLayout({ children, title, subtitle, actionButton }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);

  // Fetch pending POs count for notification badge on AI Approvals link
  useEffect(() => {
    let isMounted = true;
    const fetchPendingCount = async () => {
      try {
        const orders = await purchaseOrderService.getPurchaseOrders();
        if (isMounted) {
          const count = orders.filter((o) => o.status === 'PendingApproval').length;
          setPendingCount(count);
        }
      } catch (err) {
        // silent catch
      }
    };
    fetchPendingCount();
    const interval = setInterval(fetchPendingCount, 15000); // refresh every 15s
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, [location.pathname]);

  const navItems = [
    {
      label: 'Purchase Orders',
      path: '/purchase-orders',
      icon: <ShoppingCart className="w-5 h-5" />,
      active: location.pathname === '/purchase-orders' || location.pathname.startsWith('/purchase-orders/')
    },
    {
      label: 'Suppliers',
      path: '/suppliers',
      icon: <Building2 className="w-5 h-5" />,
      active: location.pathname === '/suppliers' || location.pathname.startsWith('/suppliers/')
    },
    {
      label: 'AI Approvals',
      path: '/ai-approvals',
      icon: <CheckSquare className="w-5 h-5" />,
      badge: pendingCount > 0 ? pendingCount : null,
      active: location.pathname === '/ai-approvals'
    },
    {
      label: 'Supplier Analytics',
      path: '/supplier-analytics',
      icon: <BarChart3 className="w-5 h-5" />,
      active: location.pathname === '/supplier-analytics'
    }
  ];

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getRoleName = (role) => {
    const r = typeof role === 'number' ? role : parseInt(role, 10);
    switch (r) {
      case 1:
        return 'Supply Chain Manager';
      case 2:
        return 'Quality Inspector';
      case 3:
        return 'System Admin';
      default:
        return 'Floor Worker';
    }
  };

  return (
    <div className="min-h-screen bg-[#070b14] text-slate-100 flex flex-col md:flex-row">
      {/* Mobile top bar */}
      <div className="md:hidden flex items-center justify-between px-4 py-3 bg-slate-900/90 border-b border-slate-800 sticky top-0 z-40 backdrop-blur-md">
        <div className="flex items-center gap-2.5">
          <img src="/assets/amic-logo.png" alt="AMIC Logo" className="h-8 w-auto object-contain" />
          <span className="font-bold tracking-tight text-white text-base">AMIC PO</span>
        </div>
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="p-2 text-slate-400 hover:text-white rounded-lg bg-slate-800/60"
        >
          {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* Sidebar navigation */}
      <aside
        className={`fixed md:sticky top-0 h-screen w-64 bg-slate-950/95 border-r border-slate-800/80 flex flex-col z-50 transition-transform duration-200 md:translate-x-0 ${
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Logo area */}
        <div className="p-5 border-b border-slate-800/80 flex items-center justify-between">
          <Link to="/purchase-orders" className="flex items-center gap-3 group">
            <div className="w-9 h-9 rounded-xl bg-brand-500/10 border border-brand-500/30 flex items-center justify-center p-1.5 group-hover:border-brand-500/60 transition-all">
              <img src="/assets/amic-logo.png" alt="AMIC Logo" className="w-full h-full object-contain" />
            </div>
            <div>
              <div className="font-bold text-white text-base tracking-tight leading-tight">
                AMIC <span className="text-brand-400 font-semibold text-xs ml-1">SCM</span>
              </div>
              <div className="text-[10px] text-slate-400 tracking-wider uppercase font-medium">
                Supply Chain Manager
              </div>
            </div>
          </Link>
          <button
            onClick={() => setMobileMenuOpen(false)}
            className="md:hidden p-1.5 text-slate-400 hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Manager role badge */}
        <div className="px-4 py-3">
          <div className="p-3 rounded-xl bg-gradient-to-r from-brand-950/60 to-slate-900 border border-brand-800/40 flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-brand-500/20 border border-brand-400/30 flex items-center justify-center text-brand-400">
              <ShieldCheck className="w-4 h-4" />
            </div>
            <div className="overflow-hidden">
              <p className="text-xs font-semibold text-white truncate">
                {user?.fullName || 'Sukirthan (Manager)'}
              </p>
              <p className="text-[10px] text-brand-400 font-medium">
                {getRoleName(user?.role)}
              </p>
            </div>
          </div>
        </div>

        {/* Navigation links */}
        <nav className="flex-1 px-3 py-2 space-y-1 overflow-y-auto">
          {navItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              onClick={() => setMobileMenuOpen(false)}
              className={`flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-medium transition-all ${
                item.active
                  ? 'bg-gradient-to-r from-brand-600 to-brand-700 text-white shadow-lg shadow-brand-600/20'
                  : 'text-slate-400 hover:text-slate-100 hover:bg-slate-900/80'
              }`}
            >
              <div className="flex items-center gap-3">
                <span className={item.active ? 'text-white' : 'text-slate-400'}>{item.icon}</span>
                <span>{item.label}</span>
              </div>
              {item.badge && (
                <span className="px-2 py-0.5 text-xs font-bold rounded-full bg-amber-500 text-slate-950 animate-pulse">
                  {item.badge}
                </span>
              )}
            </Link>
          ))}
        </nav>

        {/* User Profile & Logout */}
        <div className="p-4 border-t border-slate-800/80 space-y-2">
          <div className="flex items-center justify-between text-xs text-slate-400 px-1">
            <span className="truncate">{user?.email}</span>
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-3.5 py-2 text-sm font-medium text-slate-300 hover:text-rose-300 hover:bg-rose-500/10 rounded-xl border border-slate-800 hover:border-rose-500/30 transition-all"
          >
            <LogOut className="w-4 h-4" />
            <span>Sign Out</span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col min-w-0 overflow-y-auto min-h-screen">
        {/* Top Header Bar */}
        <header className="sticky top-0 z-30 bg-slate-950/80 backdrop-blur-md border-b border-slate-800/80 px-6 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-xl md:text-2xl font-bold text-white tracking-tight flex items-center gap-2">
              {title}
            </h1>
            {subtitle && <p className="text-xs md:text-sm text-slate-400 mt-0.5">{subtitle}</p>}
          </div>

          <div className="flex items-center gap-3">
            {pendingCount > 0 && (
              <Link
                to="/ai-approvals"
                className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs font-semibold rounded-xl hover:bg-amber-500/20 transition-all"
              >
                <Bell className="w-3.5 h-3.5 animate-bounce" />
                <span>{pendingCount} Pending Approval</span>
              </Link>
            )}
            {actionButton}
          </div>
        </header>

        {/* Page Content Body */}
        <div className="flex-1 p-6 md:p-8 max-w-7xl w-full mx-auto space-y-6">
          {children}
        </div>
      </main>
    </div>
  );
}
