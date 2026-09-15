import api from './api';

const AI_API_BASE_URL = import.meta.env.VITE_AI_API_BASE_URL || 'http://127.0.0.1:8000';

const defectService = {
  getAll: async () => {
    const response = await api.get('/defects');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/defects/${id}`);
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
    const response = await fetch(`${AI_API_BASE_URL}/quality/recommendation`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(data.detail || data.message || 'Unable to analyze the defect with AI.');
      error.response = { status: response.status, data: { ...data, message: data.detail || data.message } };
      throw error;
    }
    return data;
  }
};

export default defectService;
