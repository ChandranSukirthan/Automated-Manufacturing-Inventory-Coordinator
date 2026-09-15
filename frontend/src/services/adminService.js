import api from './api';

const adminService = {
  // Users
  getAllUsers: async () => {
    const response = await api.get('/admin/users');
    return response.data;
  },

  getUserById: async (id) => {
    const response = await api.get(`/admin/users/${id}`);
    return response.data;
  },

  createUser: async (data) => {
    const response = await api.post('/admin/users', data);
    return response.data;
  },

  updateUser: async (id, data) => {
    const response = await api.put(`/admin/users/${id}`, data);
    return response.data;
  },

  activateUser: async (id) => {
    const response = await api.put(`/admin/users/${id}/activate`);
    return response.data;
  },

  deactivateUser: async (id) => {
    const response = await api.put(`/admin/users/${id}/deactivate`);
    return response.data;
  },

  assignRole: async (id, role) => {
    const response = await api.put(`/admin/users/${id}/role`, { role });
    return response.data;
  },

  // Roles
  getRoles: async () => {
    const response = await api.get('/admin/roles');
    return response.data;
  },

  // Audit Logs
  getAuditLogs: async (params = {}) => {
    const response = await api.get('/admin/audit-logs', { params });
    return response.data;
  },

  // Agent Workflows
  getAgentWorkflows: async () => {
    const response = await api.get('/admin/agent-workflows');
    return response.data;
  },

  getAgentWorkflowById: async (id) => {
    const response = await api.get(`/admin/agent-workflows/${id}`);
    return response.data;
  },

  approveWorkflow: async (workflowId) => {
    const response = await api.post(`/admin/agent-workflows/${workflowId}/approve`);
    return response.data;
  },

  rejectWorkflow: async (workflowId) => {
    const response = await api.post(`/admin/agent-workflows/${workflowId}/reject`);
    return response.data;
  },

  triggerWorkflow: async (data) => {
    const response = await api.post('/admin/agent-workflows/trigger', data);
    return response.data;
  },

  // System Health
  getSystemHealth: async () => {
    const response = await api.get('/admin/system-health');
    return response.data;
  }
};

export default adminService;

