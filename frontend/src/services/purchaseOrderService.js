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
  },

  async processPayment(id, forceDispatch = true) {
    const response = await api.post(`/purchase-orders/${id}/process-payment?forceDispatch=${forceDispatch}`);
    return response.data;
  },

  async downloadPdf(id, poNumber) {
    const response = await api.get(`/purchase-orders/${id}/pdf`, {
      responseType: 'blob'
    });
    const blob = new Blob([response.data], { type: 'application/pdf' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `PurchaseOrder_${poNumber || id}.pdf`);
    document.body.appendChild(link);
    link.click();
    link.parentNode.removeChild(link);
    window.URL.revokeObjectURL(url);
  }
};

export default purchaseOrderService;

