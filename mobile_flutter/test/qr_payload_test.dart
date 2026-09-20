import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/quality_models.dart';
import 'package:mobile_flutter/qr_payload.dart';

BatchDetails batchDetails() => const BatchDetails(
  id: 'BATCH111',
  productType: 'BoxPouch',
  inventoryRolls: [
    InventoryRoll(id: 'ROLL11', batchId: 'BATCH111', status: 'Available'),
  ],
);

void main() {
  test('accepts a plain-text batch QR payload', () {
    expect(QrPayload.parse(' BATCH111 ').value, 'BATCH111');
  });

  test('rejects empty QR payloads', () {
    expect(() => QrPayload.parse('  '), throwsA(isA<QrPayloadException>()));
  });

  test('rejects unsupported structured and URL payloads', () {
    expect(
      () => QrPayload.parse('{"batchId":"BATCH111"}'),
      throwsA(isA<QrPayloadException>()),
    );
    expect(
      () => QrPayload.parse('https://example.com/BATCH111'),
      throwsA(isA<QrPayloadException>()),
    );
  });

  test('resolves a batch QR payload from returned batch details', () {
    final resolution = QrResolution.fromBatch(batchDetails(), 'BATCH111');

    expect(resolution.type, QrPayloadType.batch);
    expect(resolution.batch.id, 'BATCH111');
  });

  test('resolves a roll QR payload to its related batch', () {
    final resolution = QrResolution.fromBatch(batchDetails(), 'ROLL11');

    expect(resolution.type, QrPayloadType.inventoryRoll);
    expect(resolution.batch.id, 'BATCH111');
  });

  test('rejects an unknown identifier in returned batch details', () {
    expect(
      () => QrResolution.fromBatch(batchDetails(), 'UNKNOWN'),
      throwsA(isA<QrPayloadException>()),
    );
  });
}
