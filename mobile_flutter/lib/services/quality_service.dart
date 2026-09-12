import '../models/quality_models.dart';
import 'api_client.dart';

class QualityService {
  QualityService(this.api);

  final ApiClient api;

  Future<Map<String, dynamic>> getRoleDashboard(String role) async {
    final path = switch (role) {
      'FloorWorker' => '/dashboard/worker',
      'SupplyChainManager' => '/dashboard/manager',
      'ITAdmin' => '/dashboard/admin',
      _ => throw const ApiException(
        'This dashboard is not available for the current role.',
      ),
    };
    return await api.get(path) as Map<String, dynamic>;
  }

  Future<QualitySummary> getSummary() async => QualitySummary.fromJson(
    await api.get('/dashboard/quality/summary') as Map<String, dynamic>,
  );

  Future<List<DefectReport>> getDefects() async =>
      _list(await api.get('/defects'), DefectReport.fromJson);

  Future<DefectReport> getDefect(String id) async => DefectReport.fromJson(
    await api.get('/defects/$id') as Map<String, dynamic>,
  );

  Future<DefectReport> createDefect({
    required String batchId,
    required String productType,
    required String severity,
    required String description,
    String status = 'Open',
  }) async => DefectReport.fromJson(
    await api.post('/defects', {
      'batchId': batchId,
      'productType': productType,
      'severity': severity,
      'description': description,
      'status': status,
    }) as Map<String, dynamic>,
  );

  Future<DefectReport> updateDefect({
    required String id,
    required String batchId,
    required String productType,
    required String severity,
    required String description,
    required String status,
  }) async => DefectReport.fromJson(
    await api.put('/defects/$id', {
      'batchId': batchId,
      'productType': productType,
      'severity': severity,
      'description': description,
      'status': status,
    }) as Map<String, dynamic>,
  );

  Future<void> deleteDefect(String id) => api.delete('/defects/$id');

  Future<List<QuarantineRecord>> getQuarantines() async =>
      _list(await api.get('/quarantine'), QuarantineRecord.fromJson);

  Future<QuarantineRecord> getQuarantine(String id) async =>
      QuarantineRecord.fromJson(
        await api.get('/quarantine/$id') as Map<String, dynamic>,
      );

  Future<QuarantineRecord> quarantineDefect(
    String defectId,
    String reason,
    String inventoryRollId,
  ) async => QuarantineRecord.fromJson(
    await api.post('/defects/$defectId/quarantine', {
      'reason': reason,
      if (inventoryRollId.trim().isNotEmpty) 'inventoryRollId': inventoryRollId,
    }) as Map<String, dynamic>,
  );

  Future<QuarantineRecord> releaseQuarantine(String id) async =>
      QuarantineRecord.fromJson(
        await api.post('/quarantine/$id/release') as Map<String, dynamic>,
      );

  List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parser) =>
      (value as List<dynamic>)
          .map((item) => parser(item as Map<String, dynamic>))
          .toList();
}
