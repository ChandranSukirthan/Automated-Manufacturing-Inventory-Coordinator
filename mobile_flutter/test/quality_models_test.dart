import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/models/quality_models.dart';

void main() {
  test('parses a backend batch with inventory roll statuses', () {
    final batch = BatchDetails.fromJson({
      'id': 'BATCH-001',
      'productType': 'Bottle',
      'inventoryRolls': [
        {'id': 'ROLL-001', 'batchId': 'BATCH-001', 'status': 'Available'},
        {'id': 'ROLL-002', 'batchId': 'BATCH-001', 'status': 'Quarantined'},
      ],
    });

    expect(batch.id, 'BATCH-001');
    expect(batch.productType, 'Bottle');
    expect(batch.inventoryRolls, hasLength(2));
    expect(batch.inventoryRolls.last.status, 'Quarantined');
  });

  test('preserves backend defect fields including reporter', () {
    final defect = DefectReport.fromJson({
      'id': 'defect-1',
      'batchId': 'BATCH-001',
      'productType': 'BoxPouch',
      'severity': 'CRITICAL',
      'description': 'Seal failure',
      'createdAt': '2026-09-12T06:00:00Z',
      'status': 'Open',
      'reportedByUserId': 'user-1',
    });

    expect(defect.severity, 'CRITICAL');
    expect(defect.reportedByUserId, 'user-1');
    expect(defect.description, 'Seal failure');
  });

  test('supports the derived quality dashboard metrics', () {
    const summary = QualitySummary(
      totalDefects: 1,
      highSeverityDefects: 1,
      activeQuarantines: 1,
      releasedQuarantines: 0,
      openDefects: 1,
      quarantinedBatches: 1,
      affectedInventory: 1,
      releasedInventory: 0,
    );

    final updated = summary.copyWith(releasedInventory: 2);

    expect(updated.totalDefects, 1);
    expect(updated.releasedInventory, 2);
  });
}