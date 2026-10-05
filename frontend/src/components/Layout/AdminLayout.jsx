import useMobileNavigation from './useMobileNavigation';
import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { 
  Package, 
  Cpu, 
  Wrench, 
  Clock, 
  Users, 
  ShieldCheck, 
  FileText, 
  Bot, 
  Activity, 
  LayoutDashboard, 
  LogOut, 
  Menu, 
  X, 
  ChevronRight,
  User as UserIcon,
  Factory,
  CreditCard
} from 'lucide-react';
import { useAuth } from '../../context/useAuth';
import adminService from '../../services/adminService';
import { normalizeRole } from '../../utils/roles';

export default function AdminLayout({ children, title, subtitle, actionButton }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { mobileMenuOpen, setMobileMenuOpen, sidebarRef } = useMobileNavigation();
  const [pendingWfCount, setPendingWfCount] = useState(0);

  React.useEffect(() => {
    let isMounted = true;
    const checkPendingWorkflows = async () => {
      try {
        const workflows = await adminService.getAgentWorkflows();
        if (isMounted && Array.isArray(workflows)) {
          const pending = workflows.filter(
            w => w.workflowType === 'Maintenance' && (w.status === 3 || w.status === 'WaitingForApproval' || w.approvalStatus === 0 || w.approvalStatus === 'Pending') &&
                 w.status !== 1 && w.status !== 'Completed' &&
                 w.status !== 2 && w.status !== 'Failed'
          ).length;
          setPendingWfCount(pending);
        }
      } catch {
        // Silently ignore if unauthenticated or error
      }
    };

    checkPendingWorkflows();
    const interval = setInterval(checkPendingWorkflows, 15000);
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const navSections = [
    {
      title: 'Production & Equipment',
      items: [
        { label: 'Production Overview', path: '/production', icon: Factory },
        { label: 'Machines', path: '/machines', icon: Cpu },
        { label: 'Maintenance Logs', path: '/maintenance', icon: Wrench },
        { label: 'Work Shifts', path: '/shifts', icon: Clock },
      ]
    },
    {
      title: 'System Administration',
      items: [
        { label: 'Admin Hub', path: '/admin', icon: LayoutDashboard },
        { label: 'User Directory', path: '/admin/users', icon: Users },
        { label: 'Role Management', path: '/admin/roles', icon: ShieldCheck },
        { label: 'Audit Logs', path: '/admin/audit-logs', icon: FileText },
        { label: 'AI Workflows', path: '/admin/agent-workflows', icon: Bot },
        { label: 'Payment Approvals', path: '/ai-approvals', icon: CreditCard },
        { label: 'System Health', path: '/admin/system-health', icon: Activity },
        { label: 'My Profile', path: '/profile', icon: UserIcon },
      ]
    },
    {
      title: 'Shared Operations',
      items: [
        { label: 'Purchase Orders', path: '/purchase-orders', icon: Package },
        { label: 'Suppliers', path: '/suppliers', icon: Users },
        { label: 'AI Procurement', path: '/purchase-orders/procurement', icon: Bot },
        { label: 'Quality Control', path: '/quality', icon: ShieldCheck },
        { label: 'Worker Inventory', path: '/inventory', icon: Package },
      ]
    }
  ];

  const getRoleLabel = (role) => {
    switch (normalizeRole(role)) {
      case 0:
      case 'FloorWorker':
        return 'Floor Worker';
      case 1:
      case 'SupplyChainManager':
        return 'Supply Chain Mgr';
      case 2:
      case 'QualityInspector':
        return 'Quality Inspector';
      case 3:
      case 'ITAdmin':
        return 'IT Admin';
      default:
        return role || 'User';
    }
  };

  return (
    <div className="role-shell role-admin min-h-screen bg-slate-950 text-slate-100 flex font-sans selection:bg-brand-500 selection:text-white">
      {/* Ambient background glows */}
      <div className="fixed top-0 left-64 w-96 h-96 bg-brand-600/10 rounded-full blur-[140px] pointer-events-none -z-10" />
      <div className="fixed bottom-0 right-10 w-96 h-96 bg-cyan-600/10 rounded-full blur-[140px] pointer-events-none -z-10" />

      {/* Mobile Sidebar Overlay */}
      {mobileMenuOpen && (
        <div 
          className="fixed inset-0 bg-black/60 z-40 lg:hidden backdrop-blur-sm"
          onClick={() => setMobileMenuOpen(false)}
        />
      )}

      {/* Sidebar Navigation */}
      <aside ref={sidebarRef} className={`fixed top-0 bottom-0 left-0 z-50 w-72 bg-slate-900/80 backdrop-blur-2xl border-r border-white/10 flex flex-col transition-transform duration-300 lg:translate-x-0 ${
        mobileMenuOpen ? 'translate-x-0' : '-translate-x-full invisible lg:visible'
      }`}>
        {/* Brand Header */}
        <div className="p-6 border-b border-white/10 flex items-center justify-between">
          <Link to="/admin" className="flex items-center gap-3 group">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-brand-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-brand-500/20 group-hover:scale-105 transition-transform">
              <Package className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="text-xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-slate-300">
                AMIC
              </span>
              <span className="block text-xs font-semibold text-brand-400 tracking-wider uppercase">
                IT Admin Console
              </span>
            </div>
          </Link>
          <button 
            onClick={() => setMobileMenuOpen(false)}
            className="lg:hidden text-slate-400 hover:text-white p-1 rounded-lg hover:bg-white/5"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Menu */}
        <div className="flex-1 overflow-y-auto px-4 py-6 space-y-8 custom-scrollbar">
          {navSections.map((section, idx) => (
            <div key={idx} className="space-y-2">
              <h3 className="px-3 text-xs font-bold uppercase tracking-wider text-slate-400">
                {section.title}
              </h3>
              <div className="space-y-1">
                {section.items.map((item) => {
                  const Icon = item.icon;
                  const currentPath = location.pathname === '/purchase-orders/approvals' ? '/ai-approvals' : location.pathname;
                  const activePath = navSections.flatMap((group) => group.items)
                    .filter((link) => currentPath === link.path || (link.path !== '/admin' && currentPath.startsWith(`${link.path}/`)))
                    .sort((a, b) => b.path.length - a.path.length)[0]?.path;
                  const isActive = item.path === activePath;
                  return (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setMobileMenuOpen(false)}
                      className={`flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-medium transition-all group ${
                        isActive
                          ? 'bg-gradient-to-r from-brand-600/90 to-cyan-600/90 text-white shadow-lg shadow-brand-600/20'
                          : 'text-slate-400 hover:text-slate-100 hover:bg-white/5'
                      }`}
                    >
                      <div className="flex items-center gap-2 shrink-0">
                        <Icon className={`w-4 h-4 transition-colors ${isActive ? 'text-white' : 'text-slate-400 group-hover:text-brand-400'}`} />
                        <span>{item.label}</span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        {item.path === '/admin/agent-workflows' && pendingWfCount > 0 && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-amber-500/20 text-amber-300 border border-amber-500/40 animate-pulse shadow-sm shadow-amber-500/20">
                            {pendingWfCount}
                          </span>
                        )}
                        {isActive && <ChevronRight className="w-4 h-4 text-white/70" />}
                      </div>
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        {/* User Profile Bar & Logout */}
        <div className="p-4 border-t border-white/10 bg-slate-950/40">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3 overflow-hidden">
              <div className="w-9 h-9 rounded-xl bg-slate-800 border border-white/10 flex items-center justify-center text-brand-400 font-semibold shrink-0">
                {user?.fullName ? user.fullName.charAt(0).toUpperCase() : <UserIcon className="w-4 h-4" />}
              </div>
              <div className="truncate">
                <p className="text-sm font-semibold text-white truncate">{user?.fullName || 'Administrator'}</p>
                {getRoleLabel(user?.role) ? (
                  <span className="inline-block px-2 py-0.5 text-[10px] font-medium rounded-full bg-brand-500/20 text-brand-300 border border-brand-500/30">
                    {getRoleLabel(user?.role)}
                  </span>
                ) : null}
              </div>
            </div>
            <button
              onClick={handleLogout}
              title="Sign Out"
              className="p-2 rounded-xl text-slate-400 hover:text-red-400 hover:bg-red-500/10 border border-transparent hover:border-red-500/20 transition-all shrink-0"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 lg:pl-72">
        {/* Top Header */}
        <header className="role-topbar sticky top-0 z-30 min-h-16 bg-slate-950/80 backdrop-blur-xl border-b border-white/10 px-4 sm:px-6 py-3 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0 flex-1">
            <button
              aria-label="Open menu" onClick={() => setMobileMenuOpen(true)}
              className="lg:hidden p-2 rounded-xl text-slate-400 hover:text-white hover:bg-white/5 border border-white/10"
            >
              <Menu className="w-5 h-5" />
            </button>
            <div className="min-w-0">
              <h1 className="text-lg font-bold text-white tracking-tight break-words">{title || 'Manufacturing Coordinator'}</h1>
              {subtitle && <p className="text-xs text-slate-400 hidden sm:block">{subtitle}</p>}
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Link 
              to="/admin/system-health"
              className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 transition-colors text-xs text-slate-300"
            >
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span className="font-mono text-emerald-400 font-medium">System Online</span>
            </Link>
            {actionButton}
          </div>
        </header>

        {/* Page Content */}
        <main className="role-content flex-1 min-w-0 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto space-y-6">
          {children}
        </main>
      </div>
    </div>
  );
}

