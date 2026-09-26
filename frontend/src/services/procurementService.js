import api from './api';

export const procurementService = {
  /**
   * Initialize a new procurement request with calculated net deficit.
   * Calls ASP.NET Core: POST /api/procurement/request
   */
  async createRequest(data) {
    const response = await api.post('/procurement/request', data);
    return response.data;
  },

  /**
   * Trigger the 4-agent LangGraph workflow via ASP.NET Core.
   * Calls ASP.NET Core: POST /api/procurement/{id}/start
   */
  async startResearch(id) {
    const response = await api.post(`/procurement/${id}/start`);
    return response.data;
  },

  /**
   * Run research alias (POST /api/procurement/{id}/research)
   */
  async runResearch(id) {
    const response = await api.post(`/procurement/${id}/research`);
    return response.data;
  },

  /**
   * Retrieve procurement request by ID.
   * Calls ASP.NET Core: GET /api/procurement/{id}
   */
  async getRequest(id) {
    const response = await api.get(`/procurement/${id}`);
    return response.data;
  },

  /**
   * List all procurement requests.
   * Calls ASP.NET Core: GET /api/procurement
   */
  async getAllRequests() {
    const response = await api.get('/procurement');
    return response.data;
  },

  /**
   * Retrieve evaluated supplier candidates.
   * Calls ASP.NET Core: GET /api/procurement/{id}/candidates
   */
  async getCandidates(id) {
    const response = await api.get(`/procurement/${id}/candidates`);
    return response.data;
  },

  /**
   * Retrieve AI recommendation summary and rationale.
   * Calls ASP.NET Core: GET /api/procurement/{id}/recommendation
   */
  async getRecommendation(id) {
    const response = await api.get(`/procurement/${id}/recommendation`);
    return response.data;
  },

  /**
   * Retrieve end-to-end lifecycle status tracking:
   * procurement + PO + Stripe payment + SendGrid email.
   * Calls ASP.NET Core: GET /api/procurement/{id}/status
   */
  async getStatus(id) {
    const response = await api.get(`/procurement/${id}/status`);
    return response.data;
  },

  /**
   * Verify and onboard an UNVERIFIED supplier candidate.
   * Calls ASP.NET Core: POST /api/procurement/{id}/verify-supplier?candidateId={candidateId}
   */
  async verifySupplierCandidate(id, candidateId, data) {
    const response = await api.post(
      `/procurement/${id}/verify-supplier?candidateId=${candidateId}`,
      data
    );
    return response.data;
  },

  /**
   * Generate Draft PO from an evaluated and approved candidate.
   * Calls ASP.NET Core: POST /api/procurement/{id}/create-draft-po?candidateId={candidateId}
   */
  async createDraftPo(id, candidateId) {
    const response = await api.post(
      `/procurement/${id}/create-draft-po?candidateId=${candidateId}`
    );
    return response.data;
  },

  /**
   * Generate Draft PO alias (POST /api/procurement/{id}/generate-draft-po?candidateId={candidateId})
   */
  async generateDraftPo(id, candidateId) {
    const response = await api.post(
      `/procurement/${id}/generate-draft-po?candidateId=${candidateId}`
    );
    return response.data;
  }
};

export default procurementService;
