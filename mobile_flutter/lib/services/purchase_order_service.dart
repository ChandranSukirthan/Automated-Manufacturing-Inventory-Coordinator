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

  /// POST /api/suppliers — register and create new supplier vendor
  Future<SupplierSummary> createSupplier(Map<String, dynamic> data) async {
    final response = await _api.post('/suppliers', data);
    if (response is Map<String, dynamic>) {
      return SupplierSummary.fromJson(response);
    }
    throw const ApiException('Failed to register new supplier.');
  }

  /// POST /api/suppliers/{id}/verify — verify and activate supplier
  Future<SupplierSummary> verifySupplier(int id) async {
    final response = await _api.post('/suppliers/$id/verify', {});
    if (response is Map<String, dynamic>) {
      return SupplierSummary.fromJson(response);
    }
    throw const ApiException('Failed to verify supplier.');
  }

  /// GET /api/stock-alerts — retrieve all low stock alerts
  Future<List<StockAlertItem>> getStockAlerts() async {
    try {
      final response = await _api.get('/stock-alerts');
      if (response is List) {
        return response
            .map((item) => StockAlertItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/stock-alerts/unread — retrieve unread low stock alerts
  Future<List<StockAlertItem>> getUnreadStockAlerts() async {
    try {
      final response = await _api.get('/stock-alerts/unread');
      if (response is List) {
        return response
            .map((item) => StockAlertItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// PUT /api/stock-alerts/{id}/read — mark alert as read/acknowledged
  Future<bool> markStockAlertAsRead(int id) async {
    try {
      await _api.put('/stock-alerts/$id/read', {});
      return true;
    } catch (_) {
      return false;
    }
  }


  /// GET /api/procurement/{id}/candidates — evaluated supplier candidates
  Future<List<SupplierCandidateItem>> getProcurementCandidates(int id) async {
    try {
      final response = await _api.get('/procurement/$id/candidates');
      if (response is List) {
        return response
            .map((item) => SupplierCandidateItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// POST /api/procurement/{id}/create-draft-po?candidateId={candidateId} — create draft PO from candidate
  Future<PurchaseOrderDetail> createDraftPoFromCandidate(int procurementId, int candidateId) async {
    final response = await _api.post('/procurement/$procurementId/create-draft-po?candidateId=$candidateId');
    if (response is Map<String, dynamic>) {
      return PurchaseOrderDetail.fromJson(response);
    }
    throw const ApiException('Failed to create draft PO from candidate.');
  }

  /// POST /api/procurement/{id}/verify-supplier?candidateId={candidateId} — verify unverified supplier candidate
  Future<ProcurementItem> verifySupplierCandidate(int procurementId, int candidateId, Map<String, dynamic> data) async {
    final response = await _api.post('/procurement/$procurementId/verify-supplier?candidateId=$candidateId', data);
    if (response is Map<String, dynamic>) {
      return ProcurementItem.fromJson(response);
    }
    throw const ApiException('Failed to verify supplier candidate.');
  }

  /// POST /api/purchase-orders — create a new purchase order directly
  Future<PurchaseOrderDetail> createPurchaseOrder(Map<String, dynamic> data) async {
    final response = await _api.post('/purchase-orders', data);
    if (response is Map<String, dynamic>) {
      return PurchaseOrderDetail.fromJson(response);
    }
    throw const ApiException('Failed to create purchase order.');
  }

  /// POST /api/purchase-orders/{id}/submit
  Future<PurchaseOrderDetail> submitPurchaseOrder(int id) async {
    final response = await _api.post('/purchase-orders/$id/submit');
    return PurchaseOrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /api/purchase-orders/{id}/approve
  Future<PurchaseOrderDetail> approvePurchaseOrder(int id, {String? notes}) async {
    final response = await _api.post('/purchase-orders/$id/approve', notes != null ? {'notes': notes} : null);
    return PurchaseOrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /api/purchase-orders/{id}/reject
  Future<PurchaseOrderDetail> rejectPurchaseOrder(int id, {required String notes}) async {
    final response = await _api.post('/purchase-orders/$id/reject', {'notes': notes});
    return PurchaseOrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /api/purchase-orders/{id}/revise
  Future<PurchaseOrderDetail> revisePurchaseOrder(int id, {required String notes}) async {
    final response = await _api.post('/purchase-orders/$id/revise', {'notes': notes});
    return PurchaseOrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /api/purchase-orders/{id}/process-payment
  Future<PurchaseOrderDetail> processPayment(int id, {bool forceDispatch = true}) async {
    final response = await _api.post('/purchase-orders/$id/process-payment?forceDispatch=$forceDispatch');
    return PurchaseOrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /api/purchase-orders/{id}/create-checkout-session
  Future<String?> createCheckoutSession(int id) async {
    final response = await _api.post('/purchase-orders/$id/create-checkout-session');
    if (response is Map<String, dynamic> && response['url'] != null) {
      return response['url'] as String;
    }
    return null;
  }
}



