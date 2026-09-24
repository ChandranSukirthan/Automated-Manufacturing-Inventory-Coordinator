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

