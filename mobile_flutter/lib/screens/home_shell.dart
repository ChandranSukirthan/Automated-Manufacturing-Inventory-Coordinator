import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_state.dart';
import '../services/admin_service.dart';
import '../services/purchase_order_service.dart';
import '../services/quality_service.dart';
import 'package:mobile_flutter/screens/admin/it_admin_main_screen.dart';
import 'worker_dashboard_screen.dart';
import 'dashboard_screen.dart';
import 'ai_validation_screen.dart';
import 'defects_screen.dart';
import 'quarantine_screen.dart';
import 'quarantine_history_screen.dart';
import 'profile_screen.dart';
import 'purchase_orders/po_status_dashboard_screen.dart';
import 'purchase_orders/po_list_screen.dart';
import 'purchase_orders/supplier_status_screen.dart';
import 'purchase_orders/notification_status_screen.dart';
import 'purchase_orders/procurement_details_screen.dart';
import 'purchase_orders/ai_workflow_status_screen.dart';
import 'purchase_orders/incoming_supplies_screen.dart';

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

  void _onTabSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _showProfilePopup() async {
    final user = widget.appState.session!.user;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _ProfilePopup(
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        onSaveName: widget.appState.updateProfile,
        onSignOut: widget.appState.logout,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.session!.user;
    final isITAdmin = user.isITAdmin || user.role == 'ITAdmin' || user.role == '3' || user.role == 'Admin';
    final isFloorWorker = user.isFloorWorker || user.role == 'FloorWorker' || user.role == '0' || user.role == 'Worker';
    final isQualityInspector = user.isQualityInspector || user.role == 'QualityInspector' || user.role == '2';

    if (isITAdmin) {
      return ItAdminMainScreen(
        apiClient: widget.qualityService.api,
        appState: widget.appState,
        showAppBar: true,
        onSignOut: widget.appState.logout,
        userName: user.fullName,
        userEmail: user.email,
      );
    }

    if (isFloorWorker) {
      return WorkerDashboardScreen(
        qualityService: widget.qualityService,
        appState: widget.appState,
      );
    }

    final qaTitles = const [
      ('QA Operations', 'Quality Overview & Health'),
      ('AI Validation & Safety', 'Multi-Agent Quality Gates'),
      ('Defect Management', 'Active Quality Reports'),
      ('Quarantine Control', 'Lot Containment & Safety'),
      ('Quarantine History', 'Archived Dispositions'),
    ];
    final currentQaTitle = isQualityInspector
        ? qaTitles[_selectedIndex.clamp(0, qaTitles.length - 1)]
        : ('Floor Operations', 'Manufacturing Inventory');

    final List<Widget> screens;
    final List<String> titles;

    if (isQualityInspector) {
      screens = [
        DashboardScreen(
          service: widget.qualityService,
          appState: widget.appState,
          onNavigateTab: _onTabSelect,
        ),
        AiValidationScreen(
          service: widget.qualityService,
          showAppBar: false,
        ),
        DefectsScreen(service: widget.qualityService, showAppBar: false),
        QuarantineScreen(service: widget.qualityService),
        QuarantineHistoryScreen(
          service: widget.qualityService,
          showPageChrome: false,
        ),
      ];
      titles = ['QA Operations', 'AI Validation & Safety', 'Defect Management', 'Quarantine Control', 'Quarantine History'];
    } else {
      screens = [
        POStatusDashboardScreen(
          service: widget.poService,
          onNavigateTab: _onTabSelect,
        ),
        POListScreen(service: widget.poService, showAppBar: false,
            isActive: _selectedIndex == 1),
        AIWorkflowStatusScreen(service: widget.poService, showAppBar: false),
        ProcurementDetailsScreen(service: widget.poService, showAppBar: false),
        SupplierStatusScreen(service: widget.poService, showAppBar: false),
        IncomingSuppliesScreen(service: widget.poService, showAppBar: false),
        NotificationStatusScreen(service: widget.poService, showAppBar: false),
      ];
      titles = [
        'Command Center',
        'Purchase Orders',
        'AI Workflows & Approvals',
        'AI Sourcing Hub',
        'Suppliers & Verification',
        'Deliveries & Logistics',
        'Low Stock & Reorder',
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isQualityInspector
          ? PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dynamic Title Header
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currentQaTitle.$1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            currentQaTitle.$2,
                                            style: const TextStyle(
                                              color: Color(0xFF60A5FA),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Profile Avatar Button
                        InkWell(
                          onTap: _showProfilePopup,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    user.fullName.isNotEmpty
                                        ? user.fullName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    user.fullName.split(' ').first,
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: AppBar(
                title: Text(titles[_selectedIndex < titles.length ? _selectedIndex : 0]),
                actions: [
                  IconButton(
                    onPressed: () => _onTabSelect(2),
                    icon: const Icon(Icons.psychology_outlined),
                    color: const Color(0xFF06B6D4),
                    tooltip: 'AI Workflows & Approvals',
                  ),
                  IconButton(
                    onPressed: _showProfilePopup,
                    icon: const Icon(Icons.account_circle_outlined),
                    color: AppColors.primaryLight,
                    tooltip: 'Profile',
                  ),
                ],
              ),
            ),
      drawer: isQualityInspector
          ? null
          : Drawer(
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
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined, color: Color(0xFF5CC8F8)),
                    title: const Text('Command Center', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF5CC8F8)),
                    title: const Text('Purchase Orders', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined, color: Color(0xFF06B6D4)),
                    title: const Text('AI Workflows & Approvals', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined, color: Color(0xFFA855F7)),
                    title: const Text('AI Sourcing Hub', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.business_outlined, color: Color(0xFF10B981)),
                    title: const Text('Suppliers & Verification', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 4);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined, color: Color(0xFF38BDF8)),
                    title: const Text('Deliveries & Logistics', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 5);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                    title: const Text('Low Stock Alerts & Reorder', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 6);
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
      bottomNavigationBar: isQualityInspector
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090E1A),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Row(
                    children: [
                      _navItem(
                        index: 0,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                      ),
                      _navItem(
                        index: 1,
                        icon: Icons.auto_awesome_rounded,
                        label: 'AI Safety',
                      ),
                      _navItem(
                        index: 2,
                        icon: Icons.warning_amber_rounded,
                        label: 'Defects',
                      ),
                      _navItem(
                        index: 3,
                        icon: Icons.shield_outlined,
                        label: 'Quarantine',
                      ),
                      _navItem(
                        index: 4,
                        icon: Icons.history_rounded,
                        label: 'History',
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090E1A),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Row(
                    children: [
                      _navItem(
                        index: 0,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                      ),
                      _navItem(
                        index: 1,
                        icon: Icons.receipt_long_rounded,
                        label: 'Orders',
                      ),
                      _navItem(
                        index: 2,
                        icon: Icons.psychology_rounded,
                        label: 'Workflows',
                      ),
                      _navItem(
                        index: 3,
                        icon: Icons.auto_awesome_rounded,
                        label: 'Sourcing',
                      ),
                      _navItem(
                        index: 4,
                        icon: Icons.business_rounded,
                        label: 'Suppliers',
                      ),
                      _navItem(
                        index: 5,
                        icon: Icons.local_shipping_rounded,
                        label: 'Deliveries',
                      ),
                      _navItem(
                        index: 6,
                        icon: Icons.warning_amber_rounded,
                        label: 'Alerts',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelect(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 9.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePopup extends StatefulWidget {
  const _ProfilePopup({
    required this.fullName,
    required this.email,
    required this.role,
    required this.onSaveName,
    required this.onSignOut,
  });

  final String fullName;
  final String email;
  final String role;
  final Future<dynamic> Function(String fullName) onSaveName;
  final Future<void> Function() onSignOut;

  @override
  State<_ProfilePopup> createState() => _ProfilePopupState();
}

class _ProfilePopupState extends State<_ProfilePopup> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.fullName,
  );
  bool _editing = false;
  bool _saving = false;
  bool _signingOut = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaveName(name);
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = exception.toString();
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await widget.onSignOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.fullName.trim().isEmpty
                      ? '?'
                      : widget.fullName.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editing)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Your name',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _saving ? null : _saveName,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded, color: Color(0xFF34D399)),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _editing = true),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: const Color(0xFF60A5FA),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    Text(
                      widget.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assigned Role',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        widget.role,
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.role == 'QualityInspector') ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quality Scope',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      Text(
                        'Factory Quality Assurance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.errorText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out of Console'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFFFCA5A5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
