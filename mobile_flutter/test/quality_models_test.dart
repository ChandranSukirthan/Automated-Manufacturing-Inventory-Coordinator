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
      'severity': 'Critical',
      'description': 'Seal failure',
      'createdAt': '2026-09-12T06:00:00Z',
      'status': 'Open',
      'reportedByUserId': 'user-1',
      'affectedInventory': ['ROLL-001', 'ROLL-002'],
    });

    expect(defect.severity, 'Critical');
    expect(defect.reportedByUserId, 'user-1');
    expect(defect.description, 'Seal failure');
    expect(defect.affectedInventory, ['ROLL-001', 'ROLL-002']);
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

  test('AiValidationData parses and exposes dual assessment properties correctly', () {
    final aiData = AiValidationData.fromJson({
      'workflowId': 'WF-QA-PO-2026-0033',
      'poNumber': 'PO-2026-0033',
      'status': 'INVALID',
      'isValid': false,
      'qualitySafetyStatus': 'QUARANTINE_ACTIVE',
      'manualResolutionStatus': 'PENDING_REVIEW',
      'inspectorNotes': 'Pending inspector review',
      'supplierValidation': 'VALID',
      'budgetCheck': 'VALID',
      'poMathematicalCheck': 'VALID',
      'materialValidation': 'INVALID',
      'quarantinedRollsCount': 2,
    });

    expect(aiData.workflowId, 'WF-QA-PO-2026-0033');
    expect(aiData.origAiOutcome, 'INVALID');
    expect(aiData.origSafetyStatus, 'QUARANTINE_ACTIVE');
    expect(aiData.safetyGateState, 'BLOCKED');
    expect(aiData.currentManualResolution, 'PENDING REVIEW');
    expect(aiData.currentQuarantineDisposition, 'ACTIVE');
    expect(aiData.automatedCheckItems.length, 4);
    expect(aiData.passedChecks.length, 3);
    expect(aiData.automatedSummary, '3 / 4 PASSED');
  });
}