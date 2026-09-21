import api from './api';

const inventoryService = {
  // =========================================================================
  // Generic / Legacy Inventory Items
  // =========================================================================
  getItems: async () => {
    const response = await api.get('/inventory');
    return response.data;
  },

  getItemById: async (id) => {
    const response = await api.get(`/inventory/${id}`);
    return response.data;
  },

  createItem: async (itemData) => {
    const response = await api.post('/inventory', itemData);
    return response.data;
  },

  updateItem: async (id, itemData) => {
    const response = await api.put(`/inventory/${id}`, itemData);
    return response.data;
  },

  deleteItem: async (id) => {
    const response = await api.delete(`/inventory/${id}`);
    return response.data;
  },

  // =========================================================================
  // Student 1: Raw Materials CRUD
  // =========================================================================
  getRawMaterials: async () => {
    const response = await api.get('/inventory/rawmaterials');
    return response.data;
  },

  getRawMaterialById: async (id) => {
    const response = await api.get(`/inventory/rawmaterials/${id}`);
    return response.data;
  },

  createRawMaterial: async (materialData) => {
    const response = await api.post('/inventory/rawmaterials', materialData);
    return response.data;
  },

  updateRawMaterial: async (id, materialData) => {
    const response = await api.put(`/inventory/rawmaterials/${id}`, materialData);
    return response.data;
  },

  deleteRawMaterial: async (id) => {
    const response = await api.delete(`/inventory/rawmaterials/${id}`);
    return response.data;
  },

  // =========================================================================
  // Student 1: Inventory Rolls & QR Code Lookup
  // =========================================================================
  getRolls: async () => {
    const response = await api.get('/inventory/rolls');
    return response.data;
  },

  getRollById: async (id) => {
    const response = await api.get(`/inventory/rolls/${id}`);
    return response.data;
  },

  createRoll: async (rollData) => {
    const response = await api.post('/inventory/rolls', rollData);
    return response.data;
  },

  updateRoll: async (id, rollData) => {
    const response = await api.put(`/inventory/rolls/${id}`, rollData);
    return response.data;
  },

  deleteRoll: async (id) => {
    const response = await api.delete(`/inventory/rolls/${id}`);
    return response.data;
  },

  getRollByQr: async (qrCode) => {
    const response = await api.get(`/inventory/roll/qr/${encodeURIComponent(qrCode)}`);
    return response.data;
  },

  // =========================================================================
  // Student 1: Stock Levels & Calculations
  // =========================================================================
  getStockLevels: async () => {
    const response = await api.get('/inventory/stock-levels');
    return response.data;
  },

  createStockLevel: async (stockData) => {
    const response = await api.post('/inventory/stock-levels', stockData);
    return response.data;
  },

  // =========================================================================
  // Student 1: Low Stock & Alerts
  // =========================================================================
  getLowStock: async () => {
    const response = await api.get('/inventory/low-stock');
    return response.data;
  },

  createLowStockAlert: async (alertData) => {
    const response = await api.post('/inventory/low-stock-alert', alertData);
    return response.data;
  },

  getAlerts: async () => {
    const response = await api.get('/inventory/alerts');
    return response.data;
  },

  createAlert: async (alertData) => {
    const response = await api.post('/inventory/alerts', alertData);
    return response.data;
  },

  updateAlertStatus: async (id, status) => {
    const response = await api.put(`/inventory/alerts/${id}`, { status });
    return response.data;
  },

  // =========================================================================
  // Student 1: Inventory History
  // =========================================================================
  getHistory: async (materialId) => {
    const response = await api.get(`/inventory/${materialId}/history`);
    return response.data;
  },

  // =========================================================================
  // Student 1: Multi-Agent Replenishment via ASP.NET Core
  // (Zero direct calls to FastAPI - ASP.NET Core serves as the public gateway)
  // =========================================================================
  triggerWorkflow: async (objective, materialId = 'RM-STEEL-001', requiredQty = 2000) => {
    const response = await api.post('/inventory/trigger-replenishment', {
      objective: objective || `Floor Worker Stock Replenishment: Reorder ${requiredQty} units of ${materialId}`,
      materialId: materialId,
      requiredQuantity: Number(requiredQty)
    });
    return response.data;
  },

  getActiveWorkflows: async () => {
    try {
      const response = await api.get('/agentworkflow/workflows');
      return response.data;
    } catch {
      return [];
    }
  }
};

export default inventoryService;
