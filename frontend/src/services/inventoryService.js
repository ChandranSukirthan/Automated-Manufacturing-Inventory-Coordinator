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
  // Raw material CRUD
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

  // Packaging types
  getPackagingTypes: async () => {
    const response = await api.get('/inventory/packaging-types');
    return response.data;
  },

  createPackagingType: async (data) => {
    const response = await api.post('/inventory/packaging-types', data);
    return response.data;
  },

  updatePackagingType: async (id, data) => {
    const response = await api.put(`/inventory/packaging-types/${id}`, data);
    return response.data;
  },

  deletePackagingType: async (id) => {
    const response = await api.delete(`/inventory/packaging-types/${id}`);
    return response.data;
  },

  // =========================================================================
  // Inventory rolls and QR code lookup
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
  // Stock levels and calculations
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
  // Low stock and alerts
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
  // Inventory history
  // =========================================================================
  getHistory: async (materialId) => {
    const response = await api.get(`/inventory/${materialId}/history`);
    return response.data;
  },

  // =========================================================================
  // Multi-agent replenishment via ASP.NET Core
  // (Zero direct calls to FastAPI - ASP.NET Core serves as the public gateway)
  // =========================================================================
  triggerWorkflow: async (objective, materialId, requiredQty, workflowId) => {
    if (!materialId || !Number.isFinite(Number(requiredQty)) || !(Number(requiredQty) > 0)) {
      throw new Error('An exact material and positive required quantity are required.');
    }
    const response = await api.post('/inventory/trigger-replenishment', {
      objective: objective || `Floor Worker Stock Replenishment: Reorder ${requiredQty} units of ${materialId}`,
      materialId: materialId,
      requiredQuantity: Number(requiredQty),
      triggerType: 'Manual',
      ...(workflowId ? { workflowId } : {}),
    });
    return response.data;
  },

  getActiveWorkflows: async () => {
    const response = await api.get('/agentworkflow/workflows');
    return response.data;
  },

  processAutoReplenishment: async () => {
    const response = await api.post('/inventory/process-auto-replenishment');
    return response.data;
  }

};

export default inventoryService;
