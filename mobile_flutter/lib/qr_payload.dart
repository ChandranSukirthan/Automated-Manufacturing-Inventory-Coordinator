import 'models/quality_models.dart';

enum QrPayloadType { batch, inventoryRoll }

class QrPayloadException implements Exception {
  const QrPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QrPayload {
  const QrPayload._(this.value);

  final String value;

  factory QrPayload.parse(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      throw const QrPayloadException('The QR code is empty.');
    }
    if (value.contains(RegExp(r'\s')) ||
        value.startsWith('{') ||
        value.startsWith('[') ||
        value.contains('://')) {
      throw const QrPayloadException(
        'Unsupported QR format. Scan a plain-text batch or inventory roll ID.',
      );
    }
    return QrPayload._(value);
  }
}

class QrResolution {
  const QrResolution({required this.type, required this.batch});

  final QrPayloadType type;
  final BatchDetails batch;

  factory QrResolution.fromBatch(BatchDetails batch, String scannedValue) {
    if (batch.id == scannedValue) {
      return QrResolution(type: QrPayloadType.batch, batch: batch);
    }
    if (batch.inventoryRolls.any((roll) => roll.id == scannedValue)) {
      return QrResolution(type: QrPayloadType.inventoryRoll, batch: batch);
    }
    throw const QrPayloadException(
      'The scanned identifier was not found in the returned batch details.',
    );
  }
}
