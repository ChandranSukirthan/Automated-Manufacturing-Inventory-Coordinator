import api from './api';

const machineService = {
  getAll: async () => {
    const response = await api.get('/machines');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/machines/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/machines', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/machines/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/machines/${id}`);
    return response.data;
  },

  calculateMaintenance: async (id) => {
    const response = await api.post(`/machines/${id}/calculate-maintenance`);
    return response.data;
  }
};

export default machineService;

