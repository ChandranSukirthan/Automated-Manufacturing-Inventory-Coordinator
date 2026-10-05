import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/utils/locale.dart';

void main() {
  test('LKR amounts use grouping and preserve explicitly recorded currency', () {
    expect(formatMoney(5550000), 'LKR 5,550,000.00');
    expect(formatMoney(2150.4, currency: 'usd'), 'USD 2,150.40');
    expect(formatMoney(-1000), 'LKR -1,000.00');
    expect(formatMoney(double.nan), 'Not available');
  });
}
