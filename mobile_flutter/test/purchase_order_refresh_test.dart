import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_details_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_list_screen.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/purchase_order_service.dart';

class OrderService extends PurchaseOrderService {
  OrderService() : super(ApiClient());
  String status = 'PendingApproval';
  String? payment;
  int listCalls = 0;
  bool rejectConfirmation = false;
  bool missingSession = false;

  Map<String, dynamic> get data => {
    'id': 1,
    'poNumber': 'PO-TEST',
    'supplierName': 'Test Supplier',
    'status': status,
    'totalCost': 100,
    'stripePaymentStatus': payment,
    if (status != 'PendingApproval') 'approvedByName': 'Manager',
  };

  @override
  Future<List<PurchaseOrderSummary>> getPurchaseOrders() async {
    listCalls++;
    return [PurchaseOrderSummary.fromJson(data)];
  }

  @override
  Future<PurchaseOrderDetail> getPurchaseOrderById(int id) async =>
      PurchaseOrderDetail.fromJson(data);

  @override
  Future<PurchaseOrderDetail> approvePurchaseOrder(
    int id, {
    String? notes,
  }) async {
    status = 'Approved';
    return PurchaseOrderDetail.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>?> createCheckoutSession(int id) async => {
    'url': 'https://checkout.stripe.com/test',
    if (!missingSession) 'sessionId': 'cs_test',
  };

  @override
  Future<PurchaseOrderDetail?> confirmCheckout(int id, String sessionId) async {
    if (rejectConfirmation) {
      throw const ApiException('Stripe has not confirmed payment.');
    }
    status = 'Paid';
    payment = 'succeeded';
    return PurchaseOrderDetail.fromJson(data);
  }
}

Future<void> mount(WidgetTester tester, Widget screen) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  test('paid and delivery states retain approval and payment evidence', () {
    for (final status in [
      'Paid',
      'Sent',
      'SupplierNotified',
      'InTransit',
      'Delivered',
      'Completed',
    ]) {
      final summary = PurchaseOrderSummary.fromJson({
        'id': 1,
        'status': status,
      });
      final detail = PurchaseOrderDetail.fromJson({'id': 1, 'status': status});
      expect(summary.approvalStatusDisplay, 'Approved');
      expect(summary.paymentStatusDisplay, 'Settled');
      expect(detail.approvalStatusDisplay, 'Approved');
      expect(detail.paymentStatusDisplay, 'Settled');
      expect(
        detail.currentLifecycleStep,
        isNot(POLifecycleStep.poDraftCreated),
      );
    }
  });

  testWidgets('returning after approval refreshes the list', (tester) async {
    final service = OrderService();
    await mount(tester, POListScreen(service: service));
    await tester.tap(find.text('PO-TEST'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.listCalls, 2);
    expect(find.text('Approval: Approved by Manager'), findsOneWidget);
  });

  testWidgets('visible list polls for payment changes without manual refresh', (
    tester,
  ) async {
    final service = OrderService();
    await mount(tester, POListScreen(service: service));
    service.status = 'Paid';
    service.payment = 'succeeded';
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Payment: Paid'), findsOneWidget);
    expect(find.text('Approval: Approved by Manager'), findsOneWidget);
  });

  testWidgets('returning to the purchase-order tab refreshes cached orders', (
    tester,
  ) async {
    final service = OrderService();
    await mount(tester, POListScreen(service: service, isActive: false));
    service.status = 'Approved';
    await tester.pumpWidget(MaterialApp(home: POListScreen(service: service)));
    await tester.pumpAndSettle();
    expect(service.listCalls, 2);
    expect(find.text('Approval: Approved by Manager'), findsOneWidget);
  });

  testWidgets('resuming the app refreshes web updates', (tester) async {
    final service = OrderService();
    await mount(tester, POListScreen(service: service));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.status = 'Paid';
    service.payment = 'succeeded';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Payment: Paid'), findsOneWidget);
  });

  testWidgets('missing checkout session cannot report successful payment', (
    tester,
  ) async {
    final service = OrderService()
      ..status = 'Approved'
      ..missingSession = true;
    await mount(tester, PODetailsScreen(service: service, poId: 1));
    await tester.ensureVisible(find.text('Stripe Card'));
    await tester.tap(find.text('Stripe Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Payment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checkout session is missing'), findsOneWidget);
    expect(find.text('Payment checked and verified!'), findsNothing);
  });

  for (final failure in [true, false]) {
    testWidgets(
      'payment confirmation ${failure ? 'failure stays pending' : 'success updates the order'}',
      (tester) async {
        final service = OrderService()
          ..status = 'Approved'
          ..rejectConfirmation = failure;
        await mount(tester, PODetailsScreen(service: service, poId: 1));
        await tester.ensureVisible(find.text('Stripe Card'));
        await tester.tap(find.text('Stripe Card'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify Payment'));
        await tester.pumpAndSettle();
        if (failure) {
          expect(
            find.textContaining('Payment verification failed:'),
            findsOneWidget,
          );
          expect(find.text('Payment checked and verified!'), findsNothing);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(service.status, 'Approved');
        } else {
          expect(find.text('Payment checked and verified!'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(service.status, 'Paid');
          expect(service.payment, 'succeeded');
        }
      },
    );
  }
}
