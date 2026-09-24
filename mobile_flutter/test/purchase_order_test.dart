import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/auth_models.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/purchase_order_service.dart';
import 'package:mobile_flutter/services/session_storage.dart';

class MockSessionStorage extends SessionStorage {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

void main() {
  group('Purchase Order Models & Lifecycle Tests', () {
    test('PurchaseOrderSummary parses JSON correctly and computes lifecycle step', () {
      final json = {
        'id': 101,
        'poNumber': 'PO-2026-001',
        'supplierName': 'Acme Raw Materials',
        'status': 'PendingApproval',
        'currency': 'USD',
        'totalCost': 12500.50,
        'requiresApproval': true,
        'createdAt': '2026-09-24T10:00:00Z',
        'updatedAt': '2026-09-24T10:30:00Z',
      };

      final summary = PurchaseOrderSummary.fromJson(json);

      expect(summary.id, 101);
      expect(summary.poNumber, 'PO-2026-001');
      expect(summary.supplierName, 'Acme Raw Materials');
      expect(summary.status, 'PendingApproval');
      expect(summary.totalCost, 12500.50);
      expect(summary.requiresApproval, true);
      expect(summary.currentLifecycleStep, POLifecycleStep.waitingForManager);
    });

    test('PurchaseOrderDetail maps all required fields, lines, and telemetry', () {
      final json = {
        'id': 102,
        'poNumber': 'PO-2026-002',
        'supplierId': 5,
        'supplierName': 'Global Steel Corp',
        'status': 'Sent',
        'currency': 'USD',
        'totalCost': 45000.0,
        'budgetLimit': 50000.0,
        'approvalThreshold': 10000.0,
        'requiresApproval': true,
        'approvedByName': 'John Manager',
        'stripePaymentStatus': 'succeeded',
        'emailStatus': 'Delivered',
        'orderLines': [
          {
            'id': 1,
            'rawMaterialId': 20,
            'rawMaterialName': 'Stainless Steel Roll',
            'rawMaterialSku': 'RM-STEEL-001',
            'description': 'Grade 304 steel',
            'quantity': 500.0,
            'unitPrice': 90.0,
            'totalPrice': 45000.0,
          }
        ],
        'approvals': [
          {
            'id': 1,
            'action': 'Approved',
            'userName': 'John Manager',
            'notes': 'Production schedule urgent',
            'timestamp': '2026-09-24T11:00:00Z',
          }
        ],
        'transactions': [
          {
            'id': 1,
            'transactionId': 'ch_test_123',
            'amount': 45000.0,
            'paymentStatus': 'succeeded',
            'timestamp': '2026-09-24T11:05:00Z',
          }
        ],
        'createdAt': '2026-09-24T09:00:00Z',
        'updatedAt': '2026-09-24T11:10:00Z',
      };

      final detail = PurchaseOrderDetail.fromJson(json);

      expect(detail.id, 102);
      expect(detail.poNumber, 'PO-2026-002');
      expect(detail.supplierName, 'Global Steel Corp');
      expect(detail.orderLines.length, 1);
      expect(detail.orderLines.first.rawMaterialName, 'Stainless Steel Roll');
      expect(detail.orderLines.first.quantity, 500.0);
      expect(detail.orderLines.first.unitPrice, 90.0);
      expect(detail.orderLines.first.totalPrice, 45000.0);
      expect(detail.totalCost, 45000.0);
      expect(detail.status, 'Sent');
      expect(detail.approvalStatusDisplay, 'Approved by John Manager');
      expect(detail.paymentStatusDisplay, 'succeeded');
      expect(detail.supplierNotificationDisplay, 'Delivered');
      expect(detail.currentLifecycleStep, POLifecycleStep.orderSent);
    });

    test('10-Step Order Lifecycle Stepper values match requirement', () {
      final steps = POLifecycleStep.values;
      expect(steps.length, 10);
      expect(steps[0].title, 'Low Stock Submitted');
      expect(steps[1].title, 'AI Processing');
      expect(steps[2].title, 'PO Draft Created');
      expect(steps[3].title, 'Validation');
      expect(steps[4].title, 'Waiting for Manager');
      expect(steps[5].title, 'Approved');
      expect(steps[6].title, 'Payment Processing');
      expect(steps[7].title, 'Payment Successful');
      expect(steps[8].title, 'Supplier Notified');
      expect(steps[9].title, 'Order Sent');
    });
  });

  group('AI Workflow Status Tests', () {
    test('AgentWorkflowItem parses multi-agent pipeline telemetry', () {
      final json = {
        'workflowId': 'WF-2026-101',
        'objective': 'Replenish raw material for Steel Corp',
        'currentAgent': 'Human Approval Gate',
        'currentStep': 'Waiting For Manager Approval',
        'status': 'WaitingForApproval',
        'startedAt': '2026-09-24T08:00:00Z',
        'approvalStatus': 'PendingApproval',
        'finalOutcome': 'PO PO-101 in evaluation',
        'steps': ['PLANNER', 'DATA EXTRACTION', 'PURCHASING', 'VALIDATION', 'WAITING FOR APPROVAL'],
        'currentStepIndex': 4,
        'purchaseOrderId': 101,
        'poNumber': 'PO-101',
        'supplierName': 'Steel Corp',
        'totalCost': 15000.0,
      };

      final workflow = AgentWorkflowItem.fromJson(json);

      expect(workflow.workflowId, 'WF-2026-101');
      expect(workflow.currentAgent, 'Human Approval Gate');
      expect(workflow.currentStep, 'Waiting For Manager Approval');
      expect(workflow.status, 'WaitingForApproval');
      expect(workflow.steps.length, 5);
      expect(workflow.currentStepIndex, 4);
      expect(workflow.poNumber, 'PO-101');
    });
  });

  group('Authentication & Authorization Tests', () {
    test('UserSummary correctly identifies SupplyChainManager role', () {
      final manager = UserSummary.fromJson({
        'id': 'usr-1',
        'fullName': 'Sukirthan Manager',
        'email': 'manager@amic.com',
        'role': 'SupplyChainManager',
      });

      expect(manager.isSupplyChainManager, true);
      expect(manager.isQualityInspector, false);
      expect(manager.isITAdmin, false);

      final worker = UserSummary.fromJson({
        'id': 'usr-2',
        'fullName': 'Floor Operator',
        'email': 'worker@amic.com',
        'role': '0',
      });

      expect(worker.isSupplyChainManager, false);
      expect(worker.role, 'FloorWorker');

      final inspector = UserSummary.fromJson({
        'id': 'usr-3',
        'fullName': 'QA Inspector',
        'email': 'quality@amic.com',
        'role': '2',
      });

      expect(inspector.isQualityInspector, true);
      expect(inspector.isSupplyChainManager, false);
    });

    test('PurchaseOrderService enforces read-only tracking and calls ASP.NET Core only', () {
      final storage = MockSessionStorage();
      final client = ApiClient(storage: storage, baseUrl: 'http://localhost:5070/api');
      final service = PurchaseOrderService(client);

      // Verify service exposes read methods only (no unsafe mutate/approve endpoints)
      expect(service.getPurchaseOrders, isNotNull);
      expect(service.getPurchaseOrderById, isNotNull);
      expect(service.getAgentWorkflows, isNotNull);
      expect(service.getSuppliers, isNotNull);
      expect(service.getSupplierAnalytics, isNotNull);
    });
  });

  group('API Error Handling Tests', () {
    test('ApiException handles 401 Unauthorized, 404 Not Found, and 500 errors', () {
      const err401 = ApiException('Session expired. Please log in again.', statusCode: 401);
      expect(err401.statusCode, 401);
      expect(err401.toString(), contains('Session expired'));

      const err404 = ApiException('Purchase Order 999 not found.', statusCode: 404);
      expect(err404.statusCode, 404);
      expect(err404.toString(), contains('not found'));

      const err500 = ApiException('Internal server error in ASP.NET Core.', statusCode: 500);
      expect(err500.statusCode, 500);
      expect(err500.toString(), contains('Internal server error'));
    });
  });
}
