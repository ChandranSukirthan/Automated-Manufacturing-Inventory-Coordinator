import '../../models/admin/machine_model.dart';
import '../../models/admin/shift_model.dart';
import '../../models/admin/workflow_model.dart';
import '../../models/admin/system_health_model.dart';
import '../../models/admin/user_model.dart';
import '../../models/admin/audit_log_model.dart';
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

  Future<MachineModel> createMachine({
    required String name,
    required int status,
    required double uptimeHours,
    required double maintenanceIntervalHours,
    required String location,
  }) async {
    final response = await apiClient.post('/machines', {
      'name': name,
      'status': status,
      'uptimeHours': uptimeHours,
      'maintenanceIntervalHours': maintenanceIntervalHours,
      'location': location,
    });
    return MachineModel.fromJson(response as Map<String, dynamic>);
  }

  Future<MachineModel> updateMachine(
    String id, {
    required String name,
    required int status,
    required double uptimeHours,
    required double maintenanceIntervalHours,
    required String location,
  }) async {
    final response = await apiClient.put('/machines/$id', {
      'name': name,
      'status': status,
      'uptimeHours': uptimeHours,
      'maintenanceIntervalHours': maintenanceIntervalHours,
      'location': location,
    });
    return MachineModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteMachine(String id) async {
    await apiClient.delete('/machines/$id');
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

  Future<ShiftModel> createShift({
    required String name,
    required int productionTarget,
    required int availableMaterial,
    int actualOutput = 0,
    int status = 0,
    required DateTime startTime,
    required DateTime endTime,
    String? materialSku,
    String? machineId,
    double? materialPerUnit,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'productionTarget': productionTarget,
      'availableMaterial': availableMaterial,
      'actualOutput': actualOutput,
      'status': status,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
    if (materialSku != null && materialSku.isNotEmpty) {
      body['materialSku'] = materialSku;
    }
    if (machineId != null && machineId.isNotEmpty) {
      body['machineId'] = machineId;
    }
    if (materialPerUnit != null) {
      body['materialPerUnit'] = materialPerUnit;
    }

    final response = await apiClient.post('/shifts', body);
    return ShiftModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ShiftModel> updateShift(
    String id, {
    required String name,
    required int productionTarget,
    required int availableMaterial,
    int actualOutput = 0,
    int status = 0,
    required DateTime startTime,
    required DateTime endTime,
    String? materialSku,
    String? machineId,
    double? materialPerUnit,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'productionTarget': productionTarget,
      'availableMaterial': availableMaterial,
      'actualOutput': actualOutput,
      'status': status,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
    if (materialSku != null && materialSku.isNotEmpty) {
      body['materialSku'] = materialSku;
    }
    if (machineId != null && machineId.isNotEmpty) {
      body['machineId'] = machineId;
    }
    if (materialPerUnit != null) {
      body['materialPerUnit'] = materialPerUnit;
    }

    final response = await apiClient.put('/shifts/$id', body);
    return ShiftModel.fromJson(response as Map<String, dynamic>);
  }

  // ========== Users ==========

  Future<List<UserModel>> getUsers() async {
    final response = await apiClient.get('/admin/users');
    if (response is List) {
      return response
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<UserModel> createUser({
    required String fullName,
    required String email,
    required String password,
    required int role,
  }) async {
    final response = await apiClient.post('/admin/users', {
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
    });
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(
    String id, {
    required String fullName,
    required String email,
  }) async {
    final response = await apiClient.put('/admin/users/$id', {
      'fullName': fullName,
      'email': email,
    });
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> activateUser(String id) async {
    await apiClient.put('/admin/users/$id/activate', {});
  }

  Future<void> deactivateUser(String id) async {
    await apiClient.put('/admin/users/$id/deactivate', {});
  }

  Future<UserModel> assignRole(String id, int role) async {
    final response = await apiClient.put('/admin/users/$id/role', {
      'role': role,
    });
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  // ========== Audit Logs ==========

  Future<List<AuditLogModel>> getAuditLogs({
    String? userName,
    String? action,
    String? entity,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryParams = <String, String>{};
    if (userName != null && userName.isNotEmpty) queryParams['userName'] = userName;
    if (action != null && action.isNotEmpty) queryParams['action'] = action;
    if (entity != null && entity.isNotEmpty) queryParams['entity'] = entity;
    if (fromDate != null) queryParams['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) queryParams['toDate'] = toDate.toIso8601String();

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';
    final response = await apiClient.get('/admin/audit-logs$queryString');
    if (response is List) {
      return response
          .map((item) => AuditLogModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
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
