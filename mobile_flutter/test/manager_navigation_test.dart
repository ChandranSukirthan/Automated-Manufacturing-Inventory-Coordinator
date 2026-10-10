import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app_state.dart';
import 'package:mobile_flutter/models/auth_models.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/models/procurement_models.dart';
import 'package:mobile_flutter/screens/home_shell.dart';
import 'package:mobile_flutter/services/admin_service.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/auth_service.dart';
import 'package:mobile_flutter/services/purchase_order_service.dart';
import 'package:mobile_flutter/services/quality_service.dart';
import 'package:mobile_flutter/services/session_storage.dart';

class MockPurchaseOrderService extends Fake implements PurchaseOrderService {
  @override
  Future<List<PurchaseOrderSummary>> getPurchaseOrders() async => [];

  @override
  Future<List<SupplierSummary>> getSuppliers() async => [];

  @override
  Future<List<StockAlertItem>> getStockAlerts() async => [];

  @override
  Future<List<AgentWorkflowItem>> getAgentWorkflows() async => [];

  @override
  Future<List<IncomingSupplyItem>> getIncomingSupplies() async => [];

  @override
  Future<ProcurementStatusTracking> getProcurementStatusTracking(int id) async =>
      const ProcurementStatusTracking(
        procurementId: 1,
        materialName: 'Test Material',
        requiredSpecification: 'Standard',
        netDeficit: 100,
        procurementStatus: 'Draft',
        workflowId: 'WF-1',
        purchaseOrderId: 1,
        purchaseOrderNumber: 'PO-1',
        purchaseOrderStatus: 'Draft',
        paymentStatus: 'Pending',
        supplierNotificationStatus: 'Pending',
        supplierName: 'Test Supplier',
        supplierStatus: 'Pending',
        recommendedQuantity: 100,
        unitPrice: 10,
        totalCost: 1000,
        qualityEvidence: 'None',
        leadTimeDays: 7,
        availability: 'In Stock',
        requiresSupplierVerification: false,
        requiresHumanApproval: true,
        lastUpdated: null,
      );
}

void main() {
  testWidgets('Supply Chain Manager HomeShell displays all 7 bottom navigation tabs and drawer links', (tester) async {
    final storage = SessionStorage();
    final api = ApiClient(storage: storage);
    final appState = AppState(auth: AuthService(api, storage), storage: storage);
    appState.isLoading = false;
    appState.session = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: UserSummary(
        id: '1',
        fullName: 'Jane Manager',
        email: 'manager@example.com',
        role: 'SupplyChainManager',
      ),
    );

    final mockPoService = MockPurchaseOrderService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          appState: appState,
          qualityService: QualityService(api),
          poService: mockPoService,
          adminService: AdminService(api),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all 7 tabs are in the bottom navigation
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Workflows'), findsOneWidget);
    expect(find.text('Sourcing'), findsOneWidget);
    expect(find.text('Suppliers'), findsOneWidget);
    expect(find.text('Deliveries'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);

    // Tap on Workflows
    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();
    expect(find.text('AI Workflows & Approvals'), findsOneWidget);

    // Tap on Deliveries
    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();
    expect(find.text('Deliveries & Logistics'), findsOneWidget);

    // Open Drawer and verify all 7 manager modules are present
    final ScaffoldState scaffoldState = tester.state(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Command Center'), findsOneWidget);
    expect(find.text('Purchase Orders'), findsOneWidget);
    expect(find.text('AI Workflows & Approvals'), findsWidgets);
    expect(find.text('AI Sourcing Hub'), findsOneWidget);
    expect(find.text('Suppliers & Verification'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Low Stock Alerts & Reorder'),
      50,
      scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)),
    );
    expect(find.text('Low Stock Alerts & Reorder'), findsOneWidget);
  });
}
