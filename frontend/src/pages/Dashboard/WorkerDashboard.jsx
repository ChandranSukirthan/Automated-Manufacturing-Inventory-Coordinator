import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  Package,
  AlertTriangle,
  QrCode,
  Activity,
  FileText,
  Bot,
  PlusCircle,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import inventoryService from '../../services/inventoryService';

// ── Sub-components ──────────────────────────────────────────────
import WorkerHeader from '../Worker/components/WorkerHeader';
import KpiCards from '../Worker/components/KpiCards';
import InventoryTab from '../Worker/components/InventoryTab';
import RollsTab from '../Worker/components/RollsTab';
import StockLevelsTab from '../Worker/components/StockLevelsTab';
import AlertsTab from '../Worker/components/AlertsTab';
import HistoryTab from '../Worker/components/HistoryTab';
import AgentTab from '../Worker/components/AgentTab';

/* ================================================================
   WorkerDashboard — Thin orchestrator
   Manages shared state & routes, delegates rendering to tab components
   ================================================================ */

const TABS = [
  { id: 'inventory', label: 'Raw Materials & Items', icon: Package },
  { id: 'rolls', label: 'Inventory Rolls', icon: QrCode, countKey: 'rolls' },
  { id: 'stock-levels', label: 'Stock Levels & Burn Rate', icon: Activity },
  { id: 'alerts', label: 'Low Stock Alerts', icon: AlertTriangle, countKey: 'activeAlerts' },
  { id: 'history', label: 'Inventory History', icon: FileText },
  { id: 'agent', label: 'AI Agent Coordinator', icon: Bot },
];

