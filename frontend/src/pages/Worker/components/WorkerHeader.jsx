import React from 'react';
import { Package, RefreshCw, LogOut } from 'lucide-react';

export default function WorkerHeader({ user, loading, onRefresh, onLogout }) {
  return (
    <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-30">
      {/* Gradient accent bar */}
      <div className="h-0.5 bg-gradient-to-r from-cyan-500 via-blue-500 to-purple-500" />

      <div className="px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 border border-cyan-500/30 flex items-center justify-center text-cyan-400 font-bold shadow-lg shadow-cyan-500/5">
            <Package className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold tracking-tight text-white flex items-center gap-2">
              Floor Worker Console
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-gradient-to-r from-cyan-500/20 to-blue-500/20 text-cyan-400 font-mono border border-cyan-500/30">
                Student 1
              </span>
            </h1>
            <p className="text-xs text-slate-400">
              Inventory Tracking • Barcode Scanning • Stock Logistics
            </p>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <button
            onClick={onRefresh}
            disabled={loading}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-slate-700 bg-slate-800 hover:bg-slate-700 text-xs text-slate-300 transition group"
            title="Refresh Data"
          >
            <RefreshCw className={`w-3.5 h-3.5 transition-transform ${loading ? 'animate-spin text-cyan-400' : 'group-hover:rotate-45'}`} />
            Refresh
          </button>

          <div className="flex items-center gap-2 pl-3 border-l border-slate-800">
            <div className="text-right">
              <div className="text-xs font-semibold text-slate-200">{user?.fullName || 'Floor Worker'}</div>
              <div className="text-[10px] text-cyan-400 font-mono uppercase tracking-wider">Floor Worker</div>
              <div className="text-xs font-semibold text-slate-200">{user?.fullName || 'User'}</div>
            </div>
            <button
              onClick={onLogout}
              className="p-2 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </header>
  );
}

