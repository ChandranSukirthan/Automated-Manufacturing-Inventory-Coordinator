import 'api_client.dart';
import 'session_storage.dart';
import '../models/worker_workflow_models.dart';

int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
num _toNum(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

class InventoryItemModel {
  final int id;
  final String sku;
  final String name;
  final String category;
  final int stockLevel;
  final int reorderThreshold;

  InventoryItemModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.stockLevel,
    required this.reorderThreshold,
  });

    factory InventoryItemModel.fromJson(Map<String, dynamic> json) =>
        InventoryItemModel(
            id: _toInt(json['id']),
            sku: json['sku'] as String? ?? '',
            name: json['name'] as String? ?? '',
            category: json['category'] as String? ?? '',
            stockLevel: _toInt(json['stockLevel']),
            reorderThreshold: _toInt(json['reorderThreshold']),
        );
  
}

class InventoryRollModel {
  final String id;
  final String rollIdentifier;
  final String status;
  final num currentQuantity;
  final num initialQuantity;
  final int rawMaterialId;
  final String? batchId;

  InventoryRollModel({
    required this.id,
    required this.rollIdentifier,
    required this.status,
    required this.currentQuantity,
    required this.initialQuantity,
    required this.rawMaterialId,
    this.batchId,
  });

  factory InventoryRollModel.fromJson(Map<String, dynamic> json) =>
      InventoryRollModel(
        id: json['id']?.toString() ?? '',
        rollIdentifier: json['rollIdentifier']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        currentQuantity: _toNum(json['currentQuantity']),
        initialQuantity: _toNum(json['initialQuantity']),
        rawMaterialId: _toInt(json['rawMaterialId']),
        batchId: json['batchId']?.toString(),
      );
}

class RawMaterialModel {
  final int id;
  final String skuCode;
  final String name;
  final String category;
  final String unitOfMeasure;
  final num reorderThreshold;

  RawMaterialModel({
    required this.id,
    required this.skuCode,
    required this.name,
    required this.category,
    required this.unitOfMeasure,
    required this.reorderThreshold,
  });

  factory RawMaterialModel.fromJson(Map<String, dynamic> json) =>
      RawMaterialModel(
        id: _toInt(json['id']),
        skuCode: json['skuCode']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        unitOfMeasure: json['unitOfMeasure']?.toString() ?? '',
        reorderThreshold: _toNum(json['reorderThreshold']),
      );
}

class StockAlertModel {
  final int id;
  final String sku;
  final String packagingType;
  final int quantityRequested;
  final String status;
  final String workerId;

  StockAlertModel({
    required this.id,
    required this.sku,
    required this.packagingType,
    required this.quantityRequested,
    required this.status,
    required this.workerId,
  });

  factory StockAlertModel.fromJson(Map<String, dynamic> json) => StockAlertModel(
        id: _toInt(json['id']),
        sku: json['sku'] as String? ?? '',
        packagingType: json['packagingType'] as String? ?? '',
        quantityRequested: _toInt(json['quantityRequested']),
        status: json['status'] as String? ?? '',
        workerId: json['workerId'] as String? ?? '',
      );
}

class InventoryApiService {
  InventoryApiService({ApiClient? api})
      : _api = api ?? ApiClient(storage: SessionStorage());

  final ApiClient _api;

  Future<List<InventoryItemModel>> fetchInventory() async {
    final data = await _api.get('/inventory') as List<dynamic>;
    return data
        .map((item) => InventoryItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<StockAlertModel>> fetchAlerts() async {
    final data = await _api.get('/inventory/alerts') as List<dynamic>;
    return data
        .map((item) => StockAlertModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<InventoryItemModel>> fetchOwnedInventory() => fetchInventory();

  Future<List<InventoryRollModel>> fetchOwnedRolls() async {
    final data = await _api.get('/inventory/rolls') as List<dynamic>;
    return data
        .map((item) => InventoryRollModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RawMaterialModel>> fetchRawMaterials() async {
    final data = await _api.get('/inventory/rawmaterials') as List<dynamic>;
    return data
        .map((item) => RawMaterialModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchStockLevels() async {
    final data = await _api.get('/inventory/stock-levels') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(int id) async {
    final data = await _api.get('/inventory/$id/history') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<WorkerWorkflowResult> triggerReplenishment({
    required String materialId,
    required num requiredQuantity,
  }) async {
    final data = await _api.post('/inventory/trigger-replenishment', {
      'materialId': materialId,
      'requiredQuantity': requiredQuantity,
    });
    return WorkerWorkflowResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateAlertStatus(int id, String status) async {
    await _api.put('/inventory/alerts/$id', {'status': status});
  }

  Future<void> createAlert({
    required String sku,
    required String packagingType,
    required int quantityRequested,
  }) async {
    await _api.post('/inventory/alerts', {
      'sku': sku,
      'packagingType': packagingType,
      'quantityRequested': quantityRequested,
    });
  }

  Future<void> createItem({
    required String sku,
    required String name,
    required String category,
    required int stockLevel,
    required int reorderThreshold,
  }) async {
    await _api.post('/inventory', {
      'sku': sku,
      'name': name,
      'category': category,
      'stockLevel': stockLevel,
      'reorderThreshold': reorderThreshold,
    });
  }

  Future<void> updateItem(InventoryItemModel item) async {
    await _api.put('/inventory/${item.id}', {
      'id': item.id,
      'sku': item.sku,
      'name': item.name,
      'category': item.category,
      'stockLevel': item.stockLevel,
      'reorderThreshold': item.reorderThreshold,
    });
  }

  Future<void> deleteItem(int id) => _api.delete('/inventory/$id');

  Future<void> createRoll({
    required String rollIdentifier,
    required double quantity,
    required int rawMaterialId,
  }) async {
    await _api.post('/inventory/rolls', {
      'rollIdentifier': rollIdentifier,
      'initialQuantity': quantity,
      'currentQuantity': quantity,
      'rawMaterialId': rawMaterialId,
    });
  }

  Future<Map<String, dynamic>> lookupRoll(String qrCode) async =>
      await _api.get('/inventory/roll/qr/${Uri.encodeComponent(qrCode)}')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> triggerDataExtractionAgent(String batchName) async {
    final data = await _api.post('/inventory/trigger-replenishment', {
      'objective': 'Floor Worker Stock Replenishment: Analyze $batchName',
      'materialId': batchName,
      'requiredQuantity': 2000,
    });
    return data as Map<String, dynamic>;
  }
}
