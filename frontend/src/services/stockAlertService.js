import api from './api';

export const stockAlertService = {
  /**
   * Get all stock alerts with deterministic net deficit.
   * Calls ASP.NET Core: GET /api/stock-alerts
   */
  async getAlerts() {
    const response = await api.get('/stock-alerts');
    return response.data;
  },

  /**
   * Get unread stock alerts for notification dropdown.
   * Calls ASP.NET Core: GET /api/stock-alerts/unread
   */
  async getUnreadAlerts() {
    const response = await api.get('/stock-alerts/unread');
    return response.data;
  },

  /**
   * Get a specific stock alert by ID.
   * Calls ASP.NET Core: GET /api/stock-alerts/{id}
   */
  async getAlertById(id) {
    const response = await api.get(`/stock-alerts/${id}`);
    return response.data;
  },

  /**
   * Mark a stock alert as read / acknowledged by manager.
   * Calls ASP.NET Core: PUT /api/stock-alerts/{id}/read
   */
  async markAsRead(id) {
    const response = await api.put(`/stock-alerts/${id}/read`);
    return response.data;
  },

  /**
   * Create a new stock alert (Floor Worker / IoT).
   * Calls ASP.NET Core: POST /api/stock-alerts
   */
  async createAlert(data) {
    const response = await api.post('/stock-alerts', data);
    return response.data;
  }
};

export default stockAlertService;
