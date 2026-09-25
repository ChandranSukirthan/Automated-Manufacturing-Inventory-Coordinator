import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/auth_models.dart';
import 'package:mobile_flutter/models/procurement_models.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/incoming_deliveries_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/low_stock_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/mobile_notifications_screen.dart';
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
  FakePurchaseOrderService(ApiClient api, {this.customProcurement}) : super(api);

  final ProcurementItem? customProcurement;

  @override
  Future<List<ProcurementItem>> getProcurements() async {
    return [
      customProcurement ??
          ProcurementItem.fromJson({
            'id': 10,
            'rawMaterialId': 1,
            'rawMaterialName': 'Biodegradable Polymer Film',
            'rawMaterialSku': 'RM-PLASTIC-502',
            'requiredSpecification': 'ASTM D882 High Tensile Strength Barrier Film',
            'productionRequirement': 5000.0,
            'currentStock': 500.0,
            'safetyStock': 1000.0,
            'existingOpenPoQuantity': 0.0,
            'calculatedNetQuantity': 5500.0,
            'maximumBudget': 15000.0,
            'requiredByDate': '2026-10-15T00:00:00Z',
            'qualityRequirement': 'ISO 9001 certified',
            'preferredRegion': 'Domestic US',
            'status': 'DraftPoCreated',
            'generatedPurchaseOrderId': 42,
            'generatedPoNumber': 'PO-2024-001',
            'createdAt': '2026-09-24T10:00:00Z',
            'updatedAt': '2026-09-24T10:00:00Z',
            'candidates': [
              {
                'id': 1,
                'supplierName': 'Apex Polymers Ltd',
                'materialName': 'Barrier Film Roll',
                'unitPrice': 1.42,
                'currency': 'USD',
                'minimumOrderQuantity': 1000.0,
                'packSize': 500.0,
                'leadTimeDays': 7,
                'qualityEvidence': 'ISO 9001:2015 certified; ASTM D882 passed',
                'supplierStatus': 'APPROVED',
                'confidenceScore': 0.95,
                'isValidated': true,
                'recommendedOrderQuantity': 5500.0,
                'totalCost': 7810.0,
                'createdAt': '2026-09-24T10:00:00Z',
              }
            ],
          })
    ];
  }

  @override
  Future<ProcurementItem> getProcurementById(int id) async {
    return (await getProcurements()).first;
  }

  @override
  Future<List<DeliveryTrackingItem>> getIncomingDeliveries() async {
    return [
      DeliveryTrackingItem(
        purchaseOrderId: 42,
        poNumber: 'PO-2024-001',
        supplierId: 1,
        supplierName: 'Apex Polymers Ltd',
        material: 'Biodegradable Polymer Film',
        quantity: 5500.0,
        expectedDelivery: DateTime.now().add(const Duration(days: 4)),
        deliveryStatus: 'IN_TRANSIT',
        status: 'Sent',
        stripePaymentStatus: 'PAID',
        emailStatus: 'SENT',
        updatedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<MobileNotificationItem>> getMobileNotifications() async {
    return [
      MobileNotificationItem(
        id: 'n-1',
        title: 'PO Approved',
        message: 'PO-2024-001 was approved by Supply Chain Manager.',
        category: 'po_approved',
        timestamp: DateTime.now(),
      ),
      MobileNotificationItem(
        id: 'n-2',
        title: 'AI Recommendation Ready',
        message: 'Apex Polymers Ltd was selected as top supplier.',
        category: 'recommendation_ready',
        timestamp: DateTime.now(),
      ),
    ];
  }
}

void main() {
  final storage = MockSessionStorage();
  final api = ApiClient(storage: storage);

  group('Safety Gate & Mobile Procurement Widget Tests', () {
    testWidgets('Safety Gate is displayed when approval is pending, with no payment/approval button',
        (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: ProcurementDetailsScreen(
            procurementId: 10,
            service: fakeService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Safety Gate banner text is present
      expect(find.text('Waiting for Supply Chain Manager approval'), findsOneWidget);
      expect(
        find.textContaining('Review and approval are handled in the Supply Chain Manager Web Console'),
        findsOneWidget,
      );

      // Verify lock icon is present
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Verify Safety Invariant: NO payment button and NO approval button for floor worker!
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Pay with Stripe'), findsNothing);
      expect(find.text('Execute Payment'), findsNothing);
      expect(find.text('Reject Order'), findsNothing);
    });

    testWidgets('AI Recommendation Summary displays structured fields and no raw chain-of-thought',
        (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: ProcurementDetailsScreen(
            procurementId: 10,
            service: fakeService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AI Recommendation Summary title
      expect(find.text('AI Recommendation Summary'), findsOneWidget);

      // Verify recommended fields
      expect(find.text('Apex Polymers Ltd'), findsOneWidget);
      expect(find.text('Barrier Film Roll'), findsOneWidget);
      expect(find.text('5500 units'), findsOneWidget);
      expect(find.text('\$1.42 / unit'), findsOneWidget);
      expect(find.text('\$7810.00'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);

      // Verify raw reasoning / chain-of-thought is NOT exposed
      expect(find.textContaining('chain of thought'), findsNothing);
      expect(find.textContaining('thought:'), findsNothing);
    });

    testWidgets('11-Step Lifecycle Stepper displays all pipeline stages', (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: ProcurementDetailsScreen(
            procurementId: 10,
            service: fakeService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Procurement Lifecycle Pipeline'), findsOneWidget);
      expect(find.text('LOW STOCK'), findsOneWidget);
      expect(find.text('PROCUREMENT REQUESTED'), findsOneWidget);
      expect(find.text('AI RESEARCHING'), findsOneWidget);
      expect(find.text('RECOMMENDATION READY'), findsOneWidget);
      expect(find.text('WAITING FOR MANAGER APPROVAL'), findsWidgets);
    });

    testWidgets('LowStockScreen displays Material, Current Stock, Minimum Stock, Shortage',
        (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LowStockScreen(service: fakeService),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify materials listed
      expect(find.text('Biodegradable Polymer Film'), findsOneWidget);
      expect(find.text('RM-PLASTIC-502'), findsOneWidget);
      expect(find.text('Current Stock'), findsWidgets);
      expect(find.text('Minimum Stock'), findsWidgets);
      expect(find.text('Shortage'), findsWidgets);
      expect(find.text('Submit Low Stock Alert'), findsWidgets);
    });

    testWidgets('IncomingDeliveriesScreen displays PO Number, Supplier, Material, Quantity, and Delivery Status',
        (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomingDeliveriesScreen(service: fakeService),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PO-2024-001'), findsOneWidget);
      expect(find.text('Apex Polymers Ltd'), findsOneWidget);
      expect(find.text('Biodegradable Polymer Film'), findsOneWidget);
      expect(find.text('5500 units'), findsOneWidget);
      expect(find.text('IN TRANSIT'), findsOneWidget);
      expect(find.text('Mark as Received / Update Status'), findsOneWidget);
    });

    testWidgets('MobileNotificationsScreen renders operational notifications', (tester) async {
      final fakeService = FakePurchaseOrderService(api);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileNotificationsScreen(service: fakeService),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PO Approved'), findsOneWidget);
      expect(find.text('AI Recommendation Ready'), findsOneWidget);
      expect(find.textContaining('PO-2024-001 was approved'), findsOneWidget);
    });
  });
}
