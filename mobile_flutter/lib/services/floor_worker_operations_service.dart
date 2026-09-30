import 'api_client.dart';
import 'session_storage.dart';

class ProductionShiftSummary {
  const ProductionShiftSummary({
    required this.id,
    required this.name,
    required this.productionTarget,
    required this.availableMaterial,
    required this.adjustedOutput,
    required this.actualOutput,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String name;
  final int productionTarget;
  final int availableMaterial;
  final int adjustedOutput;
  final int actualOutput;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;

  factory ProductionShiftSummary.fromJson(Map<String, dynamic> json) =>
      ProductionShiftSummary(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unnamed shift',
        productionTarget: _asInt(json['productionTarget']),
        availableMaterial: _asInt(json['availableMaterial']),
        adjustedOutput: _asInt(json['adjustedOutput']),
        actualOutput: _asInt(json['actualOutput']),
        status: _shiftStatus(json['status']),
        startTime: DateTime.tryParse(json['startTime']?.toString() ?? ''),
        endTime: DateTime.tryParse(json['endTime']?.toString() ?? ''),
      );
}

class IncomingDelivery {
  const IncomingDelivery({
    required this.id,
    required this.poNumber,
    required this.supplierName,
    required this.status,
    required this.updatedAt,
  });

  final int id;
  final String poNumber;
  final String supplierName;
  final String status;
  final DateTime? updatedAt;

  factory IncomingDelivery.fromJson(Map<String, dynamic> json) =>
      IncomingDelivery(
        id: _asInt(json['id']),
        poNumber: json['poNumber']?.toString() ?? 'Unnumbered delivery',
        supplierName: json['supplierName']?.toString() ?? 'Supplier pending',
        status: json['status']?.toString() ?? 'Unknown',
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// The API serializes [ShiftStatus] as its integer enum value. Keep that
/// transport detail out of the UI, while also accepting named values if the
/// server switches to string-enum serialization later.
String _shiftStatus(dynamic value) {
  final numericStatus = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (numericStatus != null) {
    return const {0: 'Planned', 1: 'Active', 2: 'Completed'}[numericStatus] ??
        'Unknown';
  }

  final status = value?.toString().trim() ?? '';
  switch (status.toLowerCase()) {
    case 'inprogress':
    case 'in_progress':
    case 'active':
      return 'Active';
    case 'planned':
      return 'Planned';
    case 'completed':
      return 'Completed';
    default:
      return status.isEmpty ? 'Unknown' : status;
  }
}

/// Read-only operations used by the Floor Worker dashboard.
class FloorWorkerOperationsService {
  FloorWorkerOperationsService({ApiClient? api})
    : _api = api ?? ApiClient(storage: SessionStorage());

  final ApiClient _api;

  Future<List<ProductionShiftSummary>> fetchProductionShifts() async {
    final response = await _api.get('/shifts') as List<dynamic>;
    return response
        .map(
          (item) =>
              ProductionShiftSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<IncomingDelivery>> fetchIncomingDeliveries() async {
    final response = await _api.get('/purchase-orders') as List<dynamic>;
    return response
        .map((item) => IncomingDelivery.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
