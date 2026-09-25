import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/auth_models.dart';
import 'package:mobile_flutter/models/procurement_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/incoming_supplies_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/procurement_details_screen.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/purchase_order_service.dart';
import 'package:mobile_flutter/services/session_storage.dart';

class MockSessionStorage extends SessionStorage {
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> save(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

class FakePurchaseOrderService extends PurchaseOrderService {
  FakePurchaseOrderService({
    this.statusTracking,
    this.incomingSupplies = const [],
  }) : super(ApiClient(storage: MockSessionStorage(), baseUrl: 'http://localhost:5070/api'));

  final ProcurementStatusTracking? statusTracking;
  final List<IncomingSupplyItem> incomingSupplies;

  @override
  Future<ProcurementStatusTracking?> getProcurementStatus(int id) async {
    return statusTracking;
  }

  @override
  Future<List<ProcurementItem>> getProcurements() async {
    return [];
  }

  @override
  Future<List<IncomingSupplyItem>> getIncomingSupplies() async {
    return incomingSupplies;
  }
}

void main() {
  group('ProcurementDetailsScreen Widget & Safety Gate Tests', () {
    testWidgets('renders 11-step pipeline, AI recommendation summary, and safety gate banner',
        (tester) async {
      const mockTracking = ProcurementStatusTracking(
        procurementId: 101,
        materialName: 'Food Grade BOPP Film',
        requiredSpecification: 'Grade A 50 Micron',
        netDeficit: 800.0,
        procurementStatus: 'RecommendationReady',
        workflowId: 'WF-PROC-101',
        purchaseOrderId: 42,
        purchaseOrderNumber: 'PO-2026-0042',
        purchaseOrderStatus: 'PendingApproval',
        paymentStatus: 'Pending',
        supplierNotificationStatus: 'Queued',
        supplierName: 'Apex Packaging Materials Ltd',
        supplierStatus: 'APPROVED',
        recommendedQuantity: 1000.0,
        unitPrice: 3.50,
        totalCost: 3500.0,
        qualityEvidence: 'ISO 9001:2015 & ASTM F1249 Certified',
        leadTimeDays: 5,
        availability: 'In Stock',
        requiresSupplierVerification: false,
        requiresHumanApproval: true,
        lastUpdated: null,
      );

      final fakeService = FakePurchaseOrderService(statusTracking: mockTracking);

      await tester.pumpWidget(
        MaterialApp(
          home: ProcurementDetailsScreen(
            service: fakeService,
            procurementId: 101,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Top Header
      expect(find.text('Food Grade BOPP Film'), findsNWidgets(2));
      expect(find.textContaining('800 units'), findsOneWidget);
      expect(find.text('WF-PROC-101'), findsOneWidget);

      // 2. Verify Safety Gate Banner
      expect(find.text('Waiting for Supply Chain Manager approval'), findsOneWidget);
      expect(
        find.textContaining('Review and approval are handled in the Supply Chain Manager Web Console.'),
        findsOneWidget,
      );

      // CRITICAL SAFETY INVARIANT: Floor Worker has NO approval or payment controls
      expect(find.text('Approve PO'), findsNothing);
      expect(find.text('Approve Order'), findsNothing);
      expect(find.text('Pay with Stripe'), findsNothing);
      expect(find.text('Pay Now'), findsNothing);

      // 3. Verify 11-Stage Pipeline Stepper
      expect(find.text('Procurement Status Pipeline'), findsOneWidget);
      expect(find.text('LOW STOCK'), findsOneWidget);
      expect(find.text('PROCUREMENT REQUESTED'), findsOneWidget);
      expect(find.text('AI RESEARCHING'), findsOneWidget);
      expect(find.text('RECOMMENDATION READY'), findsOneWidget);
      expect(find.text('WAITING FOR MANAGER APPROVAL'), findsNWidgets(2)); // header badge + stepper
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('PAYMENT PROCESSING'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('SUPPLIER NOTIFIED'), findsOneWidget);
      expect(find.text('INCOMING SUPPLY'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);

      // 4. Verify AI Recommendation Summary Card
      expect(find.text('AI Procurement Recommendation'), findsOneWidget);
      expect(find.text('Apex Packaging Materials Ltd'), findsOneWidget);
      expect(find.text('1000 units'), findsOneWidget);
      expect(find.text('\$3.50'), findsOneWidget);
      expect(find.text('\$3500.00'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Supplier: APPROVED'), findsOneWidget);
      expect(find.text('Quality: VERIFIED'), findsOneWidget);
    });
  });

  group('IncomingSuppliesScreen Widget Tests', () {
    testWidgets('renders active deliveries with delivery status badges and filter chips',
        (tester) async {
      final mockDeliveries = [
        IncomingSupplyItem(
          purchaseOrderId: 42,
          poNumber: 'PO-2026-0042',
          supplierName: 'Apex Packaging Materials Ltd',
          materialName: 'Food Grade BOPP Film',
          quantity: 1000.0,
          expectedDelivery: DateTime.now().add(const Duration(days: 3)),
          deliveryStatus: SupplyDeliveryStatus.inTransit,
          trackingNumber: 'TRK-APEX-9921',
          actualDeliveryDate: null,
          statusRemarks: 'Dispatched via Express Freight',
        ),
      ];

      final fakeService = FakePurchaseOrderService(incomingSupplies: mockDeliveries);

      await tester.pumpWidget(
        MaterialApp(
          home: IncomingSuppliesScreen(service: fakeService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Incoming Supplies'), findsOneWidget);
      expect(find.text('PO-2026-0042'), findsOneWidget);
      expect(find.text('Apex Packaging Materials Ltd'), findsOneWidget);
      expect(find.text('Food Grade BOPP Film'), findsOneWidget);
      expect(find.text('1000 units'), findsOneWidget);
      expect(find.text('TRK-APEX-9921'), findsOneWidget);

      // Filter chips & delivery badge
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('EXPECTED'), findsOneWidget);
      expect(find.text('IN_TRANSIT'), findsNWidgets(2)); // chip + badge
      expect(find.text('RECEIVED'), findsOneWidget);
    });
  });
}
