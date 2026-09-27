import 'package:flutter/material.dart';

import '../app_state.dart';
import '../controllers/inventory_controller.dart';
import '../services/purchase_order_service.dart';
import '../services/quality_service.dart';
import '../services/admin_service.dart';
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
import 'admin_hub_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.appState,
    required this.qualityService,
    required this.poService,
    required this.adminService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;
  final PurchaseOrderService poService;
  final AdminService adminService;

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
    final isITAdmin = user.isITAdmin;
    final isQualityInspector = user.isQualityInspector;
    final isManager = user.isSupplyChainManager || isITAdmin;

    final List<Widget> screens;
    final List<String> titles;

    if (isITAdmin) {
      screens = [
        AdminHubScreen(adminService: widget.adminService),
        POStatusDashboardScreen(service: widget.poService),
        POListScreen(service: widget.poService),
        AIWorkflowStatusScreen(service: widget.poService),
        DashboardScreen(
          service: widget.qualityService,
          appState: widget.appState,
        ),
      ];
      titles = [
        'Admin Hub',
        'PO Dashboard',
        'Purchase Orders',
        'AI Workflows',
        'Quality Overview',
      ];
    } else if (isManager) {
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
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F1B2B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF070E17)),
              accountName: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFF5CC8F8),
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.cyanAccent),
              title: const Text('My Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(appState: widget.appState)),
                );
              },
            ),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('MODULES & WORKFLOWS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            if (isITAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.amberAccent),
                title: const Text('Admin Hub', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 0);
                },
              ),
            if (isManager || isITAdmin) ...[
              ListTile(
                leading: const Icon(Icons.dashboard_outlined, color: Colors.cyanAccent),
                title: const Text('PO Dashboard', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = isITAdmin ? 1 : 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.cyanAccent),
                title: const Text('Purchase Orders', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = isITAdmin ? 2 : 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology_outlined, color: Colors.cyanAccent),
                title: const Text('AI Workflows & Approvals', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = isITAdmin ? 3 : 2);
                },
              ),
            ],
            if (isQualityInspector || isITAdmin) ...[
              ListTile(
                leading: const Icon(Icons.fact_check_outlined, color: Colors.greenAccent),
                title: const Text('Quality & Defect Reports', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = isITAdmin ? 4 : 0);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined, color: Colors.purpleAccent),
              title: const Text('Factory Assistant', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Factory Assistant')),
                      body: FactoryAssistantView(
                        controller: _inventoryController,
                        poService: widget.poService,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await widget.appState.logout();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex < screens.length ? _selectedIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: isITAdmin
          ? NavigationBar(
              selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'PO Dash',
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
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Quality',
                ),
              ],
            )
          : isManager
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
