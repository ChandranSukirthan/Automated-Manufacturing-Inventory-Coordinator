import api from './api';

const defectService = {
  getAll: async () => {
    const response = await api.get('/defects');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/defects/${id}`);
    return response.data;
  },

  getBatch: async (id) => {
    const response = await api.get(`/batches/${encodeURIComponent(id)}`);
    return response.data;
  },

  create: async (payload) => {
    const response = await api.post('/defects', payload);
    return response.data;
  },

  update: async (id, payload) => {
    const response = await api.put(`/defects/${id}`, payload);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/defects/${id}`);
    return response.data;
  },

  quarantine: async (id, payload) => {
    const response = await api.post(`/defects/${id}/quarantine`, payload);
    return response.data;
  },

  analyzeWithAi: async (payload) => {
    const response = await api.post('/defects/analyze', payload);
    return response.data;
  }
};

export default defectService;
