import React from 'react';
import { ArrowDownRight, ArrowUpRight, Clock } from 'lucide-react';
import { TableSkeleton } from './SkeletonLoader';
import EmptyState from './EmptyState';

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

export default function HistoryTab({
  loading,
  rawMaterials,
  selectedHistoryMaterialId,
  onSelectMaterial,
  historyItems,
}) {
  return (
    <div className="space-y-4 tab-slide-in">
      {/* Material selector chips */}
      <div className="space-y-2">
        <label className="text-xs text-slate-400 font-medium">Select Material:</label>
        <div className="flex flex-wrap gap-2">
          {rawMaterials.map((m) => {
            const isActive = selectedHistoryMaterialId === m.id;
            return (
              <button
                key={m.id}
                onClick={() => onSelectMaterial(m.id)}
                className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition ${
                  isActive
                    ? 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-300'
                }`}
              >
                <span className="font-mono">{m.skuCode}</span>
                <span className="ml-1.5 text-slate-500">—</span>
                <span className="ml-1.5">{m.name}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* History table */}
      {loading ? (
        <TableSkeleton rows={5} cols={7} />
      ) : historyItems.length === 0 ? (
        <div className="border border-slate-800 rounded-2xl bg-slate-900/60">
          <EmptyState
            icon="file"
            title="No transactions recorded"
            description="Transaction history will appear here once stock movements are logged for this material."
          />
        </div>
      ) : (
        <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-slate-950/80 border-b border-slate-800 text-xs font-semibold text-slate-400 uppercase tracking-wider">
              <tr>
                <th className="px-6 py-3.5">Date</th>
                <th className="px-6 py-3.5">Type</th>
                <th className="px-6 py-3.5">Quantity</th>
                <th className="px-6 py-3.5">Previous Stock</th>
                <th className="px-6 py-3.5">New Stock</th>
                <th className="px-6 py-3.5">Reason / Notes</th>
                <th className="px-6 py-3.5">Logged By</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {historyItems.map((h, i) => {
                const isReceived =
                  h.transactionType === 'RECEIVED' || h.transactionType === 'Received';

                return (
                  <tr
                    key={i}
                    className={`transition hover:bg-slate-800/30 ${
                      i % 2 === 1 ? 'bg-slate-900/30' : ''
                    }`}
                  >
                    <td className="px-6 py-3">
                      <div className="flex flex-col">
                        <span className="text-xs text-slate-300">
                          {new Date(h.date).toLocaleDateString()}
                        </span>
                        <span className="text-[10px] text-slate-500 flex items-center gap-1 mt-0.5">
                          <Clock className="w-2.5 h-2.5" />
                          {relativeTime(h.date)}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-3">
                      <span
                        className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded ${
                          isReceived
                            ? 'bg-emerald-500/20 text-emerald-400'
                            : 'bg-blue-500/20 text-blue-400'
                        }`}
                      >
                        {isReceived ? (
                          <ArrowDownRight className="w-3 h-3" />
                        ) : (
                          <ArrowUpRight className="w-3 h-3" />
                        )}
                        {h.transactionType}
                      </span>
                    </td>
                    <td className="px-6 py-3 font-semibold text-slate-200 tabular-nums">
                      {h.quantity} KG
                    </td>
                    <td className="px-6 py-3 text-xs text-slate-400 tabular-nums">
                      {h.previousStock} KG
                    </td>
                    <td className="px-6 py-3 font-bold text-white tabular-nums">{h.newStock} KG</td>
                    <td className="px-6 py-3 text-xs text-slate-300 max-w-[200px] truncate">
                      {h.reason || '—'}
                    </td>
                    <td className="px-6 py-3 text-xs text-slate-500">{h.user || '—'}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

