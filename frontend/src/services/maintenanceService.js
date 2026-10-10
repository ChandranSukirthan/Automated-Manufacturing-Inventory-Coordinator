import api from './api';

const maintenanceService = {
  getAll: async () => {
    const response = await api.get('/maintenance');
    return response.data;
  },

  getByMachineId: async (machineId) => {
    const response = await api.get(`/machines/${machineId}/maintenance`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/maintenance', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/maintenance/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/maintenance/${id}`);
    return response.data;
  }
};

export default maintenanceService;

