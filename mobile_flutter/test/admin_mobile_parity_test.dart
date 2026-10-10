import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/admin/admin_api_service.dart';
import 'package:mobile_flutter/models/admin/machine_model.dart';
import 'package:mobile_flutter/models/admin/shift_model.dart';
import 'package:mobile_flutter/models/admin/audit_log_model.dart';
import 'package:mobile_flutter/screens/admin/subscreens/admin_modules_screen.dart';
import 'package:mobile_flutter/screens/admin/subscreens/maintenance_list_screen.dart';
import 'package:mobile_flutter/screens/admin/subscreens/shift_detail_screen.dart';
import 'package:mobile_flutter/screens/admin/subscreens/audit_logs_screen.dart';
import 'package:mobile_flutter/screens/admin/tabs/system_health_tab.dart';
import 'package:mobile_flutter/screens/admin/it_admin_main_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_list_screen.dart';
import 'package:mobile_flutter/screens/purchase_orders/po_details_screen.dart';
import 'purchase_order_refresh_test.dart' show OrderService;

class AuditApi extends Fake implements ApiClient {
  final calls = <String>[];
  Map<String, dynamic>? body;
  @override
  Future<dynamic> get(String path) async {
    calls.add(path);
    return [];
  }

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? data]) async {
    calls.add(path);
    body = data;
    return {};
  }

  @override
  Future<dynamic> delete(String path) async {
    calls.add(path);
    return null;
  }
}

class ParityAdmin extends Fake implements AdminApiService {
  final logs = <MaintenanceLogModel>[];
  Map<String, dynamic>? created;
  String? deletedShift;
  String? userFilter, entityFilter, actionFilter;
  @override
  Future<List<MaintenanceLogModel>> getMaintenanceLogs(String id) async =>
      List.of(logs);
  @override
  Future<void> createMaintenanceLog(
    String machineId,
    String description,
    String performedBy,
    int type,
  ) async {
    created = {
      'machineId': machineId,
      'description': description,
      'performedBy': performedBy,
      'type': type,
    };
    logs.add(
      MaintenanceLogModel.fromJson({
        'id': 'log-1',
        'machineId': machineId,
        'description': description,
        'performedBy': performedBy,
      }),
    );
  }

  @override
  Future<void> deleteMaintenanceLog(String id) async {
    logs.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> deleteShift(String id) async {
    deletedShift = id;
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs({
    String? userName,
    String? action,
    String? entity,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    userFilter = userName;
    entityFilter = entity;
    actionFilter = action;
    return [];
  }
}

Future<void> mount(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'maintenance and shift operations use admin endpoints and actual fields',
    () async {
      final api = AuditApi();
      final service = AdminApiService(apiClient: api);
      await service.createMaintenanceLog(
        'machine-1',
        'Serviced motor',
        'Technician',
        2,
      );
      expect(api.body, {
        'machineId': 'machine-1',
        'description': 'Serviced motor',
        'performedBy': 'Technician',
        'type': 2,
      });
      await service.deleteMaintenanceLog('log-1');
      await service.deleteShift('shift-1');
      expect(api.calls, [
        '/maintenance',
        '/maintenance/log-1',
        '/shifts/shift-1',
      ]);
    },
  );
  testWidgets('admin menu navigates to web role reference', (tester) async {
    await mount(
      tester,
      Scaffold(
        body: AdminModulesScreen(apiClient: AuditApi(), service: ParityAdmin()),
      ),
    );
    await tester.tap(find.text('Roles & Permissions'));
    await tester.pumpAndSettle();
    expect(find.text('IT Administrator'), findsOneWidget);
    expect(find.text('Manage Inventory Procurement'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin order list cannot create orders', (tester) async {
    await mount(
      tester,
      POListScreen(
        service: OrderService(),
        allowManagement: false,
        allowApproval: true,
        initialFilter: 'PendingApproval',
      ),
    );
    expect(find.text('Create PO'), findsNothing);
    await tester.tap(find.text('PO-TEST'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    expect(find.byTooltip('Delivery receipts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin approved order has no manager payment controls', (
    tester,
  ) async {
    final service = OrderService()..status = 'Approved';
    await mount(
      tester,
      PODetailsScreen(
        service: service,
        poId: 1,
        allowManagement: false,
        allowApproval: true,
      ),
    );
    expect(find.text('Pay with Stripe'), findsNothing);
    expect(find.text('Upload Bank Slip'), findsNothing);
    expect(find.byTooltip('Delivery receipts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('maintenance log create and confirmed delete', (tester) async {
    final service = ParityAdmin();
    await mount(
      tester,
      MaintenanceListScreen(
        machine: MachineModel.fromJson({
          'id': 'machine-1',
          'name': 'Packing line',
        }),
        service: service,
      ),
    );
    await tester.tap(find.text('Record maintenance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.created, isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'Serviced motor');
    await tester.enterText(find.byType(TextFormField).at(1), 'Technician');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.created?['machineId'], 'machine-1');
    expect(find.text('Serviced motor'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(service.logs, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shift deletion requires confirmation', (tester) async {
    final service = ParityAdmin();
    await mount(
      tester,
      ShiftDetailScreen(
        shift: ShiftModel.fromJson({'id': 'shift-1', 'name': 'Morning'}),
        service: service,
      ),
    );
    await tester.tap(find.byTooltip('Delete shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deletedShift, isNull);
    await tester.tap(find.byTooltip('Delete shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(service.deletedShift, 'shift-1');
  });
  testWidgets('audit filters send separate values and reset', (tester) async {
    final service = ParityAdmin();
    await mount(tester, AuditLogsScreen(service: service));
    await tester.enterText(find.byType(TextField).at(0), ' admin ');
    await tester.enterText(find.byType(TextField).at(1), ' Machine ');
    await tester.enterText(find.byType(TextField).at(2), ' DELETE ');
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(service.userFilter, 'admin');
    expect(service.entityFilter, 'Machine');
    expect(service.actionFilter, 'DELETE');
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(service.userFilter, '');
  });
  testWidgets('admin workflow polling runs every 15 seconds and stops after disposal', (tester) async {
    final api = AuditApi();
    await mount(tester,ItAdminMainScreen(apiClient: api));
    final initial = api.calls.where((c) => c == '/admin/agent-workflows').length;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c == '/admin/agent-workflows').length, initial + 1);
    await tester.pumpWidget(const SizedBox());
    final disposed = api.calls.length;
    await tester.pump(const Duration(seconds: 30));
    expect(api.calls.length,disposed);
    expect(tester.takeException(),isNull);
  });
  testWidgets('unknown health never invents online services', (tester) async {
    await mount(
      tester,
      SystemHealthTab(health: null, loading: false, onRefresh: () async {}),
    );
    expect(find.text('Overall Status: UNKNOWN'), findsOneWidget);
    expect(find.text('Stripe Billing Gateway'), findsNothing);
    expect(find.text('ONLINE'), findsNothing);
  });
}
