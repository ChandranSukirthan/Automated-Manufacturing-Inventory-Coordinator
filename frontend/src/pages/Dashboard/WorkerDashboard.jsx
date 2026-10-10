import ModalOverlay from '../../components/Common/ModalOverlay';
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
  Edit2,
} from 'lucide-react';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';

// ── Sub-components ──────────────────────────────────────────────
import RoleLayout from '../../components/Layout/RoleLayout';
import KpiCards from '../Worker/components/KpiCards';
import InventoryTab from '../Worker/components/InventoryTab';
import RollsTab from '../Worker/components/RollsTab';
import StockLevelsTab from '../Worker/components/StockLevelsTab';
import AlertsTab from '../Worker/components/AlertsTab';
import HistoryTab from '../Worker/components/HistoryTab';
import AgentTab from '../Worker/components/AgentTab';
import OverviewTab from '../Worker/components/OverviewTab';

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
  const [tabChoice, setTabChoice] = useState(null);
  const isDashboard = location.pathname.startsWith('/dashboard/worker');
  const routeTab = location.pathname.includes('/rolls') ? 'rolls'
    : location.pathname.includes('/stock-levels') ? 'stock-levels'
    : location.pathname.includes('/low-stock') ? 'alerts'
    : location.pathname.includes('/history') ? 'history'
    : isDashboard ? 'overview' : 'inventory';
  const activeTab = tabChoice?.path === location.pathname ? tabChoice.tab : routeTab;
  const setActiveTab = (tab) => setTabChoice({ path: location.pathname, tab });

  // Modals
  const [showAddItemModal, setShowAddItemModal] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [newItem, setNewItem] = useState({
    rawMaterialId: '', skuNumber: '', stockLevel: 0, reorderThreshold: 0,
  });
  const [showAddAlertModal, setShowAddAlertModal] = useState(false);
  const [newAlert, setNewAlert] = useState({
    sku: '', packagingType: 'Standard Roll', quantityRequested: 500, notes: '',
  });

  // Roll registration
  const [rollIdentifier, setRollIdentifier] = useState('');
  const [rollBatchId, setRollBatchId] = useState('');
  const [rollQuantity, setRollQuantity] = useState('1');
  const [rollRawMaterialId, setRollRawMaterialId] = useState('');
  const [registeredRoll, setRegisteredRoll] = useState(null);

  // QR lookup
  const [qrQuery, setQrQuery] = useState('');
  const [qrSearchResult, setQrSearchResult] = useState(null);
  const [qrSearching, setQrSearching] = useState(false);

  // AI workflow
  const [triggeringAi, setTriggeringAi] = useState(false);
  const [aiWorkflowResult, setAiWorkflowResult] = useState(null);

  // ── Data loading ────────────────────────────────────────────
  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [itemsData, rawMatsData, rollsData, alertsData, levelsData] = await Promise.all([
        inventoryService.getItems(),
        inventoryService.getRawMaterials(),
        inventoryService.getRolls(),
        inventoryService.getAlerts(),
        inventoryService.getStockLevels(),
      ]);
      setItems(itemsData || []);
      setRawMaterials(rawMatsData || []);
      setRolls(rollsData || []);
      setAlerts(alertsData || []);
      setStockLevels(levelsData || []);

      if (rawMatsData && rawMatsData.length > 0) {
        setRollRawMaterialId((prev) => (prev ? prev : String(rawMatsData[0].id)));
        const hist = await inventoryService.getHistory(rawMatsData[0].id).catch(() => []);
        setHistoryItems(hist || []);
      }
    } catch {
      setError('Unable to load inventory records. Ensure backend is running.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const initialLoad = setTimeout(loadData, 0);
    return () => clearTimeout(initialLoad);
  }, []);

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
    const stockLevel = Number(newItem.stockLevel);
    const reorderThreshold = Number(newItem.reorderThreshold);

    if (isNaN(stockLevel) || stockLevel <= 0) {
      setError('Current stock must be greater than zero when adding an item.');
      return;
    }

    if (isNaN(reorderThreshold) || reorderThreshold < 0) {
      setError('Reorder level cannot be negative.');
      return;
    }

    try {
      const material = rawMaterials.find((value) => value.id === Number(newItem.rawMaterialId));
      if (!material?.packagingTypeId) throw new Error('Select a material with a reconciled packaging type.');
      await inventoryService.createItem({
        rawMaterialId: material.id,
        packagingTypeId: material.packagingTypeId,
        skuNumber: Number(newItem.skuNumber),
        stockLevel,
        reorderThreshold,
      });
      setShowAddItemModal(false);
      setNewItem({ rawMaterialId: '', skuNumber: '', stockLevel: 0, reorderThreshold: 0 });
      showNotification('Inventory item created successfully!');
      loadData();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to create inventory item'));
    }
  };

  const handleDeleteItem = async (id) => {
    const item = items.find((value) => value.id === id);
    if (item && Number(item.stockLevel) !== 0) {
      setError(`Cannot delete ${item.sku}: it has ${item.stockLevel} units remaining. Record the actual stock usage or adjustment before deleting it.`);
      return;
    }
    if (!window.confirm('Delete this inventory item?')) return;
    setError('');
    try {
      await inventoryService.deleteItem(id);
      showNotification('Item deleted successfully.');
      loadData();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to delete item.'));
    }
  };

  const handleEditItem = async (e) => {
    e.preventDefault();
    if (!editingItem) return;
    try {
      await inventoryService.updateItem(editingItem.id, {
        id: editingItem.id,
        sku: editingItem.sku,
        name: editingItem.name,
        category: editingItem.category,
        packagingTypeId: editingItem.packagingTypeId,
        rawMaterialId: editingItem.rawMaterialId,
        skuNumber: editingItem.skuNumber,
        stockLevel: Number(editingItem.stockLevel),
        reorderThreshold: Number(editingItem.reorderThreshold),
      });
      setEditingItem(null);
      showNotification('Inventory item updated successfully!');
      loadData();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to update inventory item'));
    }
  };

  const handleUpdateAlertStatus = async (alertId, newStatus) => {
    try {
      await inventoryService.updateAlertStatus(alertId, newStatus);
      showNotification(`Alert status updated to "${newStatus}"!`);
      loadData();
    } catch (err) { setError(parseErrorMessage(err, 'Failed to update alert status')); }
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
    } catch (err) { setError(parseErrorMessage(err, 'Failed to create stock alert')); }
  };

  const handleCreateRoll = async (e) => {
    e.preventDefault();
    if (!rollIdentifier.trim() || !rollBatchId.trim()) {
      setError('Please provide the physical roll and batch identifiers.');
      return;
    }
    const matId = Number(rollRawMaterialId);
    if (!matId || isNaN(matId)) {
      setError('Please select a valid raw material.');
      return;
    }
    const qty = Number(rollQuantity);
    if (!qty || qty <= 0 || isNaN(qty)) {
      setError('Roll quantity must be greater than zero.');
      return;
    }

    try {
      const created = await inventoryService.createRoll({
        rollIdentifier: rollIdentifier.trim(),
        batchId: rollBatchId.trim(),
        rawMaterialId: matId,
        initialQuantity: qty,
        currentQuantity: qty,
      });
      setRegisteredRoll(created);
      setRollIdentifier('');
      setRollBatchId('');
      setRollQuantity('1');
      showNotification(`Inventory Roll ${created.rollIdentifier || rollIdentifier} registered!`);
      loadData();
    } catch (err) {
      const msg = typeof err.response?.data === 'string'
        ? err.response.data
        : err.response?.data?.message || err.message || 'Failed to register inventory roll.';
      setError(msg);
    }
  };

  const handleDeleteRoll = async (id) => {
    if (!window.confirm('Delete this inventory roll?')) return;
    try {
      await inventoryService.deleteRoll(id);
      showNotification('Inventory roll deleted.');
      loadData();
    } catch (err) { setError(parseErrorMessage(err, 'Failed to delete roll.')); }
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

  const handleTriggerAiWorkflow = async (sku, qty) => {
    setError('');
    setTriggeringAi(true);
    setAiWorkflowResult(null);
    try {
      const materialCode = sku;
      if (!materialCode || !(Number(qty) > 0)) {
        throw new Error('Select an exact material and enter a positive required quantity.');
      }
      const result = await inventoryService.triggerWorkflow(
        `Floor Worker Stock Replenishment: Reorder ${qty} units of ${materialCode}`,
        materialCode,
        qty
      );
      setAiWorkflowResult(result);
      showNotification('Replenishment workflow initiated!');
      await loadData();
    } catch (workflowError) {
      setError(parseErrorMessage(
        workflowError,
        'Unable to start the AI workflow. Ensure the AI service is running, then try again.',
      ));
    }
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
    <RoleLayout
      title={isDashboard ? 'Floor Worker Dashboard' : 'Floor Worker Console'}
      subtitle={isDashboard ? 'Live operational overview, urgent stock alerts, and quick actions' : 'Inventory and stock logistics'}
      loading={loading}
      onRefresh={loadData}
    >

      <main className="worker-dashboard flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-6 sm:py-8 space-y-6">
        <div className="space-y-1">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-cyan-400">Floor operations</p>
          <h2 className="text-2xl sm:text-3xl font-semibold tracking-tight text-white">
            {isDashboard ? 'Operations Dashboard' : 'Inventory Workspace'}
          </h2>
          <p className="text-sm leading-6 text-slate-400">
            {isDashboard
              ? 'Real-time overview of warehouse stock, active alerts, quick floor actions, and recent activity.'
              : 'Manage materials catalogue, track inventory rolls, monitor burn rate, and log alerts.'}
          </p>
        </div>
        {/* Banner messages */}
        {error && (
          <div className="p-4 rounded-xl border border-rose-500/30 bg-rose-500/10 text-rose-300 text-sm flex flex-wrap items-center justify-between gap-3 tab-slide-in">
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

        <button
          type="button"
          onClick={() => navigate('/worker/replenishment')}
          className="worker-replenishment-banner w-full rounded-2xl border border-cyan-500/25 bg-cyan-500/5 px-5 py-4 text-left text-sm text-cyan-100 transition hover:border-cyan-400/50 hover:bg-cyan-500/10 sm:flex sm:items-center sm:justify-between sm:gap-4"
        >
          <span className="font-semibold">Need material urgently?</span>
          <span className="mt-1 block text-xs text-cyan-300 sm:mt-0">Open the replenishment request and workflow-status workspace →</span>
        </button>

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

        {isDashboard ? (
          <OverviewTab
            items={items}
            rolls={rolls}
            alerts={alerts}
            stockLevels={stockLevels}
            lowStockItems={lowStockItems}
            activeAlerts={activeAlerts}
            onShowAddModal={() => setShowAddItemModal(true)}
            onShowAlertModal={() => setShowAddAlertModal(true)}
            onTriggerAi={handleTriggerAiWorkflow}
            onUpdateAlertStatus={handleUpdateAlertStatus}
            triggeringAi={triggeringAi}
            loading={loading}
          />
        ) : (
          <>
            {/* Tab navigation */}
            <div className="worker-tabs rounded-2xl border border-slate-800 bg-slate-900/70 overflow-x-auto p-1.5">
              <div className="flex gap-1 min-w-max">
                {TABS.map((tab) => {
                  const Icon = tab.icon;
                  const isActive = activeTab === tab.id;
                  const count = tab.countKey ? tabCounts[tab.countKey] : null;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => handleTabChange(tab.id)}
                      className={`flex items-center gap-2 px-4 py-3 text-sm font-medium rounded-xl border transition whitespace-nowrap ${
                        isActive
                          ? 'border-cyan-500/30 bg-cyan-500/10 text-cyan-200 shadow-sm'
                          : 'border-transparent text-slate-400 hover:bg-slate-800/60 hover:text-slate-200'
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
                onEditItem={(item) => setEditingItem({ ...item })}
                onShowAddModal={() => setShowAddItemModal(true)}
              />
            )}

        {activeTab === 'rolls' && (
          <RollsTab
            rolls={rolls}
            inventoryItems={items}
            rawMaterials={rawMaterials}
            rollIdentifier={rollIdentifier}
            rollBatchId={rollBatchId}
            setRollBatchId={setRollBatchId}
            setRollIdentifier={setRollIdentifier}
            rollQuantity={rollQuantity}
            setRollQuantity={setRollQuantity}
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
            onTriggerAi={handleTriggerAiWorkflow}
            triggeringAi={triggeringAi}
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
          </>
        )}

        {/* ── Modal: Add Stock Item ────────────────────────── */}
        {showAddItemModal && (
          <ModalOverlay className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="worker-dashboard-modal bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl tab-slide-in">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                  <Package className="w-5 h-5" />
                </div>
                <h3 className="text-base font-bold text-white">Add Raw Material Stock Item</h3>
              </div>
              <form onSubmit={handleAddItem} className="space-y-4">
                <div>
                  <label htmlFor="stock-material" className="block text-xs font-semibold text-slate-400 mb-1">Catalogue Material</label>
                  <select id="stock-material"
                    required value={newItem.rawMaterialId}
                    onChange={(e) => setNewItem({ ...newItem, rawMaterialId: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                  >
                    <option value="">Select a material</option>
                    {rawMaterials.filter((material) => material.packagingTypeId > 0).map((material) =>
                      <option key={material.id} value={material.id}>{material.name} — {material.skuCode}</option>)}
                  </select>
                </div>
                <div>
                  <label htmlFor="stock-sequence" className="block text-xs font-semibold text-slate-400 mb-1">SKU Sequence Number</label>
                  <input
                    id="stock-sequence" type="number" min="1" max="999999" step="1" required
                    value={newItem.skuNumber}
                    onChange={(e) => setNewItem({ ...newItem, skuNumber: e.target.value })}
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
          </ModalOverlay>
        )}

        {/* ── Modal: Edit Catalog Item ───────────────────────── */}
        {editingItem && (
          <ModalOverlay className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="worker-dashboard-modal bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl tab-slide-in">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                  <Edit2 className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Edit Catalog Item</h3>
                  <p className="text-xs text-slate-400 font-mono mt-0.5">{editingItem.sku} — {editingItem.name}</p>
                </div>
              </div>
              <form onSubmit={handleEditItem} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">SKU Code</label>
                  <input
                    type="text"
                    disabled
                    value={editingItem.sku || ''}
                    className="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-4 py-2 text-sm text-slate-400 font-mono cursor-not-allowed"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Item Name</label>
                  <input
                    type="text"
                    disabled
                    value={editingItem.name || ''}
                    className="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-4 py-2 text-sm text-slate-400 cursor-not-allowed"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Current Stock (Units)</label>
                    <input
                      type="number"
                      min={0}
                      required
                      value={editingItem.stockLevel}
                      onChange={(e) => setEditingItem({ ...editingItem, stockLevel: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Reorder Level (Units)</label>
                    <input
                      type="number"
                      min={0}
                      required
                      value={editingItem.reorderThreshold}
                      onChange={(e) => setEditingItem({ ...editingItem, reorderThreshold: e.target.value })}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                    />
                  </div>
                </div>
                <div className="flex gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setEditingItem(null)}
                    className="flex-1 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs rounded-xl transition"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-2 bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-400 hover:to-blue-400 text-slate-950 font-bold text-xs rounded-xl transition shadow-lg shadow-cyan-500/20"
                  >
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          </ModalOverlay>
        )}

        {/* ── Modal: Log Stock Alert ───────────────────────── */}
        {showAddAlertModal && (
          <ModalOverlay className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="worker-dashboard-modal bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl tab-slide-in">
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
          </ModalOverlay>
        )}
      </main>
    </RoleLayout>
  );
}
