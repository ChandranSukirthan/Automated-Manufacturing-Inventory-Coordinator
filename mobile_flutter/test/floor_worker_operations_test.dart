import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/floor_worker_operations_service.dart';

void main() {
  test(
    'maps production output and the active shift state from the API contract',
    () {
      final shift = ProductionShiftSummary.fromJson({
        'id': 'shift-1',
        'name': 'Morning shift',
        'productionTarget': 1000,
        'availableMaterial': 800,
        'adjustedOutput': 800,
        'actualOutput': 600,
        'status': 1,
        'startTime': '2026-09-28T08:00:00Z',
        'endTime': '2026-09-28T16:00:00Z',
      });

      expect(shift.status, 'Active');
      expect(shift.adjustedOutput, 800);
      expect(shift.actualOutput, 600);
    },
  );

  test('maps an incoming delivery from the purchase-order API contract', () {
    final delivery = IncomingDelivery.fromJson({
      'id': 11,
      'poNumber': 'PO-2026-0011',
      'supplierName': 'AMIC Packaging Ltd',
      'status': 'Sent',
      'updatedAt': '2026-09-28T10:00:00Z',
    });

    expect(delivery.poNumber, 'PO-2026-0011');
    expect(delivery.status, 'Sent');
  });
}
