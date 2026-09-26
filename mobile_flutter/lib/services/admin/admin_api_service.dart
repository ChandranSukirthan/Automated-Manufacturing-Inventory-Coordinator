import '../../models/admin/machine_model.dart';
import '../../models/admin/shift_model.dart';
import '../../models/admin/workflow_model.dart';
import '../../models/admin/system_health_model.dart';
import '../api_client.dart';

class AdminApiService {
  final ApiClient apiClient;

  AdminApiService({required this.apiClient});

  // ========== Machines ==========

  Future<List<MachineModel>> getMachines() async {
    final response = await apiClient.get('/machines');
    if (response is List) {
      return response
          .map((item) => MachineModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<MachineModel> getMachineById(String id) async {
    final response = await apiClient.get('/machines/$id');
    return MachineModel.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> calculateMaintenance(String machineId) async {
    final response = await apiClient.post('/machines/$machineId/calculate-maintenance');
    return response is Map<String, dynamic> ? response : {};
  }

  Future<List<MaintenanceLogModel>> getMaintenanceLogs(String machineId) async {
    final response = await apiClient.get('/machines/$machineId/maintenance');
    if (response is List) {
      return response
          .map((item) => MaintenanceLogModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ========== Shifts ==========

  Future<List<ShiftModel>> getShifts() async {
    final response = await apiClient.get('/shifts');
    if (response is List) {
      return response
          .map((item) => ShiftModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> adjustShiftOutput(String shiftId) async {
    final response = await apiClient.post('/shifts/$shiftId/adjust-output');
    return response is Map<String, dynamic> ? response : {};
  }

  // ========== Agent Workflows ==========

  Future<List<WorkflowModel>> getAgentWorkflows() async {
    final response = await apiClient.get('/admin/agent-workflows');
    if (response is List) {
      return response
          .map((item) => WorkflowModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<WorkflowModel> getWorkflowById(String id) async {
    final response = await apiClient.get('/admin/agent-workflows/$id');
    return WorkflowModel.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> approveWorkflow(String workflowId) async {
    return await apiClient.post('/admin/agent-workflows/$workflowId/approve');
  }

  Future<dynamic> rejectWorkflow(String workflowId) async {
    return await apiClient.post('/admin/agent-workflows/$workflowId/reject');
  }

  Future<dynamic> triggerWorkflow(String objective, [String? workflowId]) async {
    final body = <String, dynamic>{'objective': objective};
    if (workflowId != null) {
      body['workflowId'] = workflowId;
    }
    return await apiClient.post('/admin/agent-workflows/trigger', body);
  }

  // ========== System Health ==========

  Future<SystemHealthModel> getSystemHealth() async {
    final response = await apiClient.get('/admin/system-health');
    if (response is Map<String, dynamic>) {
      return SystemHealthModel.fromJson(response);
    }
    return SystemHealthModel(overallStatus: 'ONLINE', services: []);
  }
}
