import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Package,
  AlertTriangle,
  QrCode,
  Activity,
  Bot,
  PlusCircle,
  ArrowRight,
  Clock,
  CheckCircle2,
  ScanLine,
  RefreshCw,
  TrendingDown,
  Layers
} from 'lucide-react';
import { formatColomboDate } from '../../../utils/locale.js';
import EmptyState from './EmptyState';

export default function OverviewTab({
  items = [],
  rolls = [],
  alerts = [],
  stockLevels = [],
  lowStockItems = [],
  activeAlerts = [],
  onShowAddModal,
  onShowAlertModal,
  onTriggerAi,
  onUpdateAlertStatus,
  triggeringAi = false,
  loading = false,
}) {
  const navigate = useNavigate();

  return (
    <div className="space-y-6 tab-slide-in">
      {/* ── Quick Actions Station ──────────────────────────────── */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-wider text-slate-300">
              Floor Worker Quick Actions
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              One-click station for frequent warehouse and floor tasks
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
          <button
            type="button"
            onClick={onShowAlertModal}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-amber-500/30 bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 text-xs font-medium transition group"
          >
            <AlertTriangle className="w-5 h-5 mb-2 text-amber-400 group-hover:scale-110 transition-transform" />
            <span>Log Stock Alert</span>
          </button>

          <button
            type="button"
            onClick={onShowAddModal}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-cyan-500/30 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-300 text-xs font-medium transition group"
          >
            <PlusCircle className="w-5 h-5 mb-2 text-cyan-400 group-hover:scale-110 transition-transform" />
            <span>Add Stock Item</span>
          </button>

          <button
            type="button"
            onClick={() => navigate('/inventory/rolls')}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-blue-500/30 bg-blue-500/10 hover:bg-blue-500/20 text-blue-300 text-xs font-medium transition group"
          >
            <QrCode className="w-5 h-5 mb-2 text-blue-400 group-hover:scale-110 transition-transform" />
            <span>Scan / Rolls</span>
          </button>

          <button
            type="button"
            onClick={() => navigate('/worker/replenishment')}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-purple-500/30 bg-purple-500/10 hover:bg-purple-500/20 text-purple-300 text-xs font-medium transition group"
          >
            <RefreshCw className="w-5 h-5 mb-2 text-purple-400 group-hover:scale-110 transition-transform" />
            <span>Replenishment</span>
          </button>

          <button
            type="button"
            onClick={() => navigate('/inventory')}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-slate-700 bg-slate-800/60 hover:bg-slate-800 text-slate-300 text-xs font-medium transition group"
          >
            <Package className="w-5 h-5 mb-2 text-slate-400 group-hover:scale-110 transition-transform" />
            <span>Full Inventory</span>
          </button>

          <button
            type="button"
            onClick={() => navigate('/agent-workflows')}
            className="flex flex-col items-center justify-center p-3.5 rounded-xl border border-emerald-500/30 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 text-xs font-medium transition group"
          >
            <Bot className="w-5 h-5 mb-2 text-emerald-400 group-hover:scale-110 transition-transform" />
            <span>AI Workflows</span>
          </button>
        </div>
      </div>

      {/* ── Two-Column Operational Hub ────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Critical & Low Stock Materials Widget */}
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <TrendingDown className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-white">Critical & Low Stock Items</h3>
                  <p className="text-[11px] text-slate-500">Materials below reorder safety thresholds</p>
                </div>
              </div>
              <span className={`text-xs px-2 py-0.5 rounded-full font-bold border ${
                lowStockItems.length > 0
                  ? 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                  : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
              }`}>
                {lowStockItems.length} requiring action
              </span>
            </div>

            {lowStockItems.length === 0 ? (
              <div className="py-8 text-center">
                <CheckCircle2 className="w-10 h-10 text-emerald-400 mx-auto mb-2 opacity-80" />
                <p className="text-sm font-semibold text-slate-300">All inventory levels healthy</p>
                <p className="text-xs text-slate-500 mt-1">
                  No stock items are currently at or below their safety reorder levels.
                </p>
              </div>
            ) : (
              <div className="divide-y divide-slate-800/80 mt-2">
                {lowStockItems.slice(0, 5).map((item) => {
                  const isZero = Number(item.stockLevel) === 0;
                  return (
                    <div key={item.id} className="py-3 flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-xs font-semibold text-cyan-300 truncate">
                            {item.sku}
                          </span>
                          <span className={`text-[10px] px-1.5 py-0.2 rounded font-bold uppercase tracking-wider ${
                            isZero ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30' : 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                          }`}>
                            {isZero ? 'OUT OF STOCK' : 'LOW'}
                          </span>
                        </div>
                        <p className="text-xs text-slate-400 truncate mt-0.5">{item.name}</p>
                        <p className="text-[11px] text-slate-500 mt-0.5">
                          Stock: <span className="font-bold text-white">{item.stockLevel}</span> / Reorder: {item.reorderThreshold}
                        </p>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        <button
                          type="button"
                          disabled={triggeringAi}
                          onClick={() => {
                            const deficit = Math.max(Number(item.reorderThreshold) * 2 - Number(item.stockLevel), 100);
                            onTriggerAi(item.sku, deficit);
                          }}
                          className="px-2.5 py-1.5 rounded-lg border border-cyan-500/30 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-300 text-xs font-semibold transition flex items-center gap-1.5 disabled:opacity-50"
                          title="Trigger Autonomous Agent Replenishment"
                        >
                          <Bot className="w-3.5 h-3.5" />
                          <span>AI Restock</span>
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="pt-3 mt-3 border-t border-slate-800 flex justify-between items-center text-xs">
            <span className="text-slate-500">
              {lowStockItems.length > 5 ? `+ ${lowStockItems.length - 5} more low stock items` : ''}
            </span>
            <button
              type="button"
              onClick={() => navigate('/inventory/stock-levels')}
              className="text-cyan-400 hover:text-cyan-300 font-medium inline-flex items-center gap-1 transition"
            >
              <span>View Stock Levels & Burn Rates</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Active Stock Alerts Widget */}
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
                  <AlertTriangle className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-white">Active Stock Alerts</h3>
                  <p className="text-[11px] text-slate-500">Floor replenishment requests in progress</p>
                </div>
              </div>
              <span className={`text-xs px-2 py-0.5 rounded-full font-bold border ${
                activeAlerts.length > 0
                  ? 'bg-rose-500/10 text-rose-400 border-rose-500/30'
                  : 'bg-slate-800 text-slate-400 border-slate-700'
              }`}>
                {activeAlerts.length} active
              </span>
            </div>

            {activeAlerts.length === 0 ? (
              <div className="py-8 text-center">
                <CheckCircle2 className="w-10 h-10 text-slate-600 mx-auto mb-2" />
                <p className="text-sm font-semibold text-slate-300">No active stock alerts</p>
                <p className="text-xs text-slate-500 mt-1">
                  Floor operations are normal. You can log an alert anytime if material is low.
                </p>
              </div>
            ) : (
              <div className="divide-y divide-slate-800/80 mt-2">
                {activeAlerts.slice(0, 5).map((alert) => (
                  <div key={alert.id} className="py-3 flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs font-semibold text-white truncate">
                          {alert.sku}
                        </span>
                        <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider border ${
                          alert.status === 'Pending'
                            ? 'bg-amber-500/20 text-amber-300 border-amber-500/30'
                            : alert.status === 'Processing'
                            ? 'bg-blue-500/20 text-blue-300 border-blue-500/30'
                            : 'bg-cyan-500/20 text-cyan-300 border-cyan-500/30'
                        }`}>
                          {alert.status}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Requested: <span className="font-bold text-slate-200">{alert.quantityRequested}</span> units ({alert.packagingType || 'Roll'})
                      </p>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        {formatColomboDate(alert.createdAt)}
                      </p>
                    </div>

                    <div className="shrink-0">
                      {alert.status === 'Pending' && (
                        <button
                          type="button"
                          onClick={() => onUpdateAlertStatus(alert.id, 'Processing')}
                          className="px-2.5 py-1 text-[11px] rounded-lg border border-blue-500/30 bg-blue-500/10 hover:bg-blue-500/20 text-blue-300 font-medium transition"
                        >
                          Mark Processing
                        </button>
                      )}
                      {alert.status === 'Processing' && (
                        <button
                          type="button"
                          onClick={() => onUpdateAlertStatus(alert.id, 'Resolved')}
                          className="px-2.5 py-1 text-[11px] rounded-lg border border-emerald-500/30 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 font-medium transition"
                        >
                          Resolve
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="pt-3 mt-3 border-t border-slate-800 flex justify-between items-center text-xs">
            <span className="text-slate-500">
              {activeAlerts.length > 5 ? `+ ${activeAlerts.length - 5} more alerts` : ''}
            </span>
            <button
              type="button"
              onClick={() => navigate('/inventory/low-stock')}
              className="text-cyan-400 hover:text-cyan-300 font-medium inline-flex items-center gap-1 transition"
            >
              <span>View All Stock Alerts</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      </div>

      {/* ── Recent Inventory Rolls & QR Tracking ───────────────── */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 shadow-sm">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800 mb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400">
              <QrCode className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white">Recent Inventory Rolls</h3>
              <p className="text-[11px] text-slate-500">Physical barcode / QR tracked rolls on the warehouse floor</p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => navigate('/inventory/rolls')}
            className="text-xs text-cyan-400 hover:text-cyan-300 font-medium inline-flex items-center gap-1 transition"
          >
            <span>Rolls & QR Scanner</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {rolls.length === 0 ? (
          <div className="py-6 text-center text-slate-500 text-xs">
            No physical rolls registered yet. Use the "Scan / Rolls" quick action to register rolls.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-950/40 text-[11px] uppercase tracking-wider text-slate-500 border-b border-slate-800/80">
                <tr>
                  <th className="py-2.5 px-3">Roll Identifier</th>
                  <th className="py-2.5 px-3">Batch ID</th>
                  <th className="py-2.5 px-3">Material</th>
                  <th className="py-2.5 px-3">Quantity</th>
                  <th className="py-2.5 px-3">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {rolls.slice(0, 5).map((roll) => (
                  <tr key={roll.id} className="hover:bg-slate-800/30 transition">
                    <td className="py-2.5 px-3 font-mono font-semibold text-cyan-300">
                      {roll.rollIdentifier || `ROLL-${roll.id}`}
                    </td>
                    <td className="py-2.5 px-3 font-mono text-slate-400">{roll.batchId || '—'}</td>
                    <td className="py-2.5 px-3 text-slate-200">{roll.rawMaterialName || `Material #${roll.rawMaterialId}`}</td>
                    <td className="py-2.5 px-3 font-semibold text-white">{roll.currentQuantity ?? roll.initialQuantity ?? 0} units</td>
                    <td className="py-2.5 px-3">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-cyan-500/10 text-cyan-300 border border-cyan-500/20">
                        {roll.status || 'Available'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

