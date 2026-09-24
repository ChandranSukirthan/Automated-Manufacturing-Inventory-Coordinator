import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/session_storage.dart';
import 'package:mobile_flutter/services/quality_service.dart';

class FakeQuarantineApi extends ApiClient {
  FakeQuarantineApi() : super(storage: SessionStorage());

  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    lastPath = path;
    lastBody = body ?? const <String, dynamic>{};

    if (path.contains('/quarantine/')) {
      return {
        'id': 'QUAR-1',
        'defectReportId': 'DEF-1',
        'inventoryRollId': 'ROLL-1',
        'batchId': 'BATCH-001',
        'reason': 'Seal issue',
        'status': 'Released',
        'createdAt': '2026-09-12T06:00:00Z',
        'releasedAt': '2026-09-13T06:00:00Z',
      };
    }

    return [
      {
        'id': 'QUAR-1',
        'defectReportId': 'DEF-1',
        'inventoryRollId': 'ROLL-1',
        'batchId': 'BATCH-001',
        'reason': 'Seal issue',
        'status': 'Active',
        'createdAt': '2026-09-12T06:00:00Z',
      },
    ];
  }

  @override
  Future<dynamic> get(String path) async {
    lastPath = path;
    if (path == '/quarantine/QUAR-1') {
      return {
        'id': 'QUAR-1',
        'defectReportId': 'DEF-1',
        'inventoryRollId': 'ROLL-1',
        'batchId': 'BATCH-001',
        'reason': 'Seal issue',
        'status': 'Active',
        'createdAt': '2026-09-12T06:00:00Z',
      };
    }
    return [
      {
        'id': 'QUAR-1',
        'defectReportId': 'DEF-1',
        'inventoryRollId': 'ROLL-1',
        'batchId': 'BATCH-001',
        'reason': 'Seal issue',
        'status': 'Active',
        'createdAt': '2026-09-12T06:00:00Z',
      },
    ];
  }
}

void main() {
  test('quarantineDefect uses the backend defect quarantine endpoint and returns a list', () async {
    final api = FakeQuarantineApi();
    final service = QualityService(api);

    final records = await service.quarantineDefect(
      'DEF-1',
      'Seal issue',
      'ROLL-1',
    );

    expect(api.lastPath, '/defects/DEF-1/quarantine');
    expect(api.lastBody?['reason'], 'Seal issue');
    expect(api.lastBody?.containsKey('inventoryRollId'), isFalse);
    expect(records, isNotEmpty);
    expect(records.first.status, 'Active');
  });

  test('releaseQuarantine posts to the backend release route and maps the released status', () async {
    final api = FakeQuarantineApi();
    final service = QualityService(api);

    final record = await service.releaseQuarantine('QUAR-1');

    expect(api.lastPath, '/quarantine/QUAR-1/release');
    expect(record.status, 'Released');
    expect(record.releasedAt, isNotNull);
  });
}
