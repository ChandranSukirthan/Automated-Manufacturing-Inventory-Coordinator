import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/auth_models.dart';
import 'package:mobile_flutter/models/purchase_order_models.dart';
import 'package:mobile_flutter/screens/purchase_orders/supplier_status_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/supplier_detail_screen.dart';
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

class FakeSupplierService extends PurchaseOrderService {
  FakeSupplierService({
    List<SupplierSummary>? suppliers,
  })  : _suppliers = suppliers ?? [
          const SupplierSummary(
            id: 1,
            name: 'Apex Industrial Steel Corp',
            supplierCode: 'SUP-001',
            contactPerson: 'Alice Smith',
            email: 'alice@apexsteel.com',
            phone: '+94 77 123 4567',
            paymentTerms: 'Net 30',
            isActive: true,
            address: '100 Manufacturing Way, Colombo',
            leadTimeDays: 7,
          ),
          const SupplierSummary(
            id: 2,
            name: 'Beta Polymer Ltd',
            supplierCode: 'SUP-002',
            contactPerson: 'Bob Jones',
            email: 'bob@betapolymer.com',
            phone: '+94 71 987 6543',
            paymentTerms: 'Net 15',
            isActive: false,
            address: '22 Industrial Zone, Kandy',
            leadTimeDays: 5,
          ),
        ],
        super(ApiClient(storage: MockSessionStorage(), baseUrl: 'http://localhost:5070/api'));

  List<SupplierSummary> _suppliers;
  bool deleteCalled = false;
  int? deletedSupplierId;
  bool updateCalled = false;
  Map<String, dynamic>? updatedData;

  @override
  Future<List<SupplierSummary>> getSuppliers() async => _suppliers;

  @override
  Future<SupplierSummary> getSupplierById(int id) async {
    return _suppliers.firstWhere((s) => s.id == id);
  }

  @override
  Future<SupplierAnalytics?> getSupplierAnalytics() async {
    return SupplierAnalytics(
      totalSuppliers: _suppliers.length,
      activeSuppliers: _suppliers.where((s) => s.isActive).length,
      averageRating: 0.0,
      totalSpend: 50000.0,
    );
  }

  @override
  Future<void> deleteSupplier(int id) async {
    deleteCalled = true;
    deletedSupplierId = id;
    _suppliers = _suppliers.map((s) => s.id == id
        ? SupplierSummary(
            id: s.id,
            name: s.name,
            supplierCode: s.supplierCode,
            contactPerson: s.contactPerson,
            email: s.email,
            phone: s.phone,
            paymentTerms: s.paymentTerms,
            isActive: false,
            address: s.address,
            leadTimeDays: s.leadTimeDays,
          )
        : s).toList();
  }

  @override
  Future<SupplierSummary> updateSupplier(int id, Map<String, dynamic> data) async {
    updateCalled = true;
    updatedData = data;
    final updated = SupplierSummary(
      id: id,
      name: data['name']?.toString() ?? 'Updated',
      supplierCode: data['supplierCode']?.toString() ?? 'SUP-$id',
      contactPerson: '',
      email: data['contactEmail']?.toString() ?? '',
      phone: data['contactPhone']?.toString() ?? '',
      paymentTerms: data['paymentTerms']?.toString() ?? 'Net 30',
      isActive: data['isActive'] == true,
      address: data['address']?.toString() ?? '',
      leadTimeDays: (data['leadTimeDays'] as num?)?.toInt() ?? 7,
    );
    _suppliers = _suppliers.map((s) => s.id == id ? updated : s).toList();
    return updated;
  }

  @override
  Future<List<PurchaseOrderSummary>> getPurchaseOrders() async => [];
}

void main() {
  testWidgets('SupplierStatusScreen renders without rating and has View, Edit, Delete buttons', (tester) async {
    final service = FakeSupplierService();
    await tester.pumpWidget(
      MaterialApp(
        home: SupplierStatusScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    // Verify rating is NOT shown anywhere
    expect(find.text('Avg Rating'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);

    // Verify metrics matching web
    expect(find.text('Total Vendors'), findsOneWidget);
    expect(find.text('Active Vendors'), findsOneWidget);
    expect(find.text('Inactive Vendors'), findsOneWidget);

    // Verify suppliers list
    expect(find.text('Apex Industrial Steel Corp'), findsOneWidget);
    expect(find.text('Beta Polymer Ltd'), findsOneWidget);

    // Verify View, Edit, Delete buttons
    expect(find.text('View'), findsNWidgets(2));
    expect(find.text('Edit'), findsNWidgets(2));
    expect(find.text('Delete'), findsOneWidget); // On active supplier
    expect(find.text('Activate'), findsOneWidget); // On inactive supplier

    // Tap Delete button -> triggers deactivation confirmation modal
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate Supplier'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to deactivate'), findsOneWidget);

    // Confirm deactivation
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(service.deleteCalled, isTrue);
    expect(service.deletedSupplierId, equals(1));
  });

  testWidgets('SupplierDetailScreen renders supplier profile, contract details, and action buttons', (tester) async {
    final service = FakeSupplierService();
    final supplier = await service.getSupplierById(1);

    await tester.pumpWidget(
      MaterialApp(
        home: SupplierDetailScreen(supplier: supplier, service: service),
      ),
    );
    await tester.pumpAndSettle();

    // Verify no rating is shown
    expect(find.byIcon(Icons.star), findsNothing);

    // Verify details
    expect(find.text('Apex Industrial Steel Corp'), findsWidgets);
    expect(find.text('SUP-001'), findsOneWidget);
    expect(find.text('ACTIVE PARTNER'), findsOneWidget);
    expect(find.text('alice@apexsteel.com'), findsOneWidget);
    expect(find.text('Material Quotes'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
  });
}

