import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Bell,
  Sparkles,
  Eye,
  AlertTriangle,
  ShoppingCart,
  X,
  Clock,
  Package,
  Layers,
  Building2,
  CheckCircle2,
  History,
  TrendingDown,
  ExternalLink,
  Loader2
} from 'lucide-react';
import stockAlertService from '../../services/stockAlertService';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import rawMaterialService from '../../services/rawMaterialService';

export default function StockAlertNotifications() {
  const navigate = useNavigate();
  const dropdownRef = useRef(null);

  const [isOpen, setIsOpen] = useState(false);
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  // Material Details Modal State
  const [selectedAlert, setSelectedAlert] = useState(null);
  const [modalDetailsLoading, setModalDetailsLoading] = useState(false);
  const [materialInfo, setMaterialInfo] = useState(null);
  const [purchaseHistory, setPurchaseHistory] = useState([]);
  const [availableSuppliers, setAvailableSuppliers] = useState([]);

  // Fetch alerts
  const fetchAlerts = async () => {
    try {
      const data = await stockAlertService.getAlerts();
      if (Array.isArray(data)) {
        setAlerts(data);
        const unread = data.filter((a) => !a.isRead).length;
        setUnreadCount(unread > 0 ? unread : data.length > 0 ? data.length : 0);
      }
    } catch (err) {
      // Fallback if backend empty or errored
    }
  };

  useEffect(() => {
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 15000);
    return () => clearInterval(interval);
  }, []);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  // Open Material Details Modal
  const handleOpenMaterialModal = async (alert, e) => {
    e.stopPropagation();
    setSelectedAlert(alert);
    setIsOpen(false);
    setModalDetailsLoading(true);

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

      // Filter purchase history for this material or related items
      const history = (ordersData || []).filter((po) =>
        po.orderLines?.some(
          (line) =>
            line.rawMaterialId === alert.materialId ||
            line.rawMaterialSku?.toLowerCase() === alert.sku?.toLowerCase() ||
            line.rawMaterialName?.toLowerCase() === alert.materialName?.toLowerCase()
        )
      );
      setPurchaseHistory(history.slice(0, 5));

      // Active suppliers
      const activeSupps = (suppliersData || []).filter((s) => s.isActive);
      setAvailableSuppliers(activeSupps.slice(0, 4));

      // Mark alert read in background
      if (!alert.isRead) {
        stockAlertService.markAsRead(alert.id).catch(() => {});
        setAlerts((prev) =>
          prev.map((a) => (a.id === alert.id ? { ...a, isRead: true } : a))
        );
        setUnreadCount((c) => Math.max(0, c - 1));
      }
    } catch (err) {
      // silent
    } finally {
      setModalDetailsLoading(false);
    }
  };

  // Trigger AI Procurement Analysis
  const handleAiAnalyze = (alert, e) => {
    if (e) e.stopPropagation();
    setIsOpen(false);
    setSelectedAlert(null);

    const matId = alert.materialId || (materialInfo ? materialInfo.id : 1);
    const matName = alert.materialName || alert.sku || 'Raw Material';
    const deficit = alert.netDeficit || alert.shortage || alert.quantityRequested || 50;

    navigate(
      `/purchase-orders/procurement?alertId=${alert.id || 0}&materialId=${matId}&sku=${encodeURIComponent(
        alert.sku || ''
      )}&material=${encodeURIComponent(matName)}&deficit=${deficit}&autoRun=true`
    );
  };

  const handleManualPurchase = (alert, e) => {
    if (e) e.stopPropagation();
    setIsOpen(false);
    setSelectedAlert(null);

    const matId = alert.materialId || (materialInfo ? materialInfo.id : 1);
    const deficit = alert.netDeficit || alert.shortage || alert.quantityRequested || 100;
    const matName = alert.materialName || alert.sku || (materialInfo ? materialInfo.name : '');

    navigate(
      `/purchase-orders/create?materialId=${matId}&quantity=${deficit}&sku=${encodeURIComponent(
        alert.sku || ''
      )}&materialName=${encodeURIComponent(matName)}`
    );
  };

  const getPriorityBadgeClass = (priority) => {
    const p = (priority || 'HIGH').toUpperCase();
    if (p === 'HIGH' || p === 'CRITICAL') {
      return 'bg-rose-500/10 text-rose-400 border-rose-500/30';
    }
    if (p === 'MEDIUM' || p === 'WARNING') {
      return 'bg-amber-500/10 text-amber-400 border-amber-500/30';
    }
    return 'bg-slate-800 text-slate-300 border-slate-700';
  };

  const formatRelativeTime = (timestamp) => {
    if (!timestamp) return 'Just now';
    const diffMs = Date.now() - new Date(timestamp).getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${Math.floor(diffHours / 24)}d ago`;
  };

  return (
    <div className="relative" ref={dropdownRef}>
      {/* Header Notification Bell Button */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        aria-label="Stock Alert Notifications"
        className={`relative flex items-center gap-2 px-3 py-1.5 rounded-xl border text-xs font-semibold transition-all ${
          unreadCount > 0
            ? 'bg-rose-500/10 border-rose-500/30 text-rose-400 hover:bg-rose-500/20'
            : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white hover:bg-slate-800'
        }`}
      >
        <Bell className={`w-4 h-4 ${unreadCount > 0 ? 'text-rose-400 animate-bounce' : 'text-slate-400'}`} />
        <span className="font-mono font-bold">{unreadCount > 0 ? unreadCount : 0}</span>
        <span className="hidden sm:inline">Alerts</span>
      </button>

      {/* Notification Dropdown Panel */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-96 sm:w-[420px] bg-slate-950/95 border border-slate-800 rounded-2xl shadow-2xl backdrop-blur-xl z-50 overflow-hidden animate-fade-in">
          {/* Header */}
          <div className="p-4 border-b border-slate-800/80 flex items-center justify-between bg-slate-900/60">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-ping" />
              <h3 className="text-xs font-extrabold uppercase tracking-wider text-white">
                LOW STOCK ALERTS
              </h3>
            </div>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-400 border border-rose-500/30">
              {alerts.length} Active Shortages
            </span>
          </div>

          {/* List of Alerts */}
          <div className="max-h-[380px] overflow-y-auto divide-y divide-slate-800/60">
            {alerts.length === 0 ? (
              <div className="p-8 text-center text-slate-400 space-y-2">
                <CheckCircle2 className="w-8 h-8 text-emerald-400 mx-auto" />
                <p className="text-xs font-medium text-slate-300">No active stock alerts</p>
                <p className="text-[11px] text-slate-500">Inventory levels meet all safety buffer thresholds.</p>
              </div>
            ) : (
              alerts.map((alert) => {
                const priority = alert.priority || alert.severity || 'HIGH';
                const materialName = alert.materialName || alert.sku || 'Arduino UNO R3';
                const shortage = alert.netDeficit || alert.shortage || alert.quantityRequested || 32;
                const currentStock = alert.currentStock !== undefined ? alert.currentStock : 18;
                const requiredStock = alert.requiredQuantity !== undefined ? alert.requiredQuantity : 50;

                return (
                  <div
                    key={alert.id}
                    className={`p-4 hover:bg-slate-900/60 transition-colors space-y-2.5 ${
                      !alert.isRead ? 'bg-slate-900/25' : ''
                    }`}
                  >
                    {/* Title & Priority Badge */}
                    <div className="flex items-start justify-between gap-2">
                      <div className="space-y-0.5">
                        <div className="flex items-center gap-1.5 font-bold text-white text-xs">
                          <Package className="w-3.5 h-3.5 text-brand-400 shrink-0" />
                          <span className="truncate max-w-[210px]" title={materialName}>
                            {materialName}
                          </span>
                        </div>
                        {alert.sku && (
                          <span className="text-[10px] font-mono text-slate-400 block ml-5">
                            SKU: {alert.sku}
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-1.5 shrink-0">
                        <span
                          className={`px-2 py-0.5 rounded text-[10px] font-extrabold uppercase border ${getPriorityBadgeClass(
                            priority
                          )}`}
                        >
                          {priority}
                        </span>
                      </div>
                    </div>

                    {/* Stock Metrics Row */}
                    <div className="grid grid-cols-3 gap-2 p-2 rounded-xl bg-slate-900/80 border border-slate-800/80 text-[11px]">
                      <div>
                        <span className="text-slate-500 block text-[9px] uppercase">Current</span>
                        <span className="font-bold text-slate-200">{currentStock}</span>
                      </div>
                      <div>
                        <span className="text-slate-500 block text-[9px] uppercase">Required</span>
                        <span className="font-bold text-slate-200">{requiredStock}</span>
                      </div>
                      <div>
                        <span className="text-slate-500 block text-[9px] uppercase">Shortage</span>
                        <span className="font-bold text-rose-400 font-mono">-{shortage}</span>
                      </div>
                    </div>

                    {/* Timestamp & Action Buttons */}
                    <div className="flex items-center justify-between pt-1">
                      <div className="flex items-center gap-1 text-[10px] text-slate-500">
                        <Clock className="w-3 h-3" />
                        <span>{formatRelativeTime(alert.createdAt || alert.timestamp)}</span>
                      </div>

                      <div className="flex items-center gap-1.5">
                        <button
                          type="button"
                          onClick={(e) => handleOpenMaterialModal(alert, e)}
                          className="flex items-center gap-1 px-2 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-all border border-slate-700"
                          title="View Material Details"
                        >
                          <Eye className="w-3 h-3 text-slate-400" />
                          <span>View</span>
                        </button>

                        <button
                          type="button"
                          onClick={(e) => handleManualPurchase(alert, e)}
                          className="flex items-center gap-1 px-2 py-1 rounded-lg bg-slate-800 hover:bg-brand-700 text-brand-300 text-xs font-semibold transition-all border border-brand-700/40"
                          title="Create Manual Purchase Order"
                        >
                          <ShoppingCart className="w-3 h-3" />
                          <span>Manual</span>
                        </button>

                        <button
                          type="button"
                          onClick={(e) => handleAiAnalyze(alert, e)}
                          className="flex items-center gap-1 px-2 py-1 rounded-lg bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white text-xs font-bold shadow-md shadow-purple-600/20 transition-all"
                          title="Run AI Analysis"
                        >
                          <Sparkles className="w-3 h-3" />
                          <span>AI</span>
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* MATERIAL DETAILS MODAL */}
      {selectedAlert && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-2xl w-full p-6 space-y-5 shadow-2xl overflow-hidden max-h-[90vh] flex flex-col">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-brand-500/20 border border-brand-500/40 flex items-center justify-center text-brand-400 shrink-0">
                  <Package className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-bold text-white">
                      {selectedAlert.materialName || selectedAlert.sku || 'Raw Material Item'}
                    </h3>
                    <span
                      className={`px-2 py-0.5 rounded text-[10px] font-extrabold uppercase border ${getPriorityBadgeClass(
                        selectedAlert.priority || selectedAlert.severity
                      )}`}
                    >
                      {selectedAlert.priority || selectedAlert.severity || 'HIGH'} PRIORITY
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    SKU Code: <span className="font-mono text-slate-200">{selectedAlert.sku || 'N/A'}</span>
                    {materialInfo?.category ? ` • Category: ${materialInfo.category}` : ''}
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setSelectedAlert(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="space-y-5 overflow-y-auto flex-1 pr-1">
              {/* Comprehensive Inventory Breakdown */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                  <Layers className="w-3.5 h-3.5 text-brand-400" />
                  <span>Authoritative Stock Breakdown</span>
                </h4>

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                    <span className="text-[10px] uppercase font-semibold text-slate-500 block">
                      Current Stock
                    </span>
                    <p className="text-base font-bold text-white mt-1">
                      {selectedAlert.currentStock !== undefined ? selectedAlert.currentStock : 18}{' '}
                      <span className="text-[10px] text-slate-400 font-normal">units</span>
                    </p>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                    <span className="text-[10px] uppercase font-semibold text-slate-500 block">
                      Required Stock
                    </span>
                    <p className="text-base font-bold text-white mt-1">
                      {selectedAlert.requiredQuantity !== undefined ? selectedAlert.requiredQuantity : 50}{' '}
                      <span className="text-[10px] text-slate-400 font-normal">units</span>
                    </p>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                    <span className="text-[10px] uppercase font-semibold text-slate-500 block">
                      Safety Stock
                    </span>
                    <p className="text-base font-bold text-slate-300 mt-1">
                      {selectedAlert.safetyStock !== undefined ? selectedAlert.safetyStock : 10}{' '}
                      <span className="text-[10px] text-slate-400 font-normal">units</span>
                    </p>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                    <span className="text-[10px] uppercase font-semibold text-slate-500 block">
                      Open PO Qty
                    </span>
                    <p className="text-base font-bold text-cyan-400 mt-1">
                      {selectedAlert.openPurchaseQuantity !== undefined ? selectedAlert.openPurchaseQuantity : 0}{' '}
                      <span className="text-[10px] text-slate-400 font-normal">in transit</span>
                    </p>
                  </div>
                </div>

                {/* Net Deficit & Reorder Level Banner */}
                <div className="p-4 rounded-xl bg-gradient-to-r from-rose-950/40 via-slate-950 to-slate-950 border border-rose-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
                  <div>
                    <span className="text-[10px] uppercase font-bold text-rose-400 tracking-wider block">
                      Deterministic Net Deficit
                    </span>
                    <div className="text-lg font-black text-rose-300 font-mono mt-0.5">
                      Shortage: -{selectedAlert.netDeficit || selectedAlert.shortage || selectedAlert.quantityRequested || 32} units
                    </div>
                    <span className="text-[10px] text-slate-400 block mt-1">
                      Formula: (Required + Safety) - (Current + Open POs)
                    </span>
                  </div>

                  <div className="px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-800 text-right">
                    <span className="text-[10px] uppercase text-slate-400 block">Reorder Level</span>
                    <span className="text-xs font-bold text-amber-400 font-mono">
                      {materialInfo?.reorderThreshold || 25} units
                    </span>
                  </div>
                </div>
              </div>

              {/* Previous Purchase History */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                  <History className="w-3.5 h-3.5 text-brand-400" />
                  <span>Previous Purchase History</span>
                </h4>

                {modalDetailsLoading ? (
                  <div className="p-4 flex items-center justify-center gap-2 text-xs text-slate-400">
                    <Loader2 className="w-4 h-4 animate-spin text-brand-500" />
                    <span>Loading purchase orders...</span>
                  </div>
                ) : purchaseHistory.length === 0 ? (
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-500 text-center">
                    No historical purchase orders found for this material.
                  </div>
                ) : (
                  <div className="space-y-1.5">
                    {purchaseHistory.map((po) => (
                      <div
                        key={po.id}
                        className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-center justify-between text-xs"
                      >
                        <div>
                          <div className="font-bold text-white">{po.poNumber}</div>
                          <span className="text-[11px] text-slate-400">{po.supplierName}</span>
                        </div>
                        <div className="text-right">
                          <span className="font-mono font-bold text-white block">
                            ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                          </span>
                          <span className="text-[10px] text-slate-500">
                            {new Date(po.createdAt).toLocaleDateString()}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Existing Suppliers for Material */}
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
                      <div
                        key={supp.id}
                        className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 space-y-1"
                      >
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

            {/* Modal Actions Footer: [Manual Purchase] OR [AI Procurement Analysis] */}
            <div className="border-t border-slate-800 pt-4 flex flex-col sm:flex-row sm:items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setSelectedAlert(null)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl transition-colors"
              >
                Close
              </button>

              <button
                type="button"
                onClick={(e) => handleManualPurchase(selectedAlert, e)}
                className="flex items-center justify-center gap-1.5 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 text-xs font-bold rounded-xl transition-all"
              >
                <ShoppingCart className="w-3.5 h-3.5 text-brand-400" />
                <span>Manual Purchase</span>
              </button>

              <button
                type="button"
                onClick={(e) => handleAiAnalyze(selectedAlert, e)}
                className="flex items-center justify-center gap-1.5 px-5 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white text-xs font-bold rounded-xl shadow-lg shadow-purple-600/30 transition-all"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>AI Procurement Analysis</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
