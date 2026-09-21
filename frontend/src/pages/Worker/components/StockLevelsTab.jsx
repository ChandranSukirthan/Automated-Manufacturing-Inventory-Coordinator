import React, { useState, useMemo } from 'react';
import {
  AlertTriangle,
  CheckCircle,
  Clock,
  ArrowUpDown,
  TrendingDown,
} from 'lucide-react';
import { TableSkeleton } from './SkeletonLoader';
import EmptyState from './EmptyState';

/* ── Stock gauge bar ─────────────────────────────────────────── */
function StockGaugeBar({ current, min, max }) {
  const safeMax = Math.max(max, 1);
  const pct = Math.min((current / safeMax) * 100, 100);
  const minPct = Math.min((min / safeMax) * 100, 100);
  const color =
    current <= min * 0.5
      ? 'from-rose-500 to-rose-600'
      : current <= min
        ? 'from-amber-500 to-amber-600'
        : 'from-emerald-500 to-cyan-500';

  return (
    <div className="space-y-1">
      <div className="flex justify-between items-center">
        <span className="font-bold text-slate-100 tabular-nums text-sm">{current} KG</span>
      </div>
      <div className="relative w-full h-2 rounded-full bg-slate-800 overflow-hidden">
        <div
          className={`absolute inset-y-0 left-0 rounded-full bg-gradient-to-r ${color} gauge-fill`}
          style={{ width: `${pct}%` }}
        />
        {/* Reorder threshold marker */}
        <div
          className="absolute top-0 bottom-0 w-px bg-amber-400/60"
          style={{ left: `${minPct}%` }}
          title={`Reorder at ${min} KG`}
        />
      </div>
    </div>
  );
}

/* ── Days remaining urgency ──────────────────────────────────── */
function DaysChip({ days }) {
  const d = Number(days);
  let cls = 'text-emerald-400';
  if (d <= 3) cls = 'text-rose-400 font-bold';
  else if (d <= 7) cls = 'text-amber-400';

  return (
    <span className={`font-mono tabular-nums ${cls}`}>
      {d <= 3 && <span className="inline-block w-1.5 h-1.5 rounded-full bg-rose-500 pulse-dot mr-1.5 align-middle" />}
      {days} days
    </span>
  );
}

export default function StockLevelsTab({
  loading,
  stockLevels,
  alerts,
  triggeringAi,
  onTriggerAi,
}) {
  const [sortField, setSortField] = useState(null);
  const [sortDir, setSortDir] = useState('asc');

  const toggleSort = (field) => {
    if (sortField === field) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortField(field);
      setSortDir('asc');
    }
  };

  const sorted = useMemo(() => {
    if (!sortField) return stockLevels;
    return [...stockLevels].sort((a, b) => {
      const va = Number(a[sortField]) || 0;
      const vb = Number(b[sortField]) || 0;
      return sortDir === 'asc' ? va - vb : vb - va;
    });
  }, [stockLevels, sortField, sortDir]);

  const SortHeader = ({ field, children }) => (
    <th
      className="px-6 py-3.5 cursor-pointer select-none hover:text-slate-200 transition group"
      onClick={() => toggleSort(field)}
    >
      <div className="flex items-center gap-1">
        {children}
        <ArrowUpDown
          className={`w-3 h-3 transition ${
            sortField === field ? 'text-cyan-400' : 'text-slate-600 group-hover:text-slate-400'
          }`}
        />
      </div>
    </th>
  );

  if (loading) {
    return (
      <div className="tab-slide-in">
        <TableSkeleton rows={5} cols={8} />
      </div>
    );
  }

  if (stockLevels.length === 0) {
    return (
      <div className="tab-slide-in border border-slate-800 rounded-2xl bg-slate-900/60">
        <EmptyState
          icon="package"
          title="No stock level data"
          description="Stock levels will appear once raw materials are configured in the system."
        />
      </div>
    );
  }

  return (
    <div className="space-y-4 tab-slide-in">
      <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-800 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
          <div>
            <h3 className="text-base font-bold text-white">Stock Levels & Daily Burn Rate</h3>
            <p className="text-xs text-slate-400">
              Click column headers to sort • Gauge shows stock vs. maximum capacity
            </p>
          </div>
          <div className="flex items-center gap-3 text-xs text-slate-500">
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-emerald-500" /> Normal
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-amber-500" /> Low
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-rose-500" /> Critical
            </span>
          </div>
        </div>

        <table className="w-full text-left text-sm text-slate-300">
          <thead className="bg-slate-950/80 border-b border-slate-800 text-xs font-semibold text-slate-400 uppercase tracking-wider">
            <tr>
              <th className="px-6 py-3.5">SKU</th>
              <th className="px-6 py-3.5">Material</th>
              <SortHeader field="currentStock">Stock</SortHeader>
              <th className="px-6 py-3.5">Gauge</th>
              <SortHeader field="burnRate">Burn Rate</SortHeader>
              <SortHeader field="daysRemaining">Days Left</SortHeader>
              <th className="px-6 py-3.5">Status</th>
              <th className="px-6 py-3.5 text-right">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/60">
            {sorted.map((lvl) => {
              const isCritical = lvl.status === 'CRITICAL';
              const isLow = lvl.status === 'LOW';
              const isNeedsReorder = isCritical || isLow;
              const hasActiveAlert = alerts.some(
                (a) =>
                  a.sku?.toLowerCase() === lvl.skuCode?.toLowerCase() &&
                  ['Pending', 'Processing', 'Acknowledged'].includes(a.status)
              );

              return (
                <tr
                  key={lvl.id}
                  className={`transition hover:bg-slate-800/30 ${
                    isCritical ? 'border-l-2 border-l-rose-500/60' : isLow ? 'border-l-2 border-l-amber-500/60' : ''
                  }`}
                >
                  <td className="px-6 py-4 font-mono font-bold text-cyan-400 text-xs">
                    {lvl.skuCode}
                  </td>
                  <td className="px-6 py-4 font-medium text-white">{lvl.materialName}</td>
                  <td className="px-6 py-4 font-bold text-slate-100 tabular-nums">
                    {lvl.currentStock} KG
                  </td>
                  <td className="px-6 py-4 w-40">
                    <StockGaugeBar
                      current={lvl.currentStock}
                      min={lvl.minimumStock}
                      max={lvl.maximumStock}
                    />
                  </td>
                  <td className="px-6 py-4">
                    <span className="flex items-center gap-1 text-xs font-mono text-cyan-300">
                      <TrendingDown className="w-3 h-3 text-slate-500" />
                      {lvl.burnRate} KG/day
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <DaysChip days={lvl.daysRemaining} />
                  </td>
                  <td className="px-6 py-4">
                    {isCritical ? (
                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-rose-500/20 text-rose-400 border border-rose-500/30">
                        CRITICAL
                      </span>
                    ) : isLow ? (
                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                        LOW
                      </span>
                    ) : (
                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                        NORMAL
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-right">
                    {isNeedsReorder ? (
                      hasActiveAlert ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                          <Clock className="w-3 h-3" />
                          In Progress
                        </span>
                      ) : (
                        <button
                          onClick={() => onTriggerAi(lvl.skuCode, 2000)}
                          disabled={triggeringAi}
                          className="px-3 py-1.5 rounded-lg bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 text-xs font-semibold transition disabled:opacity-50"
                        >
                          Reorder via AI
                        </button>
                      )
                    ) : (
                      <span className="inline-flex items-center gap-1 text-xs text-emerald-400 font-semibold">
                        <CheckCircle className="w-3.5 h-3.5" /> Healthy
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

