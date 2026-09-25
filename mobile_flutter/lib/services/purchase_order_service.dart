import '../models/procurement_models.dart';
import '../models/purchase_order_models.dart';
import 'api_client.dart';

class PurchaseOrderService {
  const PurchaseOrderService(this._api);

  final ApiClient _api;

  /// GET /api/purchase-orders — list all purchase orders
  Future<List<PurchaseOrderSummary>> getPurchaseOrders() async {
    final response = await _api.get('/purchase-orders');
    if (response is List) {
      return response
          .map((item) => PurchaseOrderSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /api/purchase-orders/{id} — full PO details
  Future<PurchaseOrderDetail> getPurchaseOrderById(int id) async {
    final response = await _api.get('/purchase-orders/$id');
    if (response is Map<String, dynamic>) {
      return PurchaseOrderDetail.fromJson(response);
    }
    throw const ApiException('Invalid purchase order response payload.');
  }

  /// GET /api/purchase-orders/incoming-supplies — active deliveries for Floor Workers
  Future<List<IncomingSupplyItem>> getIncomingSupplies() async {
    try {
      final response = await _api.get('/purchase-orders/incoming-supplies');
      if (response is List) {
        return response
            .map((item) => IncomingSupplyItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/purchase-orders/{id}/delivery-status — delivery status for specific PO
  Future<IncomingSupplyItem> getDeliveryStatus(int id) async {
    final response = await _api.get('/purchase-orders/$id/delivery-status');
    if (response is Map<String, dynamic>) {
      return IncomingSupplyItem.fromJson(response);
    }
    throw const ApiException('Failed to retrieve delivery status.');
  }

  /// GET /api/procurement — list all procurement requests
  Future<List<ProcurementItem>> getProcurements() async {
    try {
      final response = await _api.get('/procurement');
      if (response is List) {
        return response
            .map((item) => ProcurementItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/procurement/{id} — full procurement item with evaluated candidates
  Future<ProcurementItem> getProcurementById(int id) async {
    final response = await _api.get('/procurement/$id');
    if (response is Map<String, dynamic>) {
      return ProcurementItem.fromJson(response);
    }
    throw const ApiException('Failed to retrieve procurement request.');
  }

  /// GET /api/procurement/{id}/status — real-time 11-step status pipeline
  Future<ProcurementStatusTracking?> getProcurementStatus(int id) async {
    try {
      final response = await _api.get('/procurement/$id/status');
      if (response is Map<String, dynamic>) {
        return ProcurementStatusTracking.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/procurement/request — initialize procurement request
  Future<ProcurementItem> createProcurementRequest(Map<String, dynamic> data) async {
    final response = await _api.post('/procurement/request', data);
    if (response is Map<String, dynamic>) {
      return ProcurementItem.fromJson(response);
    }
    throw const ApiException('Failed to create procurement request.');
  }

  /// POST /api/procurement/{id}/start — trigger AI research workflow
  Future<ProcurementItem> startProcurementResearch(int id) async {
    final response = await _api.post('/procurement/$id/start');
    if (response is Map<String, dynamic>) {
      return ProcurementItem.fromJson(response);
    }
    throw const ApiException('Failed to trigger AI research.');
  }

  /// POST /api/stock-alerts — submit low stock alert to ASP.NET Core
  Future<Map<String, dynamic>> submitLowStockAlert({
    required String sku,
    required String packagingType,
    required int quantityRequested,
    String? workerId,
  }) async {
    final body = {
      'sku': sku,
      'packagingType': packagingType,
      'quantityRequested': quantityRequested,
      'workerId': workerId ?? 'floor_worker_1',
    };
    final response = await _api.post('/stock-alerts', body);
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'status': 'Submitted', 'sku': sku};
  }

  /// GET /api/agentworkflow/workflows — get multi-agent workflow statuses
  Future<List<AgentWorkflowItem>> getAgentWorkflows() async {
    try {
      final response = await _api.get('/agentworkflow/workflows');
      if (response is List) {
        return response
            .map((item) => AgentWorkflowItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/suppliers — list suppliers
  Future<List<SupplierSummary>> getSuppliers() async {
    try {
      final response = await _api.get('/suppliers');
      if (response is List) {
        return response
            .map((item) => SupplierSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/suppliers/analytics — supplier overall spend & performance
  Future<SupplierAnalytics?> getSupplierAnalytics() async {
    try {
      final response = await _api.get('/suppliers/analytics');
      if (response is Map<String, dynamic>) {
        return SupplierAnalytics.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}


