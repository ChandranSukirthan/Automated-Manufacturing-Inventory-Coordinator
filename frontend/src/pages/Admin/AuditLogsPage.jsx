import React, { useState, useEffect } from 'react';
import { 
  FileText, 
  Search, 
  Filter, 
  CheckCircle2, 
  XCircle, 
  Calendar, 
  User, 
  Database, 
  Globe, 
  Loader2, 
  RefreshCw,
  AlertTriangle
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import adminService from '../../services/adminService';

export default function AuditLogsPage() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Filters
  const [userFilter, setUserFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [entityFilter, setEntityFilter] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');

  const fetchLogs = async (customParams = null) => {
    setLoading(true);
    setError('');
    try {
      const activeUser = customParams?.userName !== undefined ? customParams.userName : userFilter;
      const activeAction = customParams?.action !== undefined ? customParams.action : actionFilter;
      const activeEntity = customParams?.entity !== undefined ? customParams.entity : entityFilter;
      const activeFrom = customParams?.fromDate !== undefined ? customParams.fromDate : fromDate;
      const activeTo = customParams?.toDate !== undefined ? customParams.toDate : toDate;

      const params = {};
      if (activeUser) params.userName = activeUser;
      if (activeAction) params.action = activeAction;
      if (activeEntity) params.entity = activeEntity;
      if (activeFrom) params.fromDate = new Date(activeFrom + 'T00:00:00.000Z').toISOString();
      if (activeTo) params.toDate = new Date(activeTo + 'T23:59:59.999Z').toISOString();

      const data = await adminService.getAuditLogs(params);
      setLogs(data);
    } catch (err) {
      console.error(err);
      setError('Failed to fetch security audit trail.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const handleResetFilters = () => {
    setUserFilter('');
    setActionFilter('');
    setEntityFilter('');
    setFromDate('');
    setToDate('');
    fetchLogs({ userName: '', action: '', entity: '', fromDate: '', toDate: '' });
  };

  const getActionBadge = (action) => {
    if (action.includes('CREATE') || action.includes('REGISTER')) {
      return <span className="px-2 py-0.5 rounded text-xs font-mono font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">{action}</span>;
    }
    if (action.includes('UPDATE') || action.includes('ASSIGN') || action.includes('ADJUST')) {
      return <span className="px-2 py-0.5 rounded text-xs font-mono font-bold bg-blue-500/10 text-blue-400 border border-blue-500/20">{action}</span>;
    }
    if (action.includes('DELETE') || action.includes('DEACTIVATE')) {
      return <span className="px-2 py-0.5 rounded text-xs font-mono font-bold bg-red-500/10 text-red-400 border border-red-500/20">{action}</span>;
    }
    return <span className="px-2 py-0.5 rounded text-xs font-mono font-bold bg-purple-500/10 text-purple-400 border border-purple-500/20">{action}</span>;
  };

  return (
    <AdminLayout 
      title="Security & Audit Trail" 
      subtitle="Immutable record of user actions, administrative mutations, and API events"
    >
      {/* Top Filter Bar */}
      <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl space-y-4 shadow-xl">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-white flex items-center gap-2">
            <Filter className="w-4 h-4 text-brand-400" />
            Filter Audit Ledger
          </h3>
          <div className="flex items-center gap-2">
            <button
              onClick={handleResetFilters}
              className="text-xs text-slate-400 hover:text-white px-2.5 py-1 rounded-lg hover:bg-white/5 transition-colors"
            >
              Reset Filters
            </button>
            <button
              onClick={fetchLogs}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white text-xs font-semibold shadow-sm"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
              <span>Apply Filters</span>
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          <div>
            <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">User Name</label>
            <input
              type="text"
              placeholder="e.g. System Admin"
              value={userFilter}
              onChange={(e) => setUserFilter(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && fetchLogs()}
              className="w-full px-3 py-1.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-xs focus:ring-1 focus:ring-brand-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">Action Type</label>
            <input
              type="text"
              placeholder="e.g. CREATE, UPDATE"
              value={actionFilter}
              onChange={(e) => setActionFilter(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && fetchLogs()}
              className="w-full px-3 py-1.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-xs focus:ring-1 focus:ring-brand-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">Target Entity</label>
            <input
              type="text"
              placeholder="e.g. Machine, Shift, User"
              value={entityFilter}
              onChange={(e) => setEntityFilter(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && fetchLogs()}
              className="w-full px-3 py-1.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-xs focus:ring-1 focus:ring-brand-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">From Date</label>
            <div className="relative">
              <input
                type="date"
                value={fromDate}
                onChange={(e) => setFromDate(e.target.value)}
                onClick={(e) => e.target.showPicker?.()}
                className="w-full pl-8 pr-3 py-1.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-xs focus:ring-1 focus:ring-brand-500 focus:outline-none [color-scheme:dark] cursor-pointer"
              />
              <Calendar className="w-3.5 h-3.5 text-brand-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">To Date</label>
            <div className="relative">
              <input
                type="date"
                value={toDate}
                onChange={(e) => setToDate(e.target.value)}
                onClick={(e) => e.target.showPicker?.()}
                className="w-full pl-8 pr-3 py-1.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-xs focus:ring-1 focus:ring-brand-500 focus:outline-none [color-scheme:dark] cursor-pointer"
              />
              <Calendar className="w-3.5 h-3.5 text-brand-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>
        </div>

        {/* Quick Date Presets */}
        <div className="flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-white/5 text-[11px]">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-slate-400 font-medium">Quick Presets:</span>
            <button
              type="button"
              onClick={() => {
                const today = new Date().toISOString().slice(0, 10);
                setFromDate(today);
                setToDate(today);
                fetchLogs({ fromDate: today, toDate: today });
              }}
              className="px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-slate-300 hover:text-white border border-white/5 transition-colors"
            >
              Today
            </button>
            <button
              type="button"
              onClick={() => {
                const to = new Date().toISOString().slice(0, 10);
                const from = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
                setFromDate(from);
                setToDate(to);
                fetchLogs({ fromDate: from, toDate: to });
              }}
              className="px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-slate-300 hover:text-white border border-white/5 transition-colors"
            >
              Last 7 Days
            </button>
            <button
              type="button"
              onClick={() => {
                const to = new Date().toISOString().slice(0, 10);
                const from = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
                setFromDate(from);
                setToDate(to);
                fetchLogs({ fromDate: from, toDate: to });
              }}
              className="px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-slate-300 hover:text-white border border-white/5 transition-colors"
            >
              Last 30 Days
            </button>
            {(fromDate || toDate) && (
              <button
                type="button"
                onClick={() => {
                  setFromDate('');
                  setToDate('');
                  fetchLogs({ fromDate: '', toDate: '' });
                }}
                className="px-2.5 py-1 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/20 transition-colors"
              >
                Clear Dates
              </button>
            )}
          </div>
          <span className="text-slate-400">
            Showing <strong className="text-brand-400">{logs.length}</strong> events
          </span>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Audit Log Table */}
      <div className="bg-slate-900/60 border border-white/10 rounded-2xl overflow-hidden backdrop-blur-xl shadow-xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-white/10 bg-white/5 text-xs uppercase tracking-wider text-slate-400">
                <th className="py-3.5 px-4 font-semibold">Timestamp (UTC)</th>
                <th className="py-3.5 px-4 font-semibold">User</th>
                <th className="py-3.5 px-4 font-semibold">Action</th>
                <th className="py-3.5 px-4 font-semibold">Entity & Target ID</th>
                <th className="py-3.5 px-4 font-semibold">Result</th>
                <th className="py-3.5 px-4 font-semibold text-right">Client IP</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 text-sm font-mono">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400 font-sans">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto text-brand-400 mb-2" />
                    Querying audit logs ledger...
                  </td>
                </tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-400 font-sans">
                    No audit records match the applied criteria.
                  </td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id} className="hover:bg-white/[0.02] transition-colors">
                    <td className="py-3.5 px-4 text-xs text-slate-300">
                      {new Date(log.timestamp).toLocaleString()}
                    </td>
                    <td className="py-3.5 px-4 font-sans font-medium text-white">
                      <div className="flex items-center gap-2">
                        <User className="w-3.5 h-3.5 text-brand-400" />
                        <span>{log.userName}</span>
                      </div>
                    </td>
                    <td className="py-3.5 px-4">
                      {getActionBadge(log.action)}
                    </td>
                    <td className="py-3.5 px-4 text-xs">
                      <div className="flex items-center gap-1.5 font-sans">
                        <Database className="w-3.5 h-3.5 text-cyan-400" />
                        <span className="font-semibold text-white">{log.entity}</span>
                        {log.entityId && (
                          <span className="text-slate-400 font-mono text-[11px] truncate max-w-[150px]">
                            ({log.entityId})
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-3.5 px-4">
                      {log.success ? (
                        <span className="inline-flex items-center gap-1 text-xs text-emerald-400 font-sans font-semibold">
                          <CheckCircle2 className="w-3.5 h-3.5" /> Success
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-xs text-red-400 font-sans font-semibold">
                          <XCircle className="w-3.5 h-3.5" /> Failed
                        </span>
                      )}
                    </td>
                    <td className="py-3.5 px-4 text-right text-xs text-slate-400">
                      <div className="inline-flex items-center gap-1">
                        <Globe className="w-3 h-3 text-slate-500" />
                        <span>{log.ipAddress || '127.0.0.1'}</span>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </AdminLayout>
  );
}

