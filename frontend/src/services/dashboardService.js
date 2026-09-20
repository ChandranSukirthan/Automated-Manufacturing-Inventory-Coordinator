import api from './api';

const dashboardService = {
  getQualitySummary: async () => {
    const response = await api.get('/dashboard/quality/summary');
    return response.data;
  }
};

export default dashboardService;
