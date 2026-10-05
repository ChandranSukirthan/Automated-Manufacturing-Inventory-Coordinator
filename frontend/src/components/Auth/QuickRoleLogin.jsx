import React, { useState } from 'react';
import { 
  Zap, 
  Package, 
  Briefcase, 
  ClipboardCheck, 
  ShieldCheck, 
  Loader2 
} from 'lucide-react';

export const QUICK_ROLES = [
  {
    id: 'worker',
    name: 'Floor Worker',
    roleTag: 'Inventory & Alerts',
    email: 'worker@amic.com',
    password: 'Worker@123',
    icon: Package,
    badgeClass: 'text-amber-400 bg-amber-500/10 border-amber-500/30 group-hover:border-amber-400 group-hover:bg-amber-500/20',
    borderHover: 'hover:border-amber-500/60 hover:bg-amber-500/5 hover:shadow-[0_0_15px_rgba(245,158,11,0.15)]'
  },
  {
    id: 'manager',
    name: 'SCM Manager',
    roleTag: 'Procurement & AI',
    email: 'manager@amic.com',
    password: 'Manager@123',
    icon: Briefcase,
    badgeClass: 'text-cyan-400 bg-cyan-500/10 border-cyan-500/30 group-hover:border-cyan-400 group-hover:bg-cyan-500/20',
    borderHover: 'hover:border-cyan-500/60 hover:bg-cyan-500/5 hover:shadow-[0_0_15px_rgba(6,182,212,0.15)]'
  },
  {
    id: 'quality',
    name: 'Quality Inspector',
    roleTag: 'QA & Quarantine',
    email: 'quality@amic.com',
    password: 'Quality@123',
    icon: ClipboardCheck,
    badgeClass: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30 group-hover:border-emerald-400 group-hover:bg-emerald-500/20',
    borderHover: 'hover:border-emerald-500/60 hover:bg-emerald-500/5 hover:shadow-[0_0_15px_rgba(16,185,129,0.15)]'
  },
  {
    id: 'admin',
    name: 'System Admin',
    roleTag: 'Config & Users',
    email: 'admin@amic.com',
    password: 'Admin@123',
    icon: ShieldCheck,
    badgeClass: 'text-indigo-400 bg-indigo-500/10 border-indigo-500/30 group-hover:border-indigo-400 group-hover:bg-indigo-500/20',
    borderHover: 'hover:border-indigo-500/60 hover:bg-indigo-500/5 hover:shadow-[0_0_15px_rgba(99,102,241,0.15)]'
  }
];

export default function QuickRoleLogin({ onQuickLogin, disabled = false }) {
  const [activeRole, setActiveRole] = useState(null);

  const handleClick = async (role) => {
    setActiveRole(role.id);
    try {
      await onQuickLogin(role);
    } finally {
      setActiveRole(null);
    }
  };

  return (
    <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-700/80 shadow-lg mb-3">
      <div className="flex items-center justify-between mb-2.5">
        <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-200">
          <Zap className="w-4 h-4 text-amber-400 fill-amber-400" />
          <span>Quick Login by Role</span>
        </div>
        <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-brand-500/20 text-brand-300 border border-brand-500/40">
          1-Click Demo
        </span>
      </div>

      <div className="grid grid-cols-2 gap-2">
        {QUICK_ROLES.map((r) => {
          const Icon = r.icon;
          const isLoading = disabled && activeRole === r.id;
          return (
            <button
              key={r.id}
              type="button"
              disabled={disabled}
              onClick={() => handleClick(r)}
              className={`group relative flex items-center gap-2 p-2 rounded-lg border border-slate-700/80 bg-slate-800/60 text-left transition-all duration-150 ${r.borderHover} disabled:opacity-50 cursor-pointer`}
            >
              <div className={`p-1.5 rounded-md border shrink-0 transition-colors ${r.badgeClass}`}>
                {isLoading ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-white" />
                ) : (
                  <Icon className="w-3.5 h-3.5" />
                )}
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-xs font-semibold text-slate-100 truncate group-hover:text-white">
                  {r.name}
                </div>
                <div className="text-[10px] text-slate-400 truncate">
                  {r.roleTag}
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

