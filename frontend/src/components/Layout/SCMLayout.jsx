import React, { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
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
  UserCheck,
  Sparkles,
  Bot
} from 'lucide-react';
import useMobileNavigation from './useMobileNavigation';
import { useAuth } from '../../context/useAuth';
import purchaseOrderService from '../../services/purchaseOrderService';
import StockAlertNotifications from '../Notifications/StockAlertNotifications';

export default function SCMLayout({ children, title, subtitle, actionButton }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { mobileMenuOpen, setMobileMenuOpen, sidebarRef } = useMobileNavigation();
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
    } catch {
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
      label: 'Dashboard',
      path: '/dashboard/manager',
      icon: <LayoutDashboard className="w-5 h-5" />,
      active: location.pathname === '/dashboard/admin' || location.pathname === '/dashboard/manager'
    },
    {
      label: 'Suppliers',
      path: '/suppliers',
      icon: <Building2 className="w-5 h-5" />,
      active: location.pathname === '/suppliers' || location.pathname.startsWith('/suppliers/')
    },
    {
      label: 'Purchase Orders',
      path: '/purchase-orders',
      icon: <ShoppingCart className="w-5 h-5" />,
      active:
        (location.pathname === '/purchase-orders' ||
          location.pathname === '/purchase-orders/create' ||
          (location.pathname.startsWith('/purchase-orders/') &&
            !location.pathname.includes('/approvals') &&
            !location.pathname.includes('/analytics') &&
            !location.pathname.includes('/procurement')))
    },
    {
      label: 'AI Procurement',
      path: '/purchase-orders/procurement',
      icon: <Sparkles className="w-5 h-5" />,
      active:
        location.pathname === '/purchase-orders/procurement' ||
        location.pathname === '/procurement-research'
    },
    {
      label: 'AI Approvals',
      path: '/purchase-orders/approvals',
      icon: <CheckSquare className="w-5 h-5" />,
      badge: pendingCount > 0 ? pendingCount : null,
      active: location.pathname === '/purchase-orders/approvals' || location.pathname === '/ai-approvals'
    },
    {
      label: 'Agent Workflows',
      path: '/agent-workflows',
      icon: <Bot className="w-5 h-5" />,
      active: location.pathname === '/agent-workflows'
    },
    {
      label: 'Analytics',
      path: '/purchase-orders/analytics',
      icon: <BarChart3 className="w-5 h-5" />,
      active: location.pathname === '/purchase-orders/analytics' || location.pathname === '/supplier-analytics'
    }
  ];

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getRoleName = (role) => {
    if (role === null || role === undefined) return '';
    const numericRole = typeof role === 'number' ? role : Number(role);
    if (Number.isInteger(numericRole)) {
      switch (numericRole) {
        case 1:
          return 'Supply Chain Manager';
        case 2:
          return 'Quality Inspector';
        case 3:
          return 'System Admin';
        default:
          return 'Floor Worker';
      }
    }

    const normalizedRole = String(role).trim().toLowerCase();
    if (normalizedRole === 'supplychainmanager' || normalizedRole === 'manager') {
      return 'Supply Chain Manager';
    }
    if (normalizedRole === 'qualityinspector' || normalizedRole === 'quality') {
      return 'Quality Inspector';
    }
    if (normalizedRole === 'itadmin' || normalizedRole === 'systemadmin' || normalizedRole === 'admin') {
      return 'System Admin';
    }
    return 'Floor Worker';
  };

  return (
    <div className="role-shell role-manager min-h-screen bg-[#070b14] text-slate-100 flex">
      {mobileMenuOpen && <div className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm lg:hidden"
        onClick={() => setMobileMenuOpen(false)} aria-hidden="true" />}

      {/* Sidebar navigation */}
      <aside ref={sidebarRef} aria-label="Supply Chain navigation"
        className={`fixed top-0 bottom-0 left-0 w-64 bg-slate-950/95 border-r border-slate-800/80 flex flex-col z-50 transition-transform duration-200 lg:translate-x-0 ${
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full invisible lg:visible'
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
            className="lg:hidden p-1.5 text-slate-400 hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* User profile badge */}
        <div className="px-4 py-3">
          <div className="p-3 rounded-xl bg-gradient-to-r from-brand-950/60 to-slate-900 border border-brand-800/40 flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-brand-500/20 border border-brand-400/30 flex items-center justify-center text-brand-400 shrink-0">
              <ShieldCheck className="w-4 h-4" />
            </div>
            <div className="overflow-hidden">
              <p className="text-xs font-semibold text-white truncate">
                {user?.fullName || 'User'}
              </p>
              <p className="text-[10px] text-brand-400 font-medium truncate">
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
          <Link to="/profile" onClick={() => setMobileMenuOpen(false)} className="block rounded-lg px-3 py-2 text-sm text-slate-300 hover:bg-slate-800">My Profile</Link>
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
      <main className="flex-1 flex flex-col min-w-0 min-h-screen lg:pl-64">
        {/* Top Header Bar */}
        <header className="role-topbar sticky top-0 z-30 bg-slate-950/80 backdrop-blur-md border-b border-slate-800/80 px-4 sm:px-6 py-4 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0 flex-1">
            <button aria-label="Open menu" onClick={() => setMobileMenuOpen(true)} className="lg:hidden shrink-0 p-2 rounded-lg border border-slate-800">
              <Menu className="w-5 h-5" />
            </button>
            <div className="min-w-0">
            <h1 className="text-xl md:text-2xl font-bold text-white tracking-tight break-words">
              {title}
            </h1>
            {subtitle && <p className="text-xs md:text-sm text-slate-400 mt-0.5">{subtitle}</p>}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Top Low Stock Alert Notification Button (Requirement 1) */}
            <StockAlertNotifications />

            {pendingCount > 0 && (
              <Link
                to="/ai-approvals"
                className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs font-semibold rounded-xl hover:bg-amber-500/20 transition-all"
              >
                <CheckSquare className="w-3.5 h-3.5" />
                <span>{pendingCount} Pending Approval</span>
              </Link>
            )}
            {actionButton}
          </div>
        </header>

        {/* Page Content Body */}
        <div className="role-content flex-1 min-w-0 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto space-y-6">
          {children}
        </div>
      </main>
    </div>
  );
}
