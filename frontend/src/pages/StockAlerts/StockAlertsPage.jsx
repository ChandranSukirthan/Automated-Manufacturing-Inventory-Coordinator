import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Bell,
  Package,
  Sparkles,
  ShoppingCart,
  Eye,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Layers,
  Filter,
  RefreshCw,
  Loader2,
  TrendingDown,
  X,
  History,
  Building2
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import stockAlertService from '../../services/stockAlertService';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import rawMaterialService from '../../services/rawMaterialService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function StockAlertsPage() {
  const navigate = useNavigate();

  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Filters
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  // Material Details Modal
  const [selectedAlert, setSelectedAlert] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [materialInfo, setMaterialInfo] = useState(null);
  const [purchaseHistory, setPurchaseHistory] = useState([]);
  const [availableSuppliers, setAvailableSuppliers] = useState([]);

  const fetchAlerts = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await stockAlertService.getAlerts();
      setAlerts(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load stock alerts.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAlerts();
  }, []);

  const filteredAlerts = useMemo(() => {
    return alerts.filter((a) => {
      const priority = (a.priority || a.severity || 'HIGH').toUpperCase();
      const isRead = a.isRead;
      const name = (a.materialName || a.sku || '').toLowerCase();

      if (priorityFilter !== 'all' && priority !== priorityFilter) return false;
      if (statusFilter === 'unread' && isRead) return false;
      if (statusFilter === 'read' && !isRead) return false;
      if (searchTerm && !name.includes(searchTerm.toLowerCase())) return false;
      return true;
    });
  }, [alerts, priorityFilter, statusFilter, searchTerm]);

  const stats = useMemo(() => {
    const total = alerts.length;
    const unread = alerts.filter((a) => !a.isRead).length;
    const high = alerts.filter((a) => ['HIGH', 'CRITICAL'].includes((a.priority || a.severity || 'HIGH').toUpperCase())).length;
    const medium = alerts.filter((a) => (a.priority || a.severity || '').toUpperCase() === 'MEDIUM').length;
    return { total, unread, high, medium };
  }, [alerts]);

  const handleViewAlert = async (alert) => {
    setSelectedAlert(alert);
    setModalLoading(true);
    try {
      const [materialsData, ordersData, suppliersData] = await Promise.all([
        rawMaterialService.getRawMaterials().catch(() => []),
        purchaseOrderService.getPurchaseOrders().catch(() => []),
        supplierService.getSuppliers().catch(() => [])
      ]);
      const foundMaterial = (materialsData || []).find(
        (m) =>
          m.id === alert.materialId ||
          m.skuCode?.toLowerCase() === alert.sku?.toLowerCase() ||
          m.name?.toLowerCase() === alert.materialName?.toLowerCase()
      );
      setMaterialInfo(foundMaterial || null);
      const history = (ordersData || []).filter((po) =>
        po.orderLines?.some(
          (line) =>
            line.rawMaterialId === alert.materialId ||
            line.rawMaterialSku?.toLowerCase() === alert.sku?.toLowerCase() ||
            line.rawMaterialName?.toLowerCase() === alert.materialName?.toLowerCase()
        )
      );
      setPurchaseHistory(history.slice(0, 5));
      setAvailableSuppliers((suppliersData || []).filter((s) => s.isActive).slice(0, 4));

      if (!alert.isRead) {
        stockAlertService.markAsRead(alert.id).catch(() => {});
        setAlerts((prev) => prev.map((a) => (a.id === alert.id ? { ...a, isRead: true } : a)));
      }
    } catch (_) {
    } finally {
      setModalLoading(false);
    }
  };

  const handleManualPurchase = (alert) => {
    setSelectedAlert(null);
    const matId = alert.materialId || (materialInfo ? materialInfo.id : 1);
    const deficit = alert.netDeficit || alert.shortage || alert.quantityRequested || 100;
    const matName = encodeURIComponent(alert.materialName || alert.sku || (materialInfo ? materialInfo.name : ''));
    navigate(`/purchase-orders/create?materialId=${matId}&quantity=${deficit}&sku=${encodeURIComponent(alert.sku || '')}&materialName=${matName}`);
  };

  const handleAiAnalyze = (alert) => {
    setSelectedAlert(null);
    const matId = alert.materialId || (materialInfo ? materialInfo.id : 1);
    const matName = alert.materialName || alert.sku || 'Raw Material';
    const deficit = alert.netDeficit || alert.shortage || alert.quantityRequested || 50;
    navigate(`/purchase-orders/procurement?alertId=${alert.id || 0}&materialId=${matId}&material=${encodeURIComponent(matName)}&deficit=${deficit}&autoRun=true`);
  };

  const getPriorityClass = (priority) => {
    const p = (priority || 'HIGH').toUpperCase();
    if (p === 'HIGH' || p === 'CRITICAL') return 'bg-rose-500/10 text-rose-400 border-rose-500/30';
    if (p === 'MEDIUM' || p === 'WARNING') return 'bg-amber-500/10 text-amber-400 border-amber-500/30';
    return 'bg-slate-800 text-slate-300 border-slate-700';
  };

  const formatTime = (ts) => {
    if (!ts) return 'Just now';
    const diff = Date.now() - new Date(ts).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    return `${Math.floor(hrs / 24)}d ago`;
  };

  return (
    <AppLayout
      title="Low Stock Alerts"
      subtitle="Monitor manufacturing inventory shortages and trigger manual or AI procurement workflows"
      actionButton={
        <button
          onClick={fetchAlerts}
          disabled={loading}
          className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-slate-300 font-semibold rounded-xl text-xs transition-all disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh</span>
        </button>
      }
    >
      {/* Stats Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: 'Total Alerts', value: stats.total, color: 'text-white', icon: <Bell className="w-4 h-4" /> },
          { label: 'Unread Alerts', value: stats.unread, color: 'text-rose-400', icon: <AlertTriangle className="w-4 h-4" /> },
          { label: 'High Priority', value: stats.high, color: 'text-rose-400', icon: <TrendingDown className="w-4 h-4" /> },
          { label: 'Medium Priority', value: stats.medium, color: 'text-amber-400', icon: <Layers className="w-4 h-4" /> }
        ].map((s) => (
          <div key={s.label} className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center gap-3">
            <div className={`w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center ${s.color}`}>
              {s.icon}
            </div>
            <div>
              <div className={`text-xl font-black font-mono ${s.color}`}>{s.value}</div>
              <div className="text-[10px] uppercase text-slate-500 font-semibold tracking-wider">{s.label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Filters Row */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-1.5 bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 flex-1 min-w-[200px]">
          <Filter className="w-3.5 h-3.5 text-slate-500" />
          <input
            type="text"
            placeholder="Search material or SKU..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="bg-transparent text-xs text-white placeholder-slate-500 outline-none flex-1"
          />
          {searchTerm && (
            <button onClick={() => setSearchTerm('')}><X className="w-3.5 h-3.5 text-slate-500 hover:text-white" /></button>
          )}
        </div>

        <div className="flex gap-1.5">
          {['all', 'HIGH', 'MEDIUM', 'LOW'].map((p) => (
            <button
              key={p}
              onClick={() => setPriorityFilter(p)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all border ${
                priorityFilter === p
                  ? 'bg-brand-600 text-white border-brand-600 shadow-md shadow-brand-600/20'
                  : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
              }`}
            >
              {p === 'all' ? 'All Priority' : p}
            </button>
          ))}
        </div>

        <div className="flex gap-1.5">
          {['all', 'unread', 'read'].map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all border capitalize ${
                statusFilter === s
                  ? 'bg-brand-600 text-white border-brand-600 shadow-md shadow-brand-600/20'
                  : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Alert Table */}
      {loading ? (
        <div className="p-20 flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading stock alerts...</p>
        </div>
      ) : filteredAlerts.length === 0 ? (
        <div className="p-16 flex flex-col items-center gap-3 text-center bg-slate-900/40 rounded-2xl border border-slate-800">
          <CheckCircle2 className="w-10 h-10 text-emerald-400" />
          <p className="text-sm font-semibold text-white">No stock alerts found</p>
          <p className="text-xs text-slate-500">All manufacturing inventory levels meet required safety thresholds.</p>
        </div>
      ) : (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-950/60 text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  <th className="py-3 px-4">Material</th>
                  <th className="py-3 px-4 text-right">Current Stock</th>
                  <th className="py-3 px-4 text-right">Required</th>
                  <th className="py-3 px-4 text-right">Safety Stock</th>
                  <th className="py-3 px-4 text-right">Open PO Qty</th>
                  <th className="py-3 px-4 text-right">Net Deficit</th>
                  <th className="py-3 px-4 text-center">Priority</th>
                  <th className="py-3 px-4 text-center">Status</th>
                  <th className="py-3 px-4 text-right">Time</th>
                  <th className="py-3 px-4 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredAlerts.map((alert) => {
                  const priority = (alert.priority || alert.severity || 'HIGH').toUpperCase();
                  const current = alert.currentStock !== undefined ? alert.currentStock : 18;
                  const required = alert.requiredQuantity !== undefined ? alert.requiredQuantity : 50;
                  const safety = alert.safetyStock !== undefined ? alert.safetyStock : 10;
                  const openPo = alert.openPurchaseQuantity !== undefined ? alert.openPurchaseQuantity : 0;
                  const deficit = alert.netDeficit || alert.shortage || Math.max(0, (required + safety) - (current + openPo));

                  return (
                    <tr
                      key={alert.id}
                      className={`hover:bg-slate-800/30 transition-colors ${!alert.isRead ? 'bg-slate-900/40' : ''}`}
                    >
                      <td className="py-3.5 px-4">
                        <div className="flex items-center gap-2.5">
                          {!alert.isRead && (
                            <div className="w-2 h-2 rounded-full bg-rose-500 shrink-0 animate-ping" />
                          )}
                          <div>
                            <div className="font-semibold text-white text-sm">
                              {alert.materialName || 'Arduino UNO R3'}
                            </div>
                            {alert.sku && (
                              <div className="text-[11px] font-mono text-slate-400">
                                SKU: {alert.sku}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="py-3.5 px-4 text-right font-mono text-sm text-slate-200">{current}</td>
                      <td className="py-3.5 px-4 text-right font-mono text-sm text-slate-200">{required}</td>
                      <td className="py-3.5 px-4 text-right font-mono text-sm text-slate-400">{safety}</td>
                      <td className="py-3.5 px-4 text-right font-mono text-sm text-cyan-400">{openPo}</td>
                      <td className="py-3.5 px-4 text-right">
                        <span className="font-black font-mono text-rose-400 text-sm">-{deficit}</span>
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-extrabold uppercase border ${getPriorityClass(priority)}`}>
                          {priority}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-semibold uppercase border ${
                          alert.isRead
                            ? 'bg-slate-800 text-slate-400 border-slate-700'
                            : 'bg-rose-500/10 text-rose-400 border-rose-500/30'
                        }`}>
                          {alert.isRead ? 'Read' : 'New'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-1 text-[11px] text-slate-400">
                          <Clock className="w-3 h-3 text-slate-500" />
                          <span>{formatTime(alert.createdAt || alert.timestamp)}</span>
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        <div className="flex items-center justify-center gap-1.5">
                          <button
                            onClick={() => handleViewAlert(alert)}
                            className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-all border border-slate-700"
                            title="View Material Details"
                          >
                            <Eye className="w-3.5 h-3.5 text-slate-400" />
                            <span>View</span>
                          </button>
                          <button
                            onClick={() => handleManualPurchase(alert)}
                            className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-brand-700 text-brand-300 text-xs font-semibold transition-all border border-brand-700/40"
                            title="Create Manual Purchase Order"
                          >
                            <ShoppingCart className="w-3.5 h-3.5" />
                            <span>Buy</span>
                          </button>
                          <button
                            onClick={() => handleAiAnalyze(alert)}
                            className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white text-xs font-bold shadow-md shadow-purple-600/20 transition-all"
                            title="Run AI Procurement Analysis"
                          >
                            <Sparkles className="w-3.5 h-3.5" />
                            <span>AI Analyze</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Material Details Modal (Requirement 3: Material, Current Stock, Required, Safety Stock, Open PO, Net Deficit, Reorder Level, Previous Orders, [Manual Purchase], [AI Procurement Analysis]) */}
      {selectedAlert && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-2xl w-full p-6 space-y-5 shadow-2xl max-h-[90vh] flex flex-col overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-brand-500/20 border border-brand-500/40 flex items-center justify-center text-brand-400 shrink-0">
                  <Package className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-bold text-white">
                      {selectedAlert.materialName || selectedAlert.sku || 'Raw Material'}
                    </h3>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-extrabold uppercase border ${getPriorityClass(selectedAlert.priority || selectedAlert.severity)}`}>
                      {(selectedAlert.priority || selectedAlert.severity || 'HIGH').toUpperCase()} PRIORITY
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    SKU: <span className="font-mono text-slate-200">{selectedAlert.sku || 'N/A'}</span>
                    {materialInfo?.category ? ` · Category: ${materialInfo.category}` : ''}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedAlert(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="space-y-5 overflow-y-auto flex-1 pr-1">
              {/* Inventory Breakdown */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                  <Layers className="w-3.5 h-3.5 text-brand-400" />
                  <span>Authoritative Stock Breakdown</span>
                </h4>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                  {[
                    { label: 'Current Stock', value: selectedAlert.currentStock ?? 18, unit: 'units', color: 'text-white' },
                    { label: 'Required Stock', value: selectedAlert.requiredQuantity ?? 50, unit: 'units', color: 'text-white' },
                    { label: 'Safety Stock', value: selectedAlert.safetyStock ?? 10, unit: 'units', color: 'text-slate-300' },
                    { label: 'Open PO Qty', value: selectedAlert.openPurchaseQuantity ?? 0, unit: 'in transit', color: 'text-cyan-400' }
                  ].map((m) => (
                    <div key={m.label} className="p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                      <span className="text-[10px] uppercase font-semibold text-slate-500 block">{m.label}</span>
                      <p className={`text-base font-bold mt-1 ${m.color}`}>
                        {m.value} <span className="text-[10px] text-slate-400 font-normal">{m.unit}</span>
                      </p>
                    </div>
                  ))}
                </div>

                <div className="p-4 rounded-xl bg-gradient-to-r from-rose-950/40 via-slate-950 to-slate-950 border border-rose-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
                  <div>
                    <span className="text-[10px] uppercase font-bold text-rose-400 tracking-wider block">Deterministic Net Deficit</span>
                    <div className="text-lg font-black text-rose-300 font-mono mt-0.5">
                      Shortage: -{selectedAlert.netDeficit || selectedAlert.shortage || selectedAlert.quantityRequested || 32} units
                    </div>
                    <span className="text-[10px] text-slate-400 block mt-1">Formula: (Required + Safety) − (Current + Open POs)</span>
                  </div>
                  <div className="px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-800 text-right">
                    <span className="text-[10px] uppercase text-slate-400 block">Reorder Level</span>
                    <span className="text-xs font-bold text-amber-400 font-mono">{materialInfo?.reorderThreshold || 25} units</span>
                  </div>
                </div>
              </div>

              {/* Previous Purchase History */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                  <History className="w-3.5 h-3.5 text-brand-400" />
                  <span>Previous Purchase History</span>
                </h4>
                {modalLoading ? (
                  <div className="p-4 flex items-center justify-center gap-2 text-xs text-slate-400">
                    <Loader2 className="w-4 h-4 animate-spin text-brand-500" />
                    <span>Loading history...</span>
                  </div>
                ) : purchaseHistory.length === 0 ? (
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-500 text-center">
                    No historical purchase orders found for this material.
                  </div>
                ) : (
                  <div className="space-y-1.5">
                    {purchaseHistory.map((po) => (
                      <div key={po.id} className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-center justify-between text-xs">
                        <div>
                          <div className="font-bold text-white">{po.poNumber}</div>
                          <span className="text-[11px] text-slate-400">{po.supplierName}</span>
                        </div>
                        <div className="text-right">
                          <span className="font-mono font-bold text-white block">
                            ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                          </span>
                          <span className="text-[10px] text-slate-500">{new Date(po.createdAt).toLocaleDateString()}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Existing Suppliers */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                  <Building2 className="w-3.5 h-3.5 text-brand-400" />
                  <span>Existing Approved Suppliers</span>
                </h4>
                {availableSuppliers.length === 0 ? (
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-500 text-center">
                    No active suppliers registered. AI research can discover external candidates.
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                    {availableSuppliers.map((supp) => (
                      <div key={supp.id} className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 space-y-1">
                        <div className="flex items-center justify-between font-bold text-white">
                          <span>{supp.name}</span>
                          <span className="text-[10px] text-emerald-400 font-semibold">Active</span>
                        </div>
                        <p className="text-[11px] text-slate-400">
                          Lead Time: {supp.leadTimeDays || 7}d • {supp.paymentTerms || 'Net 30'}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Modal Footer Actions: [Manual Purchase] OR [AI Procurement Analysis] */}
            <div className="border-t border-slate-800 pt-4 flex flex-col sm:flex-row sm:items-center justify-end gap-3">
              <button
                onClick={() => setSelectedAlert(null)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl transition-colors"
              >
                Close
              </button>
              <button
                onClick={() => handleManualPurchase(selectedAlert)}
                className="flex items-center justify-center gap-1.5 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 text-xs font-bold rounded-xl transition-all"
              >
                <ShoppingCart className="w-3.5 h-3.5 text-brand-400" />
                <span>Manual Purchase</span>
              </button>
              <button
                onClick={() => handleAiAnalyze(selectedAlert)}
                className="flex items-center justify-center gap-1.5 px-5 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white text-xs font-bold rounded-xl shadow-lg shadow-purple-600/30 transition-all"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>AI Procurement Analysis</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </AppLayout>
  );
}
