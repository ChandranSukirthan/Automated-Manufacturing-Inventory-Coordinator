import 'package:flutter/material.dart';

import '../app_state.dart';
import '../controllers/inventory_controller.dart';
import '../services/purchase_order_service.dart';
import '../services/quality_service.dart';
import '../views/factory_assistant_view.dart';
import 'dashboard_screen.dart';
import 'defects_screen.dart';
import 'quarantine_screen.dart';
import 'quarantine_history_screen.dart';
import 'role_dashboard_screen.dart';
import 'profile_screen.dart';
import 'purchase_orders/po_status_dashboard_screen.dart';
import 'purchase_orders/po_list_screen.dart';
import 'purchase_orders/ai_workflow_status_screen.dart';
import 'purchase_orders/supplier_status_screen.dart';
import 'purchase_orders/notification_status_screen.dart';
import 'purchase_orders/procurement_details_screen.dart';
import 'purchase_orders/incoming_supplies_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.appState,
    required this.qualityService,
    required this.poService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;
  final PurchaseOrderService poService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final InventoryController _inventoryController;

  @override
  void initState() {
    super.initState();
    _inventoryController = InventoryController(poService: widget.poService);
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.session!.user;
    final isQualityInspector = user.isQualityInspector;
    final isManager = user.isSupplyChainManager || user.isITAdmin;

    final List<Widget> screens;
    final List<String> titles;

    if (isManager) {
      screens = [
        POStatusDashboardScreen(service: widget.poService),
        POListScreen(service: widget.poService),
        AIWorkflowStatusScreen(service: widget.poService),
        SupplierStatusScreen(service: widget.poService),
        NotificationStatusScreen(service: widget.poService),
      ];
      titles = [
        'PO Dashboard',
        'Purchase Orders',
        'AI Workflows',
        'Suppliers',
        'Notifications',
      ];
    } else if (isQualityInspector) {
      screens = [
        DashboardScreen(
          service: widget.qualityService,
          appState: widget.appState,
        ),
        DefectsScreen(service: widget.qualityService),
        QuarantineScreen(service: widget.qualityService),
        QuarantineHistoryScreen(service: widget.qualityService),
      ];
      titles = ['Dashboard', 'Defect reports', 'Quarantine', 'History'];
    } else {
      screens = [
        FactoryAssistantView(
          controller: _inventoryController,
          poService: widget.poService,
        ),
        ProcurementDetailsScreen(service: widget.poService),
        IncomingSuppliesScreen(service: widget.poService),
        NotificationStatusScreen(service: widget.poService),
      ];
      titles = [
        'Factory Assistant',
        'Procurement Tracker',
        'Incoming Supplies',
        'Alerts',
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex < titles.length ? _selectedIndex : 0]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'logout') {
                await widget.appState.logout();
                return;
              }
              if (value != 'profile' || !mounted) return;

              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(appState: widget.appState),
                ),
              );
              if (mounted) setState(() {});
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'profile',
                enabled: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(user.email),
                    Text(user.role),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex < screens.length ? _selectedIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: isManager
          ? NavigationBar(
              selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: 'AI Flows',
                ),
                NavigationDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business),
                  label: 'Suppliers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_active_outlined),
                  selectedIcon: Icon(Icons.notifications_active),
                  label: 'Alerts',
                ),
              ],
            )
          : isQualityInspector
              ? NavigationBar(
                  selectedIndex: _selectedIndex < 4 ? _selectedIndex : 0,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check),
                      label: 'Defects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Quarantine',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history),
                      label: 'History',
                    ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: _selectedIndex < 4 ? _selectedIndex : 0,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.precision_manufacturing_outlined),
                      selectedIcon: Icon(Icons.precision_manufacturing),
                      label: 'Factory',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome),
                      label: 'Procurement',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping),
                      label: 'Deliveries',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_active_outlined),
                      selectedIcon: Icon(Icons.notifications_active),
                      label: 'Alerts',
                    ),
                  ],
                ),
    );
  }
}
