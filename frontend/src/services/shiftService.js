import api from './api';

const shiftService = {
  getAll: async () => {
    const response = await api.get('/shifts');
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/shifts', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/shifts/${id}`, data);
    return response.data;
  },

  adjustOutput: async (id) => {
    const response = await api.post(`/shifts/${id}/adjust-output`);
    return response.data;
  }
};

export default shiftService;

