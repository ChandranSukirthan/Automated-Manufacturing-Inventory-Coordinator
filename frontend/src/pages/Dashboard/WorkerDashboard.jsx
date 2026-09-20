import React, { useState, useEffect } from 'react';
import {
  Package,
  AlertTriangle,
  PlusCircle,
  RefreshCw,
  Search,
  CheckCircle2,
  Clock,
  QrCode,
  Sparkles,
  Bot,
  Layers,
  ArrowRight,
  TrendingDown,
  ShieldAlert,
  LogOut,
  UserCheck
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import inventoryService from '../../services/inventoryService';

export default function WorkerDashboard() {
  const { user, logout } = useAuth();

  // State
  const [items, setItems] = useState([]);
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState('inventory'); // 'inventory', 'alerts', 'rolls', 'agent'

  // Modals
  const [showAddItemModal, setShowAddItemModal] = useState(false);
  const [newItem, setNewItem] = useState({
    sku: '',
    name: '',
    category: 'Raw Materials',
    stockLevel: 100,
    reorderThreshold: 50
  });

  const [showAddAlertModal, setShowAddAlertModal] = useState(false);
  const [newAlert, setNewAlert] = useState({
    sku: '',
    packagingType: 'Standard Roll',
    quantityRequested: 500,
    notes: ''
  });

  const [rollIdentifier, setRollIdentifier] = useState('');
  const [rollRawMaterialId, setRollRawMaterialId] = useState(1);
  const [registeredRoll, setRegisteredRoll] = useState(null);

  // AI Workflow trigger state
  const [triggeringAi, setTriggeringAi] = useState(false);
  const [aiWorkflowResult, setAiWorkflowResult] = useState(null);

  // Load Data
  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [itemsData, alertsData] = await Promise.all([
        inventoryService.getItems().catch(() => []),
        inventoryService.getAlerts().catch(() => [])
      ]);
      setItems(itemsData || []);
      setAlerts(alertsData || []);
    } catch (err) {
      setError('Unable to load inventory records. Ensure backend is running.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const showNotification = (msg) => {
    setSuccessMsg(msg);
    setTimeout(() => setSuccessMsg(''), 4000);
  };

  // Add Item Handler
  const handleAddItem = async (e) => {
    e.preventDefault();
    try {
      await inventoryService.createItem({
        ...newItem,
        stockLevel: Number(newItem.stockLevel),
        reorderThreshold: Number(newItem.reorderThreshold)
      });
      setShowAddItemModal(false);
      setNewItem({
        sku: '',
        name: '',
        category: 'Raw Materials',
        stockLevel: 100,
        reorderThreshold: 50
      });
      showNotification('Inventory item created successfully!');
      loadData();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to create inventory item');
    }
  };

  // Update Alert Status (Student 1 merged feature: PUT /api/inventory/alerts/{id})
  const handleUpdateAlertStatus = async (alertId, newStatus) => {
    try {
      await inventoryService.updateAlertStatus(alertId, newStatus);
      showNotification(`Alert status updated to "${newStatus}"!`);
      loadData();
    } catch (err) {
      setError('Failed to update alert status');
    }
  };

  // Create Alert Handler
  const handleAddAlert = async (e) => {
    e.preventDefault();
    try {
      await inventoryService.createAlert({
        sku: newAlert.sku,
        packagingType: newAlert.packagingType,
        quantityRequested: Number(newAlert.quantityRequested)
      });
      setShowAddAlertModal(false);
      setNewAlert({ sku: '', packagingType: 'Standard Roll', quantityRequested: 500, notes: '' });
      showNotification('Stock alert created successfully!');
      loadData();
    } catch (err) {
      setError('Failed to create stock alert');
    }
  };

  // Create Roll Handler
  const handleCreateRoll = async (e) => {
    e.preventDefault();
    if (!rollIdentifier.trim()) return;
    try {
      const created = await inventoryService.createRoll({
        rollIdentifier: rollIdentifier.trim(),
        rawMaterialId: Number(rollRawMaterialId)
      });
      setRegisteredRoll(created);
      setRollIdentifier('');
      showNotification(`Inventory Roll ${created.rollIdentifier || rollIdentifier} successfully registered!`);
    } catch (err) {
      setError('Failed to register inventory roll.');
    }
  };

  // Trigger Multi-Agent Workflow
  const handleTriggerAiWorkflow = async (sku, qty = 2000) => {
    setTriggeringAi(true);
    setAiWorkflowResult(null);
    try {
      const materialCode = sku || 'RM-STEEL-001';
      const result = await inventoryService.triggerWorkflow(
        `Floor Worker Stock Replenishment: Reorder ${qty} units of ${materialCode}`,
        materialCode,
        qty
      );
      setAiWorkflowResult(result);
      showNotification('Multi-Agent replenishment workflow initiated!');
    } catch (err) {
      setError('Failed to trigger AI workflow. Ensure FastAPI coordinator is running.');
    } finally {
      setTriggeringAi(false);
    }
  };

  // Calculations
  const lowStockItems = items.filter(
    (item) => Number(item.stockLevel) <= Number(item.reorderThreshold)
  );
  const activeAlerts = alerts.filter(
    (a) => !['Resolved', 'Dismissed'].includes(a.status)
  );

  const filteredItems = items.filter(
    (item) =>
      item.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.sku?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.category?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Top Navigation Bar */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-30 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400 font-bold">
            <Package className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold tracking-tight text-white flex items-center gap-2">
              Floor Worker Operations Console
              <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400 font-mono border border-cyan-500/30">
                Student 1
              </span>
            </h1>
            <p className="text-xs text-slate-400">Inventory Tracking, Alert Dispatch & AI Replenishment</p>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <button
            onClick={loadData}
            disabled={loading}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-slate-700 bg-slate-800 hover:bg-slate-700 text-xs text-slate-300 transition"
            title="Refresh Data"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-cyan-400' : ''}`} />
            Refresh
          </button>

          <div className="flex items-center gap-2 pl-3 border-l border-slate-800">
            <div className="text-right">
              <div className="text-xs font-semibold text-slate-200">{user?.fullName || 'Floor Worker'}</div>
              <div className="text-[10px] text-cyan-400 font-mono uppercase">Floor Worker</div>
            </div>
            <button
              onClick={logout}
              className="p-2 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8 space-y-6">
        {/* Banner Messages */}
        {error && (
          <div className="p-4 rounded-xl border border-rose-500/30 bg-rose-500/10 text-rose-300 text-sm flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-400" />
              <span>{error}</span>
            </div>
            <button onClick={() => setError('')} className="text-xs text-rose-400 underline">Dismiss</button>
          </div>
        )}

        {successMsg && (
          <div className="p-4 rounded-xl border border-emerald-500/30 bg-emerald-500/10 text-emerald-300 text-sm flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            <span>{successMsg}</span>
          </div>
        )}

        {/* Quick KPI Stat Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400 font-medium">Total Stock SKUs</p>
              <h3 className="text-2xl font-bold text-white mt-1">{items.length}</h3>
              <p className="text-[11px] text-slate-500 mt-1">Managed inventory items</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400">
              <Package className="w-6 h-6" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400 font-medium">Low Stock Alerts</p>
              <h3 className="text-2xl font-bold text-amber-400 mt-1">{lowStockItems.length}</h3>
              <p className="text-[11px] text-amber-500/80 mt-1">Below safety threshold</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
              <TrendingDown className="w-6 h-6" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400 font-medium">Active Warehouse Alerts</p>
              <h3 className="text-2xl font-bold text-rose-400 mt-1">{activeAlerts.length}</h3>
              <p className="text-[11px] text-slate-500 mt-1">{alerts.length} total logged alerts</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
              <ShieldAlert className="w-6 h-6" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-gradient-to-br from-cyan-950/40 to-slate-900 border border-cyan-800/40 flex items-center justify-between">
            <div>
              <p className="text-xs text-cyan-300 font-medium">Collaborative AI Agent</p>
              <h3 className="text-lg font-bold text-white mt-1">4-Agent Mesh</h3>
              <p className="text-[11px] text-cyan-400/80 mt-1">Data Extraction active</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-cyan-300">
              <Bot className="w-6 h-6" />
            </div>
          </div>
        </div>

        {/* Tab Selection */}
        <div className="flex items-center justify-between border-b border-slate-800">
          <div className="flex gap-2">
            {[
              { id: 'inventory', label: 'Inventory Items', icon: Package },
              { id: 'alerts', label: `Stock Alerts (${activeAlerts.length})`, icon: AlertTriangle },
              { id: 'rolls', label: 'Barcode & Rolls', icon: QrCode },
              { id: 'agent', label: 'AI Agent Coordinator', icon: Bot }
            ].map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition -mb-px ${
                    isActive
                      ? 'border-cyan-400 text-cyan-400'
                      : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-700'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  {tab.label}
                </button>
              );
            })}
          </div>

          {activeTab === 'inventory' && (
            <button
              onClick={() => setShowAddItemModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-cyan-500/20"
            >
              <PlusCircle className="w-4 h-4" />
              Add Stock Item
            </button>
          )}

          {activeTab === 'alerts' && (
            <button
              onClick={() => setShowAddAlertModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-amber-500/20"
            >
              <PlusCircle className="w-4 h-4" />
              Log Stock Alert
            </button>
          )}
        </div>

        {/* TAB 1: INVENTORY ITEMS */}
        {activeTab === 'inventory' && (
          <div className="space-y-4">
            {/* Search Bar */}
            <div className="flex items-center gap-3 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5">
              <Search className="w-4 h-4 text-slate-500" />
              <input
                type="text"
                placeholder="Search inventory by SKU, name, or category..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="bg-transparent text-sm text-slate-200 placeholder-slate-500 focus:outline-none w-full"
              />
            </div>

            {/* Inventory Table */}
            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
              <table className="w-full text-left text-sm text-slate-300">
                <thead className="bg-slate-900 border-b border-slate-800 text-xs uppercase tracking-wider text-slate-400">
                  <tr>
                    <th className="px-6 py-4">SKU</th>
                    <th className="px-6 py-4">Item Name</th>
                    <th className="px-6 py-4">Category</th>
                    <th className="px-6 py-4">Stock Level</th>
                    <th className="px-6 py-4">Reorder Threshold</th>
                    <th className="px-6 py-4">Health</th>
                    <th className="px-6 py-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filteredItems.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="px-6 py-12 text-center text-slate-500">
                        {loading ? 'Loading inventory data...' : 'No inventory items found.'}
                      </td>
                    </tr>
                  ) : (
                    filteredItems.map((item) => {
                      const isLow = Number(item.stockLevel) <= Number(item.reorderThreshold);
                      const isCritical = Number(item.stockLevel) <= Number(item.reorderThreshold) * 0.5;

                      return (
                        <tr key={item.id} className="hover:bg-slate-800/40 transition">
                          <td className="px-6 py-4 font-mono font-bold text-cyan-400">{item.sku}</td>
                          <td className="px-6 py-4 font-medium text-white">{item.name}</td>
                          <td className="px-6 py-4 text-slate-400">{item.category}</td>
                          <td className="px-6 py-4">
                            <span className={`font-mono font-bold ${isCritical ? 'text-rose-400' : isLow ? 'text-amber-400' : 'text-emerald-400'}`}>
                              {item.stockLevel}
                            </span>
                          </td>
                          <td className="px-6 py-4 font-mono text-slate-400">{item.reorderThreshold}</td>
                          <td className="px-6 py-4">
                            {isCritical ? (
                              <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20">
                                Critical Low
                              </span>
                            ) : isLow ? (
                              <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                                Reorder Due
                              </span>
                            ) : (
                              <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                                Adequate
                              </span>
                            )}
                          </td>
                          <td className="px-6 py-4 text-right">
                            {isLow && (
                              <button
                                onClick={() => handleTriggerAiWorkflow(item.sku, Math.max(500, item.reorderThreshold * 3))}
                                disabled={triggeringAi}
                                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-cyan-500/10 border border-cyan-500/30 text-cyan-300 hover:bg-cyan-500/20 text-xs font-semibold transition"
                              >
                                <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
                                Reorder via AI
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 2: STOCK ALERTS (Student 1's Merged Feature) */}
        {activeTab === 'alerts' && (
          <div className="space-y-4">
            <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 text-xs text-slate-400 flex items-center justify-between">
              <div>
                <span className="font-semibold text-slate-200">Alert Status Lifecycle: </span>
                Click any status button below to update warehouse alert statuses directly via the merged Student 1 endpoint (<code className="text-cyan-400">PUT /api/inventory/alerts/&#123;id&#125;</code>).
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {alerts.length === 0 ? (
                <div className="col-span-2 p-12 text-center text-slate-500 rounded-2xl border border-slate-800 bg-slate-900/40">
                  No stock alerts logged.
                </div>
              ) : (
                alerts.map((alert) => (
                  <div
                    key={alert.id}
                    className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-slate-700 transition flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center justify-between">
                        <span className="font-mono text-sm font-bold text-amber-400">{alert.sku}</span>
                        <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${
                          alert.status === 'Resolved'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : alert.status === 'Approved'
                            ? 'bg-blue-500/10 text-blue-400 border-blue-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        }`}>
                          {alert.status || 'Active'}
                        </span>
                      </div>

                      <div className="mt-3 space-y-1.5 text-xs text-slate-300">
                        <div className="flex justify-between">
                          <span className="text-slate-500">Packaging Type:</span>
                          <span>{alert.packagingType}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-500">Requested Quantity:</span>
                          <span className="font-mono font-bold text-white">{alert.quantityRequested} units</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-500">Logged At:</span>
                          <span>{alert.createdAt ? new Date(alert.createdAt).toLocaleString() : 'N/A'}</span>
                        </div>
                      </div>
                    </div>

                    <div className="mt-5 pt-4 border-t border-slate-800 flex items-center justify-between gap-2">
                      <span className="text-[11px] text-slate-500">Set Status:</span>
                      <div className="flex items-center gap-1.5">
                        {['Investigating', 'Approved', 'Resolved', 'Dismissed'].map((status) => (
                          <button
                            key={status}
                            onClick={() => handleUpdateAlertStatus(alert.id, status)}
                            className={`px-2 py-1 rounded text-[11px] font-medium transition ${
                              alert.status === status
                                ? 'bg-cyan-500 text-slate-950 font-bold'
                                : 'bg-slate-800 hover:bg-slate-700 text-slate-300'
                            }`}
                          >
                            {status}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}

        {/* TAB 3: BARCODE & INVENTORY ROLLS */}
        {activeTab === 'rolls' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400">
                  <QrCode className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Register Inventory Roll</h3>
                  <p className="text-xs text-slate-400">Generates QR Code URL via Student 1 Barcode Service</p>
                </div>
              </div>

              <form onSubmit={handleCreateRoll} className="space-y-4 pt-2">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Roll Identifier / QR Payload</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. ROLL-2026-STEEL-009"
                    value={rollIdentifier}
                    onChange={(e) => setRollIdentifier(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Raw Material Association ID</label>
                  <input
                    type="number"
                    required
                    min={1}
                    value={rollRawMaterialId}
                    onChange={(e) => setRollRawMaterialId(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                  />
                </div>

                <button
                  type="submit"
                  className="w-full py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold rounded-xl text-sm transition shadow-lg shadow-cyan-500/20"
                >
                  Generate & Register Roll
                </button>
              </form>
            </div>

            <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 flex flex-col justify-between">
              <div>
                <h3 className="text-base font-bold text-white mb-2">Registered Roll Details</h3>
                <p className="text-xs text-slate-400 mb-4">Live response from ASP.NET Barcode Engine</p>

                {registeredRoll ? (
                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-3">
                    <div className="flex justify-between text-xs">
                      <span className="text-slate-500">Roll ID:</span>
                      <span className="font-mono font-bold text-cyan-400">{registeredRoll.rollIdentifier}</span>
                    </div>
                    <div className="flex justify-between text-xs">
                      <span className="text-slate-500">Raw Material ID:</span>
                      <span>{registeredRoll.rawMaterialId}</span>
                    </div>
                    <div className="flex justify-between text-xs">
                      <span className="text-slate-500">Barcode URL:</span>
                      <span className="truncate max-w-[200px] text-cyan-400 underline">{registeredRoll.barcodeUrl || 'Generated'}</span>
                    </div>
                    {registeredRoll.barcodeUrl && (
                      <div className="mt-3 flex justify-center p-3 bg-white rounded-lg">
                        <img src={registeredRoll.barcodeUrl} alt="Roll QR Code" className="w-32 h-32" />
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="h-48 border border-dashed border-slate-800 rounded-xl flex items-center justify-center text-slate-600 text-xs">
                    No roll scanned or registered in current session.
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: AI AGENT COORDINATOR (Multi-Agent Collaboration) */}
        {activeTab === 'agent' && (
          <div className="space-y-6">
            <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-6">
              <div>
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Bot className="w-5 h-5 text-cyan-400" />
                  LangGraph 4-Student Collaborative Workflow
                </h3>
                <p className="text-xs text-slate-400 mt-1">
                  Connects Student 1 (Data Extraction) with Student 4 (Production), Student 2 (Purchasing), and Student 3 (Validation & Quality).
                </p>
              </div>

              {/* Architecture Steps Graphic */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                <div className="p-4 rounded-xl bg-cyan-950/20 border border-cyan-500/30">
                  <span className="text-[10px] font-mono text-cyan-400 uppercase font-bold">1. Student 1 (Floor Worker)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Data Extraction Agent</h4>
                  <p className="text-xs text-slate-400 mt-1">Scans stock levels, burn-rates, and lead time deficits.</p>
                </div>

                <div className="p-4 rounded-xl bg-purple-950/20 border border-purple-500/30">
                  <span className="text-[10px] font-mono text-purple-400 uppercase font-bold">2. Student 4 (Production)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Production Analysis</h4>
                  <p className="text-xs text-slate-400 mt-1">Evaluates shift targets, machine capacities & output deficits.</p>
                </div>

                <div className="p-4 rounded-xl bg-blue-950/20 border border-blue-500/30">
                  <span className="text-[10px] font-mono text-blue-400 uppercase font-bold">3. Student 2 (Purchasing)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Purchasing Agent</h4>
                  <p className="text-xs text-slate-400 mt-1">Compares rates, selects best supplier, and drafts PO.</p>
                </div>

                <div className="p-4 rounded-xl bg-emerald-950/20 border border-emerald-500/30">
                  <span className="text-[10px] font-mono text-emerald-400 uppercase font-bold">4. Student 3 (Quality)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Validation & Safety</h4>
                  <p className="text-xs text-slate-400 mt-1">Verifies quarantine status & budget gates for IT Admin signoff.</p>
                </div>
              </div>

              <div className="flex items-center gap-4 pt-2">
                <button
                  onClick={() => handleTriggerAiWorkflow('RM001', 2000)}
                  disabled={triggeringAi}
                  className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-slate-950 font-bold text-sm rounded-xl transition shadow-lg shadow-cyan-500/25"
                >
                  <Sparkles className={`w-4 h-4 ${triggeringAi ? 'animate-spin' : ''}`} />
                  {triggeringAi ? 'Executing 4-Agent Graph...' : 'Dispatch Automated Replenishment Workflow'}
                </button>
              </div>

              {/* Live Result Display */}
              {aiWorkflowResult && (
                <div className="mt-6 p-5 rounded-2xl bg-slate-950 border border-slate-800 space-y-4">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-white flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                      Workflow Executed: {aiWorkflowResult.workflow_id}
                    </h4>
                    <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                      Status: {aiWorkflowResult.status}
                    </span>
                  </div>

                  <div className="space-y-2 text-xs">
                    <p className="text-slate-400 font-semibold">Completed Agent Steps:</p>
                    <ul className="space-y-1 text-slate-300">
                      {aiWorkflowResult.completed_steps?.map((step, idx) => (
                        <li key={idx} className="flex items-center gap-2">
                          <ArrowRight className="w-3.5 h-3.5 text-cyan-400" />
                          <span>{step}</span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  {aiWorkflowResult.final_outcome && (
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-300">
                      <span className="font-semibold text-white">Final Outcome: </span>
                      {aiWorkflowResult.final_outcome}
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      {/* Modal: Add Stock Item */}
      {showAddItemModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <h3 className="text-lg font-bold text-white">Add Inventory Item</h3>
            <form onSubmit={handleAddItem} className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">SKU Code</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. RM-STEEL-002"
                  value={newItem.sku}
                  onChange={(e) => setNewItem({ ...newItem, sku: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Item Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Cold Rolled Steel Sheet"
                  value={newItem.name}
                  onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Category</label>
                <input
                  type="text"
                  required
                  value={newItem.category}
                  onChange={(e) => setNewItem({ ...newItem, category: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Initial Stock</label>
                  <input
                    type="number"
                    required
                    min={0}
                    value={newItem.stockLevel}
                    onChange={(e) => setNewItem({ ...newItem, stockLevel: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Reorder Threshold</label>
                  <input
                    type="number"
                    required
                    min={0}
                    value={newItem.reorderThreshold}
                    onChange={(e) => setNewItem({ ...newItem, reorderThreshold: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowAddItemModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs rounded-xl transition"
                >
                  Save Item
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Add Stock Alert */}
      {showAddAlertModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <h3 className="text-lg font-bold text-white">Log Warehouse Stock Alert</h3>
            <form onSubmit={handleAddAlert} className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">SKU</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. RM001"
                  value={newAlert.sku}
                  onChange={(e) => setNewAlert({ ...newAlert, sku: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Packaging Type</label>
                <input
                  type="text"
                  required
                  value={newAlert.packagingType}
                  onChange={(e) => setNewAlert({ ...newAlert, packagingType: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Quantity Requested</label>
                <input
                  type="number"
                  required
                  min={1}
                  value={newAlert.quantityRequested}
                  onChange={(e) => setNewAlert({ ...newAlert, quantityRequested: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
                />
              </div>

              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowAddAlertModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs rounded-xl transition"
                >
                  Log Alert
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
