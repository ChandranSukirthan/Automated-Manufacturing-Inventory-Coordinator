import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/models/auth_models.dart';

void main() {
  test('normalizes the API QualityInspector role name', () {
    final user = UserSummary.fromJson({
      'id': 1,
      'fullName': 'QA User',
      'email': 'qa@example.com',
      'role': 'QualityInspector',
    });

    expect(user.role, 'QualityInspector');
    expect(user.isQualityInspector, isTrue);
  });

  test('accepts numeric role values from the same API contract', () {
    final user = UserSummary.fromJson({
      'id': 1,
      'fullName': 'QA User',
      'email': 'qa@example.com',
      'role': 2,
    });

    expect(user.role, 'QualityInspector');
    expect(user.isQualityInspector, isTrue);
  });
}