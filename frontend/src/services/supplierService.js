import api from './api';

export const supplierService = {
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
  }
};

export default supplierService;

