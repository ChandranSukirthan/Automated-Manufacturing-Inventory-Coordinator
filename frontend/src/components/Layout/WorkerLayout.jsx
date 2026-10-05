import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';
import WorkerHeader from '../../pages/Worker/components/WorkerHeader';
import '../../pages/Worker/worker.css';

export default function WorkerLayout({ children, title, subtitle, onRefresh, loading }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const links = [
    ['/dashboard/worker', 'Dashboard'], ['/inventory', 'Inventory'],
    ['/worker/replenishment', 'Replenishment'], ['/agent-workflows', 'Agent Workflows'],
    ['/profile', 'Profile'],
  ];
  return (
    <div className="role-shell role-worker worker-shell min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      <WorkerHeader user={user} title={title} subtitle={subtitle} loading={loading}
        onRefresh={onRefresh} onLogout={() => { logout(); navigate('/login', { replace: true }); }} />
      <div className="worker-navigation border-b border-slate-800/80">
      <nav aria-label="Floor Worker navigation" className="mx-auto flex max-w-7xl gap-2 overflow-x-auto px-4 py-3 sm:px-6">
        {links.map(([to, label]) => <NavLink key={to} to={to} end={to !== '/inventory'}
          className={({ isActive }) => `shrink-0 rounded-xl border px-4 py-2.5 text-sm font-medium transition ${isActive ? 'border-cyan-400/25 bg-cyan-500/10 text-cyan-200 shadow-sm shadow-cyan-500/5' : 'border-transparent text-slate-400 hover:bg-slate-800/60 hover:text-white'}`}>
          {label}
        </NavLink>)}
      </nav>
      </div>
      <div className="role-content worker-content flex-1 min-w-0">{children}</div>
    </div>
  );
}
