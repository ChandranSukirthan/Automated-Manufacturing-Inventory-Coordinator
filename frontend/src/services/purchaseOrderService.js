import api from './api';

export const purchaseOrderService = {
  async getPurchaseOrders() {
    const response = await api.get('/purchase-orders');
    return response.data;
  },

  async getPurchaseOrderById(id) {
    const response = await api.get(`/purchase-orders/${id}`);
    return response.data;
  },

  async createPurchaseOrder(data) {
    const response = await api.post('/purchase-orders', data);
    return response.data;
  },

  async updatePurchaseOrder(id, data) {
    const response = await api.put(`/purchase-orders/${id}`, data);
    return response.data;
  },

  async submitPurchaseOrder(id) {
    const response = await api.post(`/purchase-orders/${id}/submit`);
    return response.data;
  },

  async approvePurchaseOrder(id) {
    const response = await api.post(`/purchase-orders/${id}/approve`);
    return response.data;
  },

  async rejectPurchaseOrder(id, notes = '') {
    const response = await api.post(`/purchase-orders/${id}/reject`, { notes });
    return response.data;
  },

  async revisePurchaseOrder(id, notes = '') {
    const response = await api.post(`/purchase-orders/${id}/revise`, { notes });
    return response.data;
  }
};

export default purchaseOrderService;

