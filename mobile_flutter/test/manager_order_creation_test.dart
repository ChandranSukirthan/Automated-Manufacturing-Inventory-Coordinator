import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/models/procurement_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_create_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/procurement_details_screen.dart';
import 'package:mobile_flutter/services/inventory_api_service.dart';
import 'purchase_order_refresh_test.dart' show OrderService, mount;
import 'procurement_details_screen_test.dart'
    show VerificationPurchaseOrderService;

final material = RawMaterialModel.fromJson({
  'id': 1,
  'name': 'Film',
  'skuCode': 'BP-FILM-001',
});

class CreateService extends OrderService {
  Map<String, dynamic>? saved;
  @override
  Future<List<RawMaterialModel>> getRawMaterials() async => [material];
  @override
  Future<List<SupplierSummary>> getSuppliers() async => [
    SupplierSummary.fromJson({'id': 1, 'name': 'Supplier', 'isActive': true}),
  ];
  @override
  Future<PurchaseOrderDetail> createPurchaseOrder(
    Map<String, dynamic> body,
  ) async {
    saved = body;
    return PurchaseOrderDetail.fromJson({'id': 9, 'status': 'Draft'});
  }
}

class ResearchService extends VerificationPurchaseOrderService {
  Map<String, dynamic>? created;
  int? researched;
  @override
  Future<List<RawMaterialModel>> getRawMaterials() async => [material];
  @override
  Future<ProcurementItem> createProcurementRequest(
    Map<String, dynamic> body,
  ) async {
    created = body;
    return ProcurementItem.fromJson({'id': 101});
  }

  @override
  Future<ProcurementItem> runAiResearch(int id) async {
    researched = id;
    return ProcurementItem.fromJson({'id': id});
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> enter(
  WidgetTester tester,
  String label,
  String value, {
  int index = 0,
}) async {
  final finder = field(label).at(index);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual creation validates numbers and budget without sending invalid data',
    (tester) async {
      final service = CreateService();
      await mount(
        tester,
        POCreateScreen(
          service: service,
          initialSupplierId: 1,
          initialMaterialId: 1,
          initialQuantity: 10,
          initialPrice: 2,
          initialBudget: 10,
        ),
      );
      await click(tester, 'Save draft');
      expect(service.saved, isNull);
      expect(
        find.text('Order total exceeds the budget limit.'),
        findsOneWidget,
      );
      await enter(tester, 'Budget limit (LKR) *', '100');
      await enter(tester, 'Quantity *', 'not a number');
      await click(tester, 'Save draft');
      expect(service.saved, isNull);
      expect(find.text('Enter a positive number.'), findsWidgets);
    },
  );
  testWidgets(
    'manual creation sends multiple selected items and editable budget',
    (tester) async {
      final service = CreateService();
      await mount(
        tester,
        POCreateScreen(
          service: service,
          initialSupplierId: 1,
          initialMaterialId: 1,
          initialQuantity: 10,
          initialPrice: 2,
          initialBudget: 100,
          initialCurrency: 'EUR',
        ),
      );
      await click(tester, 'Add item');
      final dropdowns = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int>,
      );
      final secondMaterial = dropdowns.last;
      await tester.ensureVisible(secondMaterial);
      await tester.pumpAndSettle();
      await tester.tap(secondMaterial);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film (BP-FILM-001)').last);
      await tester.pumpAndSettle();
      await enter(tester, 'Quantity *', '5', index: 1);
      await enter(tester, 'Unit price (EUR) *', '3', index: 1);
      await click(tester, 'Save draft');
      expect(service.saved!['supplierId'], 1);
      expect(service.saved!['budgetLimit'], 100);
      expect(service.saved!['currency'], 'EUR');
      expect(service.saved!['lines'], hasLength(2));
      expect((service.saved!['lines'] as List)[1]['quantity'], 5);
    },
  );
  testWidgets(
    'new sourcing requires specification and sends the entered quality benchmark',
    (tester) async {
      final service = ResearchService();
      await mount(
        tester,
        ProcurementDetailsScreen(
          service: service,
          procurementId: 101,
          showAppBar: false,
        ),
      );
      await click(tester, 'New AI Sourcing Request');
      await click(tester, 'Start AI Procurement Research');
      expect(service.created, isNull);
      await enter(
        tester,
        'Technical Specification & Standards *',
        'Food-safe film',
      );
      await enter(tester, 'Quality Standard Benchmark', 'CUSTOM CERT');
      await click(tester, 'Start AI Procurement Research');
      expect(service.created!['rawMaterialId'], 1);
      expect(service.created!['requiredSpecification'], 'Food-safe film');
      expect(service.created!['qualityRequirement'], 'CUSTOM CERT');
      expect(service.researched, 101);
    },
  );
}
