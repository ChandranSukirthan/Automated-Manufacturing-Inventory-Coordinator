import api from './api';
import axios from 'axios';

const FASTAPI_URL = 'http://localhost:5070';

const inventoryService = {
  // Inventory Items (Student 1)
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

  // Stock Alerts (Student 1)
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

  // Inventory Rolls & Raw Materials (Student 1)
  createRoll: async (rollData) => {
    const response = await api.post('/inventory/rolls', rollData);
    return response.data;
  },

  createRawMaterial: async (materialData) => {
    const response = await api.post('/inventory/rawmaterials', materialData);
    return response.data;
  },

  // Multi-Agent Workflow Trigger (Data Extraction -> Production -> Purchasing -> Validation)
  triggerWorkflow: async (objective, materialId = 'RM001', requiredQty = 2000) => {
    try {
      // First try via FastAPI AI coordinator port 5070 or 8000
      const response = await axios.post(`${FASTAPI_URL}/api/workflows/trigger`, {
        objective: objective || `Floor Worker Stock Replenishment: Reorder ${requiredQty} units of ${materialId}`,
        material_id: materialId,
        required_quantity: requiredQty
      });
      return response.data;
    } catch (err) {
      // Fallback try through backend proxy or direct
      const response = await api.post('/admin/workflows/trigger', {
        objective: objective || `Floor Worker Stock Replenishment: Reorder ${requiredQty} units of ${materialId}`
      });
      return response.data;
    }
  },

  getActiveWorkflows: async () => {
    try {
      const response = await axios.get(`${FASTAPI_URL}/api/workflows`);
      return response.data;
    } catch {
      return [];
    }
  }
};

export default inventoryService;