export default function WorkerDashboard() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  // ── Shared state ────────────────────────────────────────────
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
  const [activeTab, setActiveTab] = useState('inventory');

  // Modals
  const [showAddItemModal, setShowAddItemModal] = useState(false);
  const [newItem, setNewItem] = useState({
    sku: '', name: '', category: 'Metal', stockLevel: 100, reorderThreshold: 50,
  });
  const [showAddAlertModal, setShowAddAlertModal] = useState(false);
  const [newAlert, setNewAlert] = useState({
    sku: '', packagingType: 'Standard Roll', quantityRequested: 500, notes: '',
  });

  // Roll registration
  const [rollIdentifier, setRollIdentifier] = useState('');
  const [rollRawMaterialId, setRollRawMaterialId] = useState(1);
  const [registeredRoll, setRegisteredRoll] = useState(null);

  // QR lookup
  const [qrQuery, setQrQuery] = useState('');
  const [qrSearchResult, setQrSearchResult] = useState(null);
  const [qrSearching, setQrSearching] = useState(false);

  // AI workflow
  const [triggeringAi, setTriggeringAi] = useState(false);
  const [aiWorkflowResult, setAiWorkflowResult] = useState(null);

  // ── Route sync ──────────────────────────────────────────────
  useEffect(() => {
    const path = location.pathname;
    if (path.includes('/rolls')) setActiveTab('rolls');
    else if (path.includes('/stock-levels')) setActiveTab('stock-levels');
    else if (path.includes('/low-stock')) setActiveTab('alerts');
    else if (path.includes('/history')) setActiveTab('history');
    else if (path.includes('/inventory')) setActiveTab('inventory');
  }, [location.pathname]);

  // ── Data loading ────────────────────────────────────────────
  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [itemsData, rawMatsData, rollsData, alertsData, levelsData] = await Promise.all([
        inventoryService.getItems().catch(() => []),
        inventoryService.getRawMaterials().catch(() => []),
        inventoryService.getRolls().catch(() => []),
        inventoryService.getAlerts().catch(() => []),
        inventoryService.getStockLevels().catch(() => []),
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
    } catch {
      setError('Unable to load inventory records. Ensure backend is running.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  const loadHistoryForMaterial = async (id) => {
    setSelectedHistoryMaterialId(id);
    try {
      const hist = await inventoryService.getHistory(id);
      setHistoryItems(hist || []);
    } catch {
      setHistoryItems([]);
    }
  };

  const showNotification = (msg) => {
    setSuccessMsg(msg);
    setTimeout(() => setSuccessMsg(''), 4000);
  };

  // ── Event handlers (unchanged logic) ────────────────────────
  const handleAddItem = async (e) => {
    e.preventDefault();
    try {
      await inventoryService.createItem({
        ...newItem,
        stockLevel: Number(newItem.stockLevel),
        reorderThreshold: Number(newItem.reorderThreshold),
      });
      setShowAddItemModal(false);
      setNewItem({ sku: '', name: '', category: 'Metal', stockLevel: 100, reorderThreshold: 50 });
      showNotification('Inventory item created successfully!');
      loadData();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to create inventory item');
    }
  };

  const handleDeleteItem = async (id) => {
    if (!window.confirm('Delete this inventory item?')) return;
    try {
      await inventoryService.deleteItem(id);
      showNotification('Item deleted successfully.');
      loadData();
    } catch { setError('Failed to delete item.'); }
  };

  const handleUpdateAlertStatus = async (alertId, newStatus) => {
    try {
      await inventoryService.updateAlertStatus(alertId, newStatus);
      showNotification(`Alert status updated to "${newStatus}"!`);
      loadData();
    } catch { setError('Failed to update alert status'); }
  };

  const handleAddAlert = async (e) => {
    e.preventDefault();
    const existing = alerts.find(
      (a) =>
        a.sku?.toLowerCase() === newAlert.sku?.trim().toLowerCase() &&
        ['Pending', 'Processing', 'Acknowledged'].includes(a.status)
    );
    if (existing) {
      setError(`An active replenishment alert (${existing.status}) already exists for ${newAlert.sku}. Cannot create duplicate.`);
      return;
    }
    try {
      await inventoryService.createAlert({
        sku: newAlert.sku,
        packagingType: newAlert.packagingType,
        quantityRequested: Number(newAlert.quantityRequested),
      });
      setShowAddAlertModal(false);
      setNewAlert({ sku: '', packagingType: 'Standard Roll', quantityRequested: 500, notes: '' });
      showNotification('Stock alert created successfully!');
      loadData();
    } catch { setError('Failed to create stock alert'); }
  };

  const handleCreateRoll = async (e) => {
    e.preventDefault();
    if (!rollIdentifier.trim()) return;
    try {
      const created = await inventoryService.createRoll({
        rollIdentifier: rollIdentifier.trim(),
        rawMaterialId: Number(rollRawMaterialId),
      });
      setRegisteredRoll(created);
      setRollIdentifier('');
      showNotification(`Inventory Roll ${created.rollIdentifier || rollIdentifier} registered!`);
      loadData();
    } catch { setError('Failed to register inventory roll.'); }
  };

  const handleDeleteRoll = async (id) => {
    if (!window.confirm('Delete this inventory roll?')) return;
    try {
      await inventoryService.deleteRoll(id);
      showNotification('Inventory roll deleted.');
      loadData();
    } catch { setError('Failed to delete roll.'); }
  };

  const handleQrSearch = async (e) => {
    e.preventDefault();
    if (!qrQuery.trim()) return;
    setQrSearching(true);
    setQrSearchResult(null);
    try {
      const result = await inventoryService.getRollByQr(qrQuery.trim());
      setQrSearchResult(result);
      showNotification(`Found Roll: ${result.rollIdentifier}`);
    } catch {
      setError(`No inventory roll found matching QR "${qrQuery}"`);
      setQrSearchResult(null);
    } finally {
      setQrSearching(false);
    }
  };

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
      showNotification('Replenishment workflow initiated!');
      await loadData();
    } catch { setError('Failed to trigger AI workflow.'); }
    finally { setTriggeringAi(false); }
  };

  // ── Computed values ─────────────────────────────────────────
  const lowStockItems = items.filter((item) => Number(item.stockLevel) <= Number(item.reorderThreshold));
  const activeAlerts = alerts.filter((a) => !['Resolved', 'Dismissed'].includes(a.status));
  const filteredItems = items.filter(
    (item) =>
      item.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.sku?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.category?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // ── Tab change handler ──────────────────────────────────────
  const handleTabChange = (tabId) => {
    setActiveTab(tabId);
    const routes = {
      inventory: '/inventory',
      rolls: '/inventory/rolls',
      'stock-levels': '/inventory/stock-levels',
      alerts: '/inventory/low-stock',
      history: '/inventory/history',
    };
    if (routes[tabId]) navigate(routes[tabId]);
  };

  // Tab counts for badges
  const tabCounts = {
    rolls: rolls.length,
    activeAlerts: activeAlerts.length,
  };

  // ── Render ──────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      <WorkerHeader user={user} loading={loading} onRefresh={loadData} onLogout={logout} />

      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8 space-y-6">
        {/* Banner messages */}
        {error && (
          <div className="p-4 rounded-xl border border-rose-500/30 bg-rose-500/10 text-rose-300 text-sm flex items-center justify-between tab-slide-in">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-400" />
              <span>{error}</span>
            </div>
            <button onClick={() => setError('')} className="text-xs text-rose-400 underline">
              Dismiss
            </button>
          </div>
        )}
        {successMsg && (
          <div className="p-4 rounded-xl border border-emerald-500/30 bg-emerald-500/10 text-emerald-300 text-sm flex items-center gap-2 tab-slide-in">
            <svg className="w-4 h-4 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            <span>{successMsg}</span>
          </div>
        )}

        {/* KPI Cards */}
        <KpiCards
          loading={loading}
          totalItems={items.length}
          lowStockCount={lowStockItems.length}
          rollsCount={rolls.length}
          activeAlertsCount={activeAlerts.length}
          totalAlertsCount={alerts.length}
          onTabChange={handleTabChange}
        />

        {/* Tab navigation */}
        <div className="border-b border-slate-800 overflow-x-auto">
          <div className="flex gap-1 min-w-max">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              const count = tab.countKey ? tabCounts[tab.countKey] : null;
              return (
                <button
                  key={tab.id}
                  onClick={() => handleTabChange(tab.id)}
                  className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition -mb-px whitespace-nowrap ${
                    isActive
                      ? 'border-cyan-400 text-cyan-400'
                      : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-700'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  {tab.label}
                  {count !== null && (
                    <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-bold ${
                      isActive ? 'bg-cyan-500/20 text-cyan-300' : 'bg-slate-800 text-slate-500'
                    }`}>
                      {count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Active tab content */}
        {activeTab === 'inventory' && (
          <InventoryTab
            loading={loading}
            filteredItems={filteredItems}
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
            alerts={alerts}
            triggeringAi={triggeringAi}
            onTriggerAi={handleTriggerAiWorkflow}
            onDeleteItem={handleDeleteItem}
            onShowAddModal={() => setShowAddItemModal(true)}
          />
        )}

        {activeTab === 'rolls' && (
          <RollsTab
            rolls={rolls}
            rawMaterials={rawMaterials}
            rollIdentifier={rollIdentifier}
            setRollIdentifier={setRollIdentifier}
            rollRawMaterialId={rollRawMaterialId}
            setRollRawMaterialId={setRollRawMaterialId}
            registeredRoll={registeredRoll}
            onCreateRoll={handleCreateRoll}
            onDeleteRoll={handleDeleteRoll}
            qrQuery={qrQuery}
            setQrQuery={setQrQuery}
            qrSearchResult={qrSearchResult}
            qrSearching={qrSearching}
            onQrSearch={handleQrSearch}
            loading={loading}
          />
        )}

        {activeTab === 'stock-levels' && (
          <StockLevelsTab
            loading={loading}
            stockLevels={stockLevels}
            alerts={alerts}
            triggeringAi={triggeringAi}
            onTriggerAi={handleTriggerAiWorkflow}
          />
        )}

        {activeTab === 'alerts' && (
          <AlertsTab
            loading={loading}
            alerts={alerts}
            onUpdateAlertStatus={handleUpdateAlertStatus}
            onShowAddModal={() => setShowAddAlertModal(true)}
          />
        )}

        {activeTab === 'history' && (
          <HistoryTab
            loading={loading}
            rawMaterials={rawMaterials}
            selectedHistoryMaterialId={selectedHistoryMaterialId}
            onSelectMaterial={loadHistoryForMaterial}
            historyItems={historyItems}
          />
        )}

        {activeTab === 'agent' && (
          <AgentTab
            rawMaterials={rawMaterials}
            stockLevels={stockLevels}
            triggeringAi={triggeringAi}
            aiWorkflowResult={aiWorkflowResult}
            onTriggerAi={handleTriggerAiWorkflow}
          />
        )}

        {/* ── Modal: Add Stock Item ────────────────────────── */}
        {showAddItemModal && (
          <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl tab-slide-in">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                  <Package className="w-5 h-5" />
                </div>
                <h3 className="text-base font-bold text-white">Add Raw Material Stock Item</h3>
              </div>
              <form onSubmit={handleAddItem} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">SKU Code</label>
                  <input
                    type="text" required placeholder="e.g. RM-STEEL-001"
                    value={newItem.sku}
                    onChange={(e) => setNewItem({ ...newItem, sku: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Item Name</label>
                  <input
                    type="text" required placeholder="e.g. Cold Rolled Steel Sheet"
                    value={newItem.name}
                    onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Current Stock</label>
                    <input
                      type="number" required value={newItem.stockLevel}
                      onChange={(e) => setNewItem({ ...newItem, stockLevel: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Reorder Level</label>
                    <input
                      type="number" required value={newItem.reorderThreshold}
                      onChange={(e) => setNewItem({ ...newItem, reorderThreshold: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                    />
                  </div>
                </div>
                <div className="flex gap-3 pt-2">
                  <button type="button" onClick={() => setShowAddItemModal(false)}
                    className="flex-1 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs rounded-xl transition">
                    Cancel
                  </button>
                  <button type="submit"
                    className="flex-1 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs rounded-xl transition">
                    Create Item
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ── Modal: Log Stock Alert ───────────────────────── */}
        {showAddAlertModal && (
          <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl tab-slide-in">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
                  <AlertTriangle className="w-5 h-5" />
                </div>
                <h3 className="text-base font-bold text-white">Log Low Stock Alert</h3>
              </div>
              <form onSubmit={handleAddAlert} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Material SKU</label>
                  <input
                    type="text" required placeholder="e.g. RM-STEEL-001"
                    value={newAlert.sku}
                    onChange={(e) => setNewAlert({ ...newAlert, sku: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-amber-500 transition"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Requested Quantity</label>
                  <input
                    type="number" required min={1} value={newAlert.quantityRequested}
                    onChange={(e) => setNewAlert({ ...newAlert, quantityRequested: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-amber-500 transition"
                  />
                </div>
                <div className="flex gap-3 pt-2">
                  <button type="button" onClick={() => setShowAddAlertModal(false)}
                    className="flex-1 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs rounded-xl transition">
                    Cancel
                  </button>
                  <button type="submit"
                    className="flex-1 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs rounded-xl transition">
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
