import api from './api';

const maintenanceService = {
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
  }
};

export default maintenanceService;

