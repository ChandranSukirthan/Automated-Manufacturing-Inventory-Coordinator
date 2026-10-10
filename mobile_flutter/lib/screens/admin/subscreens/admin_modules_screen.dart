import 'package:flutter/material.dart';
import '../../../app_state.dart';
import '../../../services/api_client.dart';
import '../../../services/quality_service.dart';
import '../../../services/purchase_order_service.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../profile_screen.dart';
import '../../worker_dashboard_screen.dart';
import '../../defects_screen.dart';
import '../../ai_validation_screen.dart';
import '../../quarantine_screen.dart';
import '../../quarantine_history_screen.dart';
import '../../purchase_orders/po_list_screen.dart';
import '../../purchase_orders/supplier_status_screen.dart';
import '../../purchase_orders/procurement_details_screen.dart';
import 'user_management_screen.dart';
import 'audit_logs_screen.dart';
import 'roles_reference_screen.dart';
import 'maintenance_list_screen.dart';

class AdminModulesScreen extends StatelessWidget {
  const AdminModulesScreen({
    required this.apiClient,
    required this.service,
    this.appState,
    super.key,
  });
  final ApiClient apiClient;
  final AdminApiService service;
  final AppState? appState;
  @override
  Widget build(BuildContext context) {
    final quality = QualityService(apiClient);
    final orders = PurchaseOrderService(apiClient);
    Widget link(String title, IconData icon, Widget screen) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Admin navigation',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        link(
          'User Directory',
          Icons.people_outline,
          UserManagementScreen(service: service),
        ),
        link(
          'Roles & Permissions',
          Icons.shield_outlined,
          const RolesReferenceScreen(),
        ),
        link('Audit Logs', Icons.history, AuditLogsScreen(service: service)),
        link(
          'Maintenance Logs',
          Icons.build_outlined,
          MaintenanceMachinesScreen(service: service),
        ),
        if (appState != null)
          link(
            'My Profile',
            Icons.person_outline,
            ProfileScreen(appState: appState!),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Shared operations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        link(
          'Purchase Orders',
          Icons.receipt_long,
          POListScreen(
            service: orders,
            allowManagement: false,
            allowApproval: true,
          ),
        ),
        link(
          'Purchase Order Approvals',
          Icons.credit_card,
          POListScreen(
            service: orders,
            allowManagement: false,
            allowApproval: true,
            initialFilter: 'PendingApproval',
          ),
        ),
        link(
          'Suppliers',
          Icons.business,
          SupplierStatusScreen(service: orders),
        ),
        link(
          'AI Procurement',
          Icons.psychology_outlined,
          ProcurementDetailsScreen(
            service: orders,
            allowOrderManagement: false,
          ),
        ),
        link(
          'Worker Inventory & Replenishment',
          Icons.inventory_2_outlined,
          WorkerDashboardScreen(qualityService: quality, appState: appState),
        ),
        link(
          'Defect Reports',
          Icons.assignment_outlined,
          DefectsScreen(service: quality),
        ),
        link(
          'AI Quality Validation',
          Icons.verified_outlined,
          AiValidationScreen(service: quality),
        ),
        link(
          'Quarantine',
          Icons.shield_outlined,
          QuarantineScreen(service: quality),
        ),
        link(
          'Quarantine History',
          Icons.history,
          QuarantineHistoryScreen(service: quality),
        ),
      ],
    );
  }
}

class MaintenanceMachinesScreen extends StatefulWidget {
  const MaintenanceMachinesScreen({required this.service, super.key});
  final AdminApiService service;
  @override
  State<MaintenanceMachinesScreen> createState() => _MaintenanceMachinesState();
}

class _MaintenanceMachinesState extends State<MaintenanceMachinesScreen> {
  late final _machines = widget.service.getMachines();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Maintenance Logs')),
    body: FutureBuilder(
      future: _machines,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load machines: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            for (final machine in snapshot.data!)
              ListTile(
                title: Text(machine.name),
                subtitle: Text(machine.status),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaintenanceListScreen(
                      machine: machine,
                      service: widget.service,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
