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

  release: async (id, data) => {
    const response = await api.post(`/quarantine/${id}/release`, data || {});
    return response.data;
  },

  releaseAllForDefect: async (defectId, data) => {
    const response = await api.post(`/quarantine/defect/${defectId}/release-all`, data || {});
    return response.data;
  }
};

export default quarantineService;
