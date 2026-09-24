import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/session_storage.dart';
import 'package:mobile_flutter/services/quality_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(storage: SessionStorage());

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> get(String path) async => null;

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body ?? const <String, dynamic>{};
    return {
      'id': 'DEF-001',
      'batchId': 'BATCH-001',
      'productType': 'BoxPouch',
      'severity': 'HIGH',
      'description': 'Seal failure',
      'createdAt': '2026-09-12T06:00:00Z',
      'status': 'Open',
      'affectedInventory': ['ROLL-001'],
    };
  }

  @override
  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastBody = body;
    return {
      'id': 'DEF-001',
      'batchId': 'BATCH-001',
      'productType': 'BoxPouch',
      'severity': 'HIGH',
      'description': 'Seal failure',
      'createdAt': '2026-09-12T06:00:00Z',
      'status': 'Open',
      'affectedInventory': ['ROLL-001'],
    };
  }
}

void main() {
  test('createDefect uses the backend defect contract and sku payload', () async {
    final api = FakeApiClient();
    final service = QualityService(api);

    await service.createDefect(
      skuCode: 'RM-STEEL-001',
      batchId: 'BATCH-001',
      productType: 'BoxPouch',
      severity: 'HIGH',
      description: 'Seal failure',
      status: 'Open',
      affectedInventory: ['ROLL-001'],
    );

    expect(api.lastMethod, 'POST');
    expect(api.lastPath, '/defects');
    expect(api.lastBody?['skuCode'], 'RM-STEEL-001');
    expect(api.lastBody?['productType'], 'BoxPouch');
    expect(api.lastBody?['affectedInventory'], ['ROLL-001']);
  });

  test('analyzeDefect calls the backend proxy endpoint with sku payload', () async {
    final api = FakeApiClient();
    final service = QualityService(api);

    await service.analyzeDefect(
      skuCode: 'RM-STEEL-001',
      batchId: 'BATCH-001',
      productType: 'BoxPouch',
      severity: 'HIGH',
      description: 'Seal failure',
    );

    expect(api.lastMethod, 'POST');
    expect(api.lastPath, '/defects/analyze');
    expect(api.lastBody?['skuCode'], 'RM-STEEL-001');
    expect(api.lastBody?['batchId'], 'BATCH-001');
    expect(api.lastBody?['severity'], 'HIGH');
  });
}
