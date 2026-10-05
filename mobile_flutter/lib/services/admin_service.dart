import 'api_client.dart';

class AdminService {
  const AdminService(this._api);

  final ApiClient _api;

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _api.get('/admin/users');
      return response is List ? response : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getRoles() async {
    try {
      final response = await _api.get('/admin/roles');
      return response is List ? response : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await _api.get('/admin/audit-logs');
      return response is List ? response : [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSystemHealth() async {
    try {
      final response = await _api.get('/admin/system-health');
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getAgentWorkflows() async {
    try {
      final response = await _api.get('/admin/agent-workflows');
      return response is List ? response : [];
    } catch (_) {
      return [];
    }
  }
}
