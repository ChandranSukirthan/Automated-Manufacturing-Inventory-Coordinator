import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
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
  UserCheck,
  Trash2,
  Calendar,
  Eye,
  Activity,
  CheckCircle,
  FileText
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import inventoryService from '../../services/inventoryService';

export default function WorkerDashboard() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  // State
  const [items, setItems] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [rolls, setRolls] = useState([]);
  const [alerts, setAlerts] = useState([]);
  const [stockLevels, setStockLevels] = useState([]);
  const [historyItems, setHistoryItems] = useState([]);
  const [selectedHistoryMaterialId, setSelectedHistoryMaterialId] = useState(1);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState('inventory'); // 'inventory', 'rolls', 'stock-levels', 'alerts', 'history', 'agent'

  // Modals & Forms
  const [showAddItemModal, setShowAddItemModal] = useState(false);
  const [newItem, setNewItem] = useState({
    sku: '',
    name: '',
    category: 'Metal',
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

  // QR Lookup State
  const [qrQuery, setQrQuery] = useState('');
  const [qrSearchResult, setQrSearchResult] = useState(null);
  const [qrSearching, setQrSearching] = useState(false);

  // AI Workflow trigger state
  const [triggeringAi, setTriggeringAi] = useState(false);
  const [aiWorkflowResult, setAiWorkflowResult] = useState(null);

  // Synchronize Tab with current route pathname
  useEffect(() => {
    const path = location.pathname;
    if (path.includes('/rolls')) setActiveTab('rolls');
    else if (path.includes('/stock-levels')) setActiveTab('stock-levels');
    else if (path.includes('/low-stock')) setActiveTab('alerts');
    else if (path.includes('/history')) setActiveTab('history');
    else if (path.includes('/inventory')) setActiveTab('inventory');
  }, [location.pathname]);

  // Load Data
  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [itemsData, rawMatsData, rollsData, alertsData, levelsData] = await Promise.all([
        inventoryService.getItems().catch(() => []),
        inventoryService.getRawMaterials().catch(() => []),
        inventoryService.getRolls().catch(() => []),
        inventoryService.getAlerts().catch(() => []),
        inventoryService.getStockLevels().catch(() => [])
      ]);
      setItems(itemsData || []);
      setRawMaterials(rawMatsData || []);
      setRolls(rollsData || []);
      setAlerts(alertsData || []);
      setStockLevels(levelsData || []);

      if (rawMatsData && rawMatsData.length > 0) {
        const hist = await inventoryService.getHistory(rawMatsData[0].id).catch(() => []);
        setHistoryItems(hist || []);
      }
    } catch (err) {
      setError('Unable to load inventory records. Ensure backend is running.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const loadHistoryForMaterial = async (id) => {
    setSelectedHistoryMaterialId(id);
    try {
      const hist = await inventoryService.getHistory(id);
      setHistoryItems(hist || []);
    } catch (err) {
      setHistoryItems([]);
    }
  };

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
        category: 'Metal',
        stockLevel: 100,
        reorderThreshold: 50
      });
      showNotification('Inventory item created successfully!');
      loadData();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to create inventory item');
    }
  };

  // Delete Item Handler
  const handleDeleteItem = async (id) => {
    if (!window.confirm('Delete this inventory item?')) return;
    try {
      await inventoryService.deleteItem(id);
      showNotification('Item deleted successfully.');
      loadData();
    } catch (err) {
      setError('Failed to delete item.');
    }
  };

  // Update Alert Status
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
      loadData();
    } catch (err) {
      setError('Failed to register inventory roll.');
    }
  };

  // Delete Roll Handler
  const handleDeleteRoll = async (id) => {
    if (!window.confirm('Delete this inventory roll?')) return;
    try {
      await inventoryService.deleteRoll(id);
      showNotification('Inventory roll deleted.');
      loadData();
    } catch (err) {
      setError('Failed to delete roll.');
    }
  };

  // QR Code Search Handler
  const handleQrSearch = async (e) => {
    e.preventDefault();
    if (!qrQuery.trim()) return;
    setQrSearching(true);
    setQrSearchResult(null);
    try {
      const result = await inventoryService.getRollByQr(qrQuery.trim());
      setQrSearchResult(result);
      showNotification(`Found Roll: ${result.rollIdentifier}`);
    } catch (err) {
      setError(`No inventory roll found matching QR "${qrQuery}"`);
      setQrSearchResult(null);
    } finally {
      setQrSearching(false);
    }
  };

  // Trigger Multi-Agent Workflow via ASP.NET Core Proxy
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
      showNotification('Replenishment workflow initiated through ASP.NET Core gateway!');
    } catch (err) {
      setError('Failed to trigger AI workflow.');
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
            <p className="text-xs text-slate-400">Inventory Tracking, Barcode QR Scanning & Stock Logistics</p>
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
              <p className="text-xs text-slate-400 font-medium">Low Stock Items</p>
              <h3 className="text-2xl font-bold text-amber-400 mt-1">{lowStockItems.length}</h3>
              <p className="text-[11px] text-amber-500/80 mt-1">Below safety threshold</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
              <TrendingDown className="w-6 h-6" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400 font-medium">Inventory Rolls</p>
              <h3 className="text-2xl font-bold text-cyan-400 mt-1">{rolls.length}</h3>
              <p className="text-[11px] text-slate-500 mt-1">Active scanned batches</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400">
              <QrCode className="w-6 h-6" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400 font-medium">Active Warehouse Alerts</p>
              <h3 className="text-2xl font-bold text-rose-400 mt-1">{activeAlerts.length}</h3>
              <p className="text-[11px] text-slate-500 mt-1">{alerts.length} total logged</p>
            </div>
            <div className="w-12 h-12 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
              <ShieldAlert className="w-6 h-6" />
            </div>
          </div>
        </div>

        {/* Tab Selection */}
        <div className="flex items-center justify-between border-b border-slate-800 overflow-x-auto">
          <div className="flex gap-2 min-w-max">
            {[
              { id: 'inventory', label: 'Raw Materials & Items', icon: Package },
              { id: 'rolls', label: `Inventory Rolls (${rolls.length})`, icon: QrCode },
              { id: 'stock-levels', label: 'Stock Levels & Burn Rate', icon: Activity },
              { id: 'alerts', label: `Low Stock Alerts (${activeAlerts.length})`, icon: AlertTriangle },
              { id: 'history', label: 'Inventory History', icon: FileText },
              { id: 'agent', label: 'AI Agent Coordinator', icon: Bot }
            ].map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => {
                    setActiveTab(tab.id);
                    if (tab.id === 'inventory') navigate('/inventory');
                    else if (tab.id === 'rolls') navigate('/inventory/rolls');
                    else if (tab.id === 'stock-levels') navigate('/inventory/stock-levels');
                    else if (tab.id === 'alerts') navigate('/inventory/low-stock');
                    else if (tab.id === 'history') navigate('/inventory/history');
                  }}
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
              className="flex items-center gap-2 px-4 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-cyan-500/20 shrink-0"
            >
              <PlusCircle className="w-4 h-4" />
              Add Stock Item
            </button>
          )}

          {activeTab === 'alerts' && (
            <button
              onClick={() => setShowAddAlertModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold text-xs rounded-xl transition shadow-lg shadow-amber-500/20 shrink-0"
            >
              <PlusCircle className="w-4 h-4" />
              Log Stock Alert
            </button>
          )}
        </div>

        {/* TAB 1: INVENTORY ITEMS & RAW MATERIALS */}
        {activeTab === 'inventory' && (
          <div className="space-y-4">
            {/* Search Bar */}
            <div className="flex items-center gap-3 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5">
              <Search className="w-4 h-4 text-slate-500" />
              <input
                type="text"
                placeholder="Search raw materials by SKU, item name, or category..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="bg-transparent border-none text-sm text-slate-200 placeholder-slate-500 focus:outline-none w-full"
              />
            </div>

            {/* Inventory Items Table */}
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
                  {loading ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-500 text-xs">
                        Loading inventory records...
                      </td>
                    </tr>
                  ) : filteredItems.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-500 text-xs">
                        No inventory records found matching "{searchQuery}".
                      </td>
                    </tr>
                  ) : (
                    filteredItems.map((item) => {
                      const isLow = Number(item.stockLevel) <= Number(item.reorderThreshold);
                      return (
                        <tr key={item.id} className="hover:bg-slate-800/30 transition">
                          <td className="px-6 py-4 font-mono font-bold text-cyan-400 text-xs">
                            {item.sku}
                          </td>
                          <td className="px-6 py-4 font-medium text-white">{item.name}</td>
                          <td className="px-6 py-4 text-xs text-slate-400">{item.category || 'General'}</td>
                          <td className="px-6 py-4 font-semibold text-slate-100">
                            {item.stockLevel} units
                          </td>
                          <td className="px-6 py-4 text-xs text-slate-400">
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
                          <td className="px-6 py-4 text-right space-x-2">
                            {isLow && (
                              <button
                                onClick={() => handleTriggerAiWorkflow(item.sku, 2000)}
                                className="px-3 py-1.5 rounded-lg bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 text-xs font-semibold transition"
                              >
                                Reorder via AI
                              </button>
                            )}
                            <button
                              onClick={() => handleDeleteItem(item.id)}
                              className="p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 transition"
                              title="Delete Item"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
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

        {/* TAB 2: BARCODE & INVENTORY ROLLS + QR LOOKUP */}
        {activeTab === 'rolls' && (
          <div className="space-y-6">
            {/* QR Scanner / Lookup Box */}
            <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                  <QrCode className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">QR / Barcode Roll Scanner & Lookup</h3>
                  <p className="text-xs text-slate-400">Identify rolls and view real-time batch allocation</p>
                </div>
              </div>

              <form onSubmit={handleQrSearch} className="flex gap-3">
                <input
                  type="text"
                  placeholder="Enter QR barcode value (e.g. ROLL-001, ROLL-2026-STEEL-009)..."
                  value={qrQuery}
                  onChange={(e) => setQrQuery(e.target.value)}
                  className="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                />
                <button
                  type="submit"
                  disabled={qrSearching}
                  className="px-5 py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs rounded-xl transition"
                >
                  {qrSearching ? 'Scanning...' : 'Scan / Lookup'}
                </button>
              </form>

              {/* QR Search Result Card */}
              {qrSearchResult && (
                <div className="p-4 rounded-xl bg-cyan-950/20 border border-cyan-500/30 grid grid-cols-1 md:grid-cols-4 gap-4 mt-3">
                  <div>
                    <span className="text-[10px] text-slate-400 uppercase font-mono">Roll Identifier</span>
                    <p className="font-mono font-bold text-cyan-400 text-sm mt-0.5">{qrSearchResult.rollIdentifier}</p>
                  </div>
                  <div>
                    <span className="text-[10px] text-slate-400 uppercase font-mono">Material</span>
                    <p className="font-semibold text-white text-sm mt-0.5">{qrSearchResult.materialName} ({qrSearchResult.skuCode})</p>
                  </div>
                  <div>
                    <span className="text-[10px] text-slate-400 uppercase font-mono">Remaining Quantity</span>
                    <p className="font-semibold text-emerald-400 text-sm mt-0.5">{qrSearchResult.remainingQuantity} / {qrSearchResult.initialQuantity} units</p>
                  </div>
                  <div>
                    <span className="text-[10px] text-slate-400 uppercase font-mono">Status</span>
                    <p className="font-semibold text-cyan-300 text-sm mt-0.5">{qrSearchResult.status}</p>
                  </div>
                </div>
              )}
            </div>

            {/* Rolls Management & List */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Register Roll Form */}
              <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-4">
                <h3 className="text-base font-bold text-white">Register New Roll</h3>
                <form onSubmit={handleCreateRoll} className="space-y-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-300 mb-1">Roll Identifier</label>
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
                    className="w-full py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold rounded-xl text-sm transition"
                  >
                    Register Roll
                  </button>
                </form>
              </div>

              {/* Active Rolls List */}
              <div className="md:col-span-2 border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
                <div className="px-6 py-4 border-b border-slate-800 flex justify-between items-center">
                  <h3 className="text-sm font-bold text-white">Warehouse Inventory Rolls</h3>
                  <span className="text-xs text-slate-400">{rolls.length} rolls in system</span>
                </div>
                <div className="divide-y divide-slate-800 max-h-96 overflow-y-auto">
                  {rolls.length === 0 ? (
                    <div className="p-8 text-center text-xs text-slate-500">No inventory rolls registered yet.</div>
                  ) : (
                    rolls.map((roll) => (
                      <div key={roll.id} className="p-4 flex items-center justify-between hover:bg-slate-800/30 transition">
                        <div>
                          <p className="font-mono font-bold text-cyan-400 text-xs">{roll.rollIdentifier}</p>
                          <p className="text-xs text-slate-400 mt-0.5">
                            Status: <span className="text-slate-200">{roll.status || 'In Stock'}</span> • Qty: {roll.currentQuantity}
                          </p>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="text-xs text-slate-500">{new Date(roll.createdAt).toLocaleDateString()}</span>
                          <button
                            onClick={() => handleDeleteRoll(roll.id)}
                            className="p-1.5 text-slate-500 hover:text-rose-400 transition"
                            title="Delete Roll"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: STOCK LEVELS & BURN RATE */}
        {activeTab === 'stock-levels' && (
          <div className="space-y-6">
            <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
              <div className="px-6 py-4 border-b border-slate-800 flex justify-between items-center">
                <div>
                  <h3 className="text-base font-bold text-white">Stock Levels & Daily Burn Rate Analysis</h3>
                  <p className="text-xs text-slate-400">Formula: daysRemaining = currentStock / burnRate</p>
                </div>
              </div>

              <table className="w-full text-left text-sm text-slate-300">
                <thead className="bg-slate-950/80 border-b border-slate-800 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  <tr>
                    <th className="px-6 py-3.5">SKU</th>
                    <th className="px-6 py-3.5">Material</th>
                    <th className="px-6 py-3.5">Current Stock</th>
                    <th className="px-6 py-3.5">Min / Max Stock</th>
                    <th className="px-6 py-3.5">Daily Burn Rate</th>
                    <th className="px-6 py-3.5">Days Remaining</th>
                    <th className="px-6 py-3.5">Visual Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {stockLevels.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-500 text-xs">
                        Loading stock level calculations...
                      </td>
                    </tr>
                  ) : (
                    stockLevels.map((lvl) => {
                      const isCritical = lvl.status === 'CRITICAL';
                      const isLow = lvl.status === 'LOW';
                      return (
                        <tr key={lvl.id} className="hover:bg-slate-800/30 transition">
                          <td className="px-6 py-4 font-mono font-bold text-cyan-400 text-xs">{lvl.skuCode}</td>
                          <td className="px-6 py-4 font-medium text-white">{lvl.materialName}</td>
                          <td className="px-6 py-4 font-bold text-slate-100">{lvl.currentStock} KG</td>
                          <td className="px-6 py-4 text-xs text-slate-400">{lvl.minimumStock} / {lvl.maximumStock} KG</td>
                          <td className="px-6 py-4 text-xs font-mono text-cyan-300">{lvl.burnRate} KG/day</td>
                          <td className="px-6 py-4 font-mono font-bold text-slate-200">{lvl.daysRemaining} days</td>
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
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 4: LOW STOCK ALERTS */}
        {activeTab === 'alerts' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {alerts.length === 0 ? (
                <div className="col-span-2 p-12 text-center text-slate-500 text-sm border border-slate-800 rounded-2xl bg-slate-900/30">
                  No stock alerts logged. All raw material inventories are above threshold.
                </div>
              ) : (
                alerts.map((alert) => (
                  <div key={alert.id} className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex flex-col justify-between space-y-4">
                    <div className="flex items-start justify-between">
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-mono font-bold text-amber-400 text-sm">{alert.sku}</span>
                          <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider ${
                            alert.status === 'Pending' ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30' :
                            alert.status === 'Acknowledged' ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30' :
                            'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                          }`}>
                            {alert.status}
                          </span>
                        </div>
                        <p className="text-xs text-slate-400 mt-1">{alert.packagingType} • Requested: {alert.quantityRequested} units</p>
                      </div>
                      <span className="text-[11px] text-slate-500 flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {new Date(alert.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>

                    <div className="flex items-center justify-between pt-3 border-t border-slate-800/80">
                      <span className="text-xs text-slate-500">By: {alert.workerId || 'Floor Worker'}</span>
                      <div className="flex gap-1.5">
                        {['Acknowledged', 'Resolved', 'Dismissed'].map((status) => (
                          <button
                            key={status}
                            onClick={() => handleUpdateAlertStatus(alert.id, status)}
                            className="px-2 py-1 rounded text-[11px] font-medium bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
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

        {/* TAB 5: INVENTORY HISTORY */}
        {activeTab === 'history' && (
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <label className="text-xs text-slate-400">Select Raw Material:</label>
              <select
                value={selectedHistoryMaterialId}
                onChange={(e) => loadHistoryForMaterial(Number(e.target.value))}
                className="bg-slate-900 border border-slate-800 rounded-xl px-3 py-1.5 text-xs text-white focus:outline-none focus:border-cyan-500"
              >
                {rawMaterials.map((m) => (
                  <option key={m.id} value={m.id}>{m.skuCode} - {m.name}</option>
                ))}
              </select>
            </div>

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
                  {historyItems.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-500 text-xs">
                        No transactions recorded for this material.
                      </td>
                    </tr>
                  ) : (
                    historyItems.map((h, i) => (
                      <tr key={i} className="hover:bg-slate-800/30 transition">
                        <td className="px-6 py-3 text-xs text-slate-400">{new Date(h.date).toLocaleString()}</td>
                        <td className="px-6 py-3">
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                            h.transactionType === 'RECEIVED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-blue-500/20 text-blue-400'
                          }`}>
                            {h.transactionType}
                          </span>
                        </td>
                        <td className="px-6 py-3 font-semibold text-slate-200">{h.quantity} KG</td>
                        <td className="px-6 py-3 text-xs text-slate-400">{h.previousStock} KG</td>
                        <td className="px-6 py-3 font-bold text-white">{h.newStock} KG</td>
                        <td className="px-6 py-3 text-xs text-slate-300">{h.reason}</td>
                        <td className="px-6 py-3 text-xs text-slate-500">{h.user}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 6: AI AGENT COORDINATOR */}
        {activeTab === 'agent' && (
          <div className="space-y-6">
            <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-6">
              <div>
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Bot className="w-5 h-5 text-cyan-400" />
                  LangGraph 4-Student Collaborative Workflow
                </h3>
                <p className="text-xs text-slate-400 mt-1">
                  Trigger autonomous replenishment through the ASP.NET Core API Gateway.
                </p>
              </div>

              {/* Architecture Steps Graphic */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                <div className="p-4 rounded-xl bg-cyan-950/20 border border-cyan-500/30">
                  <span className="text-[10px] font-mono text-cyan-400 uppercase font-bold">1. Student 1 (Floor Worker)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Data Extraction</h4>
                  <p className="text-xs text-slate-400 mt-1">Extracts stock level, burn rate, and required replenishment</p>
                </div>

                <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] font-mono text-slate-400 uppercase font-bold">2. Student 4 (Production)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Production Analysis</h4>
                  <p className="text-xs text-slate-400 mt-1">Analyzes machine capacity, shift schedule, and output impact</p>
                </div>

                <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] font-mono text-slate-400 uppercase font-bold">3. Student 2 (Purchasing)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Supplier Procurement</h4>
                  <p className="text-xs text-slate-400 mt-1">Calculates optimal supplier and drafts Purchase Order</p>
                </div>

                <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] font-mono text-slate-400 uppercase font-bold">4. Student 3 (Quality)</span>
                  <h4 className="text-sm font-bold text-white mt-1">Validation & Safety</h4>
                  <p className="text-xs text-slate-400 mt-1">Audits defect history and verifies quarantine holds</p>
                </div>
              </div>

              {/* Trigger Button */}
              <div className="p-5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col md:flex-row items-center justify-between gap-4">
                <div>
                  <h4 className="text-sm font-bold text-white">Trigger Floor Replenishment Workflow</h4>
                  <p className="text-xs text-slate-400 mt-0.5">Executes multi-agent autonomous decision pipeline via ASP.NET Core gateway</p>
                </div>
                <button
                  onClick={() => handleTriggerAiWorkflow('RM-STEEL-001', 2000)}
                  disabled={triggeringAi}
                  className="px-5 py-2.5 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-slate-950 font-bold text-xs rounded-xl transition flex items-center gap-2 shadow-lg shadow-cyan-500/20"
                >
                  <Sparkles className={`w-4 h-4 ${triggeringAi ? 'animate-spin' : ''}`} />
                  {triggeringAi ? 'Initiating Pipeline...' : 'Run Auto Replenishment'}
                </button>
              </div>

              {/* Workflow Execution Results */}
              {aiWorkflowResult && (
                <div className="p-5 rounded-xl bg-slate-950 border border-cyan-500/30 space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-cyan-400 flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                      Workflow Executed: {aiWorkflowResult.workflow_id || 'WF-ACTIVE'}
                    </span>
                    <span className="text-xs px-2.5 py-1 rounded-full bg-cyan-500/20 text-cyan-300 font-mono">
                      {aiWorkflowResult.status || 'Active'}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
                    <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                      <span className="text-slate-500">Current Agent</span>
                      <p className="font-bold text-white mt-1">{aiWorkflowResult.current_agent || 'Completed'}</p>
                    </div>
                    <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                      <span className="text-slate-500">Requires Approval</span>
                      <p className="font-bold text-amber-400 mt-1">{aiWorkflowResult.requires_approval ? 'Yes (> $5,000)' : 'No'}</p>
                    </div>
                    <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                      <span className="text-slate-500">Approval Status</span>
                      <p className="font-bold text-cyan-400 mt-1">{aiWorkflowResult.approval_status || 'Pending'}</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Modal: Add Stock Item */}
        {showAddItemModal && (
          <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
              <h3 className="text-base font-bold text-white">Add Raw Material Stock Item</h3>
              <form onSubmit={handleAddItem} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">SKU Code</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. RM-STEEL-001"
                    value={newItem.sku}
                    onChange={(e) => setNewItem({ ...newItem, sku: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Item Name</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Cold Rolled Steel Sheet"
                    value={newItem.name}
                    onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Current Stock</label>
                    <input
                      type="number"
                      required
                      value={newItem.stockLevel}
                      onChange={(e) => setNewItem({ ...newItem, stockLevel: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Reorder Level</label>
                    <input
                      type="number"
                      required
                      value={newItem.reorderThreshold}
                      onChange={(e) => setNewItem({ ...newItem, reorderThreshold: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500"
                    />
                  </div>
                </div>
                <div className="flex gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setShowAddItemModal(false)}
                    className="flex-1 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs rounded-xl transition"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs rounded-xl transition"
                  >
                    Create Item
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal: Log Stock Alert */}
        {showAddAlertModal && (
          <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
              <h3 className="text-base font-bold text-white">Log Low Stock Alert</h3>
              <form onSubmit={handleAddAlert} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Material SKU</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. RM-STEEL-001"
                    value={newAlert.sku}
                    onChange={(e) => setNewAlert({ ...newAlert, sku: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Requested Quantity</label>
                  <input
                    type="number"
                    required
                    min={1}
                    value={newAlert.quantityRequested}
                    onChange={(e) => setNewAlert({ ...newAlert, quantityRequested: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div className="flex gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setShowAddAlertModal(false)}
                    className="flex-1 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs rounded-xl transition"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs rounded-xl transition"
                  >
                    Submit Alert
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
