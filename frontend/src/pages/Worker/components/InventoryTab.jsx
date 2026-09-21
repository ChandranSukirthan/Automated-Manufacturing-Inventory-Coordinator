import React from 'react';
import {
  Search,
  AlertTriangle,
  CheckCircle,
  Clock,
  Trash2,
  Package,
  PlusCircle
} from 'lucide-react';
import { TableSkeleton } from './SkeletonLoader';
import EmptyState from './EmptyState';

/* ── Stock level mini gauge ─────────────────────────────────── */
function StockGauge({ current, reorder }) {
  const max = Math.max(reorder * 3, current, 1);
  const pct = Math.min((current / max) * 100, 100);
  const color =
    current <= reorder * 0.5
      ? 'bg-rose-500'
      : current <= reorder
        ? 'bg-amber-500'
        : 'bg-emerald-500';

  return (
    <div className="flex items-center gap-2">
      <span className="font-semibold text-slate-100 tabular-nums">{current}</span>
      <div className="w-20 h-1.5 rounded-full bg-slate-800 overflow-hidden">
        <div
          className={`h-full rounded-full gauge-fill ${color}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

export default function InventoryTab({
  loading,
  filteredItems,
  searchQuery,
  setSearchQuery,
  alerts,
  triggeringAi,
  onTriggerAi,
  onDeleteItem,
  onShowAddModal,
}) {
  return (
    <div className="space-y-4 tab-slide-in">
      {/* Search + Add button bar */}
      <div className="flex items-center gap-3">
        <div className="flex-1 flex items-center gap-3 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 focus-within:border-cyan-500/50 transition">
          <Search className="w-4 h-4 text-slate-500" />
          <input
            type="text"
            placeholder="Search by SKU, item name, or category..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="bg-transparent border-none text-sm text-slate-200 placeholder-slate-500 focus:outline-none w-full"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="text-xs text-slate-500 hover:text-slate-300 transition"
            >
              Clear
            </button>
          )}
        </div>
        <button
          onClick={onShowAddModal}
          className="flex items-center gap-2 px-4 py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-cyan-500/20 shrink-0"
        >
          <PlusCircle className="w-4 h-4" />
          Add Item
        </button>
      </div>

      {/* Loading state */}
      {loading ? (
        <TableSkeleton rows={6} cols={7} />
      ) : filteredItems.length === 0 ? (
        <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
          <EmptyState
            icon={searchQuery ? 'search' : 'package'}
            title={searchQuery ? 'No matches found' : 'No inventory items yet'}
            description={
              searchQuery
                ? `No records match "${searchQuery}". Try a different keyword.`
                : 'Add your first raw material item to start tracking inventory.'
            }
            actionLabel={!searchQuery ? 'Add Stock Item' : undefined}
            onAction={!searchQuery ? onShowAddModal : undefined}
          />
        </div>
      ) : (
        <>
          {/* Result count */}
          <p className="text-xs text-slate-500">
            Showing <span className="text-slate-300 font-semibold">{filteredItems.length}</span> item{filteredItems.length !== 1 ? 's' : ''}
          </p>

          {/* Table */}
          <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
            <table className="w-full text-left text-sm text-slate-300">
              <thead className="bg-slate-950/80 border-b border-slate-800 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">SKU Code</th>
                  <th className="px-6 py-3.5">Item Name</th>
                  <th className="px-6 py-3.5">Category</th>
                  <th className="px-6 py-3.5">Current Stock</th>
                  <th className="px-6 py-3.5">Reorder Level</th>
                  <th className="px-6 py-3.5">Status</th>
                  <th className="px-6 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredItems.map((item) => {
                  const isLow = Number(item.stockLevel) <= Number(item.reorderThreshold);
                  const hasActiveAlert = alerts.some(
                    (a) =>
                      a.sku?.toLowerCase() === item.sku?.toLowerCase() &&
                      ['Pending', 'Processing', 'Acknowledged'].includes(a.status)
                  );

                  return (
                    <tr
                      key={item.id}
                      className={`transition hover:bg-slate-800/30 ${isLow ? 'border-l-2 border-l-amber-500/60' : ''}`}
                    >
                      <td className="px-6 py-4 font-mono font-bold text-cyan-400 text-xs">
                        {item.sku}
                      </td>
                      <td className="px-6 py-4 font-medium text-white">{item.name}</td>
                      <td className="px-6 py-4">
                        <span className="text-xs px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 border border-slate-700">
                          {item.category || 'General'}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <StockGauge current={Number(item.stockLevel)} reorder={Number(item.reorderThreshold)} />
                      </td>
                      <td className="px-6 py-4 text-xs text-slate-400 tabular-nums">
                        {item.reorderThreshold} units
                      </td>
                      <td className="px-6 py-4">
                        {isLow ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20">
                            <AlertTriangle className="w-3 h-3" />
                            Low Stock
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                            <CheckCircle className="w-3 h-3" />
                            Optimal
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          {isLow &&
                            (hasActiveAlert ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                                <Clock className="w-3 h-3" />
                                In Progress
                              </span>
                            ) : (
                              <button
                                onClick={() => onTriggerAi(item.sku, 2000)}
                                disabled={triggeringAi}
                                className="px-3 py-1.5 rounded-lg bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 text-xs font-semibold transition disabled:opacity-50"
                              >
                                Reorder via AI
                              </button>
                            ))}
                          <button
                            onClick={() => onDeleteItem(item.id)}
                            className="p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 transition"
                            title="Delete Item"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}

