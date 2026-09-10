import api from './api';

const quarantineService = {
  getAll: async () => {
    const response = await api.get('/quarantine');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/quarantine/${id}`);
    return response.data;
  },

  release: async (id) => {
    const response = await api.post(`/quarantine/${id}/release`);
    return response.data;
  }
};

export default quarantineService;
