import api from './api';

export const agentWorkflowService = {
  async getWorkflows() {
    const response = await api.get('/AgentWorkflow/workflows');
    return response.data;
  },

  async triggerEvaluation(itemId) {
    const response = await api.post(`/AgentWorkflow/trigger/${itemId}`);
    return response.data;
  }
};

export default agentWorkflowService;

