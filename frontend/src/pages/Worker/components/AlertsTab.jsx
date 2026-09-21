import React, { useState, useMemo } from 'react';
import {
  Clock,
  CheckCircle2,
  AlertTriangle,
  MessageSquare,
  XCircle,
  Eye,
  PlusCircle,
} from 'lucide-react';
import { CardSkeleton } from './SkeletonLoader';
import EmptyState from './EmptyState';

/* ── Filter chip definitions ────────────────────────────────── */
const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'Pending', label: 'Pending', color: 'amber' },
  { key: 'Processing', label: 'Processing', color: 'blue' },
  { key: 'Acknowledged', label: 'Acknowledged', color: 'cyan' },
  { key: 'Resolved', label: 'Resolved', color: 'emerald' },
  { key: 'Dismissed', label: 'Dismissed', color: 'slate' },
];

/* ── Left accent border color ───────────────────────────────── */
function alertBorderColor(status) {
  switch (status) {
    case 'Pending': return 'border-l-amber-500';
    case 'Processing': return 'border-l-blue-500';
    case 'Acknowledged': return 'border-l-cyan-500';
    case 'Resolved': return 'border-l-emerald-500';
    case 'Dismissed': return 'border-l-slate-600';
    default: return 'border-l-slate-700';
  }
}

function statusBadgeClass(status) {
  switch (status) {
    case 'Pending': return 'bg-amber-500/20 text-amber-300 border-amber-500/30';
    case 'Processing': return 'bg-blue-500/20 text-blue-300 border-blue-500/30';
    case 'Acknowledged': return 'bg-cyan-500/20 text-cyan-300 border-cyan-500/30';
    case 'Resolved': return 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30';
    case 'Dismissed': return 'bg-slate-700/40 text-slate-400 border-slate-600/30';
    default: return 'bg-slate-700/40 text-slate-400 border-slate-600/30';
  }
}

function statusIcon(status) {
  switch (status) {
    case 'Pending': return <Clock className="w-3 h-3" />;
    case 'Processing': return <AlertTriangle className="w-3 h-3" />;
    case 'Acknowledged': return <Eye className="w-3 h-3" />;
    case 'Resolved': return <CheckCircle2 className="w-3 h-3" />;
    case 'Dismissed': return <XCircle className="w-3 h-3" />;
    default: return <MessageSquare className="w-3 h-3" />;
  }
}

/* ── Relative time helper ───────────────────────────────────── */
function relativeTime(ts) {
  const diff = Date.now() - new Date(ts).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

export default function AlertsTab({
  loading,
  alerts,
  onUpdateAlertStatus,
  onShowAddModal,
}) {
  const [filter, setFilter] = useState('all');

  const counts = useMemo(() => {
    const c = { all: alerts.length };
    FILTERS.forEach((f) => {
      if (f.key !== 'all') c[f.key] = alerts.filter((a) => a.status === f.key).length;
    });
    return c;
  }, [alerts]);

  const filtered = useMemo(() => {
    const list = filter === 'all' ? alerts : alerts.filter((a) => a.status === filter);
    return [...list].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  }, [alerts, filter]);

  return (
    <div className="space-y-4 tab-slide-in">
      {/* Header bar */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
        {/* Filter chips */}
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((f) => {
            const isActive = filter === f.key;
            const count = counts[f.key] || 0;
            return (
              <button
                key={f.key}
                onClick={() => setFilter(f.key)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition ${
                  isActive
                    ? 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-300'
                }`}
              >
                {f.label}
                <span
                  className={`text-[10px] px-1.5 py-0.5 rounded-full font-bold ${
                    isActive ? 'bg-cyan-500/20 text-cyan-300' : 'bg-slate-800 text-slate-500'
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        <button
          onClick={onShowAddModal}
          className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-amber-500/20 shrink-0"
        >
          <PlusCircle className="w-4 h-4" />
          Log Alert
        </button>
      </div>

      {/* Alert List */}
      {loading ? (
        <CardSkeleton count={4} />
      ) : filtered.length === 0 ? (
        <div className="border border-slate-800 rounded-2xl bg-slate-900/60">
          <EmptyState
            icon="alert"
            title={filter !== 'all' ? `No ${filter.toLowerCase()} alerts` : 'All clear!'}
            description={
              filter !== 'all'
                ? `No alerts with status "${filter}". Try selecting a different filter.`
                : 'No stock alerts logged. All raw material inventories are above threshold. 🎉'
            }
          />
        </div>
      ) : (
        /* Timeline-style list */
        <div className="space-y-3">
          {filtered.map((alert) => (
            <div
              key={alert.id}
              className={`p-5 rounded-2xl bg-slate-900/60 border border-slate-800 border-l-4 ${alertBorderColor(
                alert.status
              )} hover:bg-slate-900/80 transition`}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-mono font-bold text-amber-400 text-sm">
                      {alert.sku}
                    </span>
                    <span
                      className={`inline-flex items-center gap-1 text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider border ${statusBadgeClass(
                        alert.status
                      )}`}
                    >
                      {statusIcon(alert.status)}
                      {alert.status}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-1.5">
                    {alert.packagingType} • Requested:{' '}
                    <span className="text-slate-200 font-semibold">
                      {alert.quantityRequested} units
                    </span>
                  </p>
                </div>

                <div className="text-right shrink-0">
                  <span className="text-xs text-slate-500 flex items-center gap-1 justify-end">
                    <Clock className="w-3 h-3" />
                    {relativeTime(alert.timestamp)}
                  </span>
                  <span className="text-[10px] text-slate-600 block mt-0.5">
                    {new Date(alert.timestamp).toLocaleDateString()}
                  </span>
                </div>
              </div>

              <div className="flex items-center justify-between pt-3 mt-3 border-t border-slate-800/80">
                <span className="text-xs text-slate-500">
                  By: <span className="text-slate-300">{alert.workerId || 'Floor Worker'}</span>
                </span>
                <div className="flex gap-1.5">
                  {['Acknowledged', 'Resolved', 'Dismissed'].map((status) => (
                    <button
                      key={status}
                      onClick={() => onUpdateAlertStatus(alert.id, status)}
                      disabled={alert.status === status}
                      className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-medium transition ${
                        alert.status === status
                          ? 'bg-slate-800/50 text-slate-600 cursor-not-allowed'
                          : 'bg-slate-800 hover:bg-slate-700 text-slate-300'
                      }`}
                    >
                      {status === 'Acknowledged' && <Eye className="w-3 h-3" />}
                      {status === 'Resolved' && <CheckCircle2 className="w-3 h-3" />}
                      {status === 'Dismissed' && <XCircle className="w-3 h-3" />}
                      {status}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

