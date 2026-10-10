import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_list_screen.dart';
import 'purchase_order_refresh_test.dart' show OrderService, mount;

const statuses = [
  'Draft',
  'PendingApproval',
  'Approved',
  'Rejected',
  'RevisionRequested',
  'Payment',
  'Sent',
  'PaymentPending',
  'Paid',
  'SupplierNotified',
  'InTransit',
  'Delivered',
  'Completed',
  'PaymentFailed',
];

class FilterOrderService extends OrderService {
  @override
  Future<List<PurchaseOrderSummary>> getPurchaseOrders() async => [
    for (var i = 0; i < statuses.length; i++)
      PurchaseOrderSummary.fromJson({
        'id': i + 1,
        'poNumber': 'ORDER-${statuses[i]}',
        'supplierName': 'Supplier ${statuses[i]}',
        'status': statuses[i],
        'totalCost': 123456789.99,
      }),
  ];
}

Future<void> selectStatus(WidgetTester tester, String status) async {
  await tester.tap(find.byKey(const ValueKey('order-status-filter')));
  await tester.pumpAndSettle();
  final item = find
      .byWidgetPredicate(
        (w) => w is DropdownMenuItem<String> && w.value == status,
      )
      .last;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: item, matching: find.byType(Text)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every backend status is selectable and filters correctly', (
    tester,
  ) async {
    await mount(tester, POListScreen(service: FilterOrderService()));
    for (final status in statuses) {
      await selectStatus(tester, status);
      expect(find.text('1 of 14 orders'), findsOneWidget);
      expect(find.text('ORDER-$status'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('trimmed search combines with status and reset restores all', (
    tester,
  ) async {
    await mount(tester, POListScreen(service: FilterOrderService()));
    await tester.enterText(find.byType(TextField), '  supplier paid  ');
    await tester.pumpAndSettle();
    expect(find.text('1 of 14 orders'), findsOneWidget);
    expect(find.text('ORDER-Paid'), findsOneWidget);
    await selectStatus(tester, 'Draft');
    expect(find.text('No orders match your filters.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('14 of 14 orders'), findsOneWidget);
    expect(find.text('All statuses'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('14 of 14 orders'), findsOneWidget);
  });

  testWidgets('long values fit narrow screen with larger text', (tester) async {
    await mount(tester, POListScreen(service: FilterOrderService()));
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: POListScreen(service: FilterOrderService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'RevisionRequested');
    await tester.pumpAndSettle();
    expect(find.text('ORDER-RevisionRequested'), findsOneWidget);
    expect(find.text('Revision Requested'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
