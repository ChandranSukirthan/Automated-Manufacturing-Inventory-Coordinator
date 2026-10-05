import api from './api';

export const supplierService = {
  async getPage(params, signal) { return (await api.get("/suppliers/paged", { params, signal })).data; },
  async getQuotes(id) { return (await api.get(`/suppliers/${id}/quotes`)).data; },
  async saveQuote(id, data) { return (await (data.id ? api.put(`/suppliers/${id}/quotes/${data.id}`, data) : api.post(`/suppliers/${id}/quotes`, data))).data; },
  async deactivateQuote(id, quoteId) { await api.delete(`/suppliers/${id}/quotes/${quoteId}`); },
  async getSuppliers() {
    const response = await api.get('/suppliers');
    return response.data;
  },

  async getSupplierById(id) {
    const response = await api.get(`/suppliers/${id}`);
    return response.data;
  },

  async createSupplier(data) {
    const response = await api.post('/suppliers', data);
    return response.data;
  },

  async updateSupplier(id, data) {
    const response = await api.put(`/suppliers/${id}`, data);
    return response.data;
  },

  async deleteSupplier(id) {
    const response = await api.delete(`/suppliers/${id}`);
    return response.data;
  },

  async getAnalytics() {
    const response = await api.get('/suppliers/analytics');
    return response.data;
  },

  async getPerformance(id) {
    const response = await api.get(`/suppliers/${id}/performance`);
    return response.data;
  },

  async verifySupplier(id, data = {}) {
    const response = await api.post(`/suppliers/${id}/verify`, data);
    return response.data;
  }
};

export default supplierService;

