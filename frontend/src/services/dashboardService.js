import api from './api';

const dashboardService = {
  getQualitySummary: async () => {
    const response = await api.get('/dashboard/quality/summary');
    return response.data;
  },

  getAiValidation: async () => {
    const response = await api.get('/quality/ai-validation');
    return response.data;
  },

  getAiValidationHistory: async () => {
    const response = await api.get('/quality/ai-validation/history');
    return response.data;
  },

  resolveAiValidation: async (workflowId, data) => {
    const response = await api.post(`/quality/ai-validation/${workflowId}/resolve`, data);
    return response.data;
  }
};

export default dashboardService;
