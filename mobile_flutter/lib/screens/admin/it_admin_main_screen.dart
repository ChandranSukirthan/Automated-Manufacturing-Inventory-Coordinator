import 'package:flutter/material.dart';

import 'package:mobile_flutter/models/admin/machine_model.dart';
import 'package:mobile_flutter/models/admin/shift_model.dart';
import 'package:mobile_flutter/models/admin/workflow_model.dart';
import 'package:mobile_flutter/models/admin/system_health_model.dart';
import 'package:mobile_flutter/services/admin/admin_api_service.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/screens/admin/tabs/admin_overview_tab.dart';
import 'package:mobile_flutter/screens/admin/tabs/production_equipment_tab.dart';
import 'package:mobile_flutter/screens/admin/tabs/agent_workflows_tab.dart';
import 'package:mobile_flutter/screens/admin/tabs/system_health_tab.dart';

class ItAdminMainScreen extends StatefulWidget {
  final ApiClient apiClient;
  final bool showAppBar;
  final VoidCallback? onSignOut;
  final String? userName;
  final String? userEmail;

  const ItAdminMainScreen({
    required this.apiClient,
    this.showAppBar = true,
    this.onSignOut,
    this.userName,
    this.userEmail,
    super.key,
  });

  @override
  State<ItAdminMainScreen> createState() => _ItAdminMainScreenState();
}

class _ItAdminMainScreenState extends State<ItAdminMainScreen> {
  late final AdminApiService _service;
  int _currentIndex = 0;

  List<MachineModel> _machines = [];
  List<ShiftModel> _shifts = [];
  List<WorkflowModel> _workflows = [];
  SystemHealthModel? _health;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = AdminApiService(apiClient: widget.apiClient);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getMachines().catchError((_) => <MachineModel>[]),
        _service.getShifts().catchError((_) => <ShiftModel>[]),
        _service.getAgentWorkflows().catchError((_) => <WorkflowModel>[]),
        _service.getSystemHealth().catchError((_) => SystemHealthModel(overallStatus: 'ONLINE', services: [])),
      ]);

      if (mounted) {
        setState(() {
          _machines = (results[0] as List<dynamic>?)?.cast<MachineModel>() ?? <MachineModel>[];
          _shifts = (results[1] as List<dynamic>?)?.cast<ShiftModel>() ?? <ShiftModel>[];
          _workflows = (results[2] as List<dynamic>?)?.cast<WorkflowModel>() ?? <WorkflowModel>[];
          _health = results[3] as SystemHealthModel?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to sync administrative telemetry: $e';
          _loading = false;
        });
      }
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Color(0xFF06B6D4), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName ?? 'System Administrator',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.userEmail ?? 'admin@amic.com',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Role: ITAdmin (Full Access)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onSignOut?.call();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _workflows.where((w) => w.isWaitingForApproval).length;

    final tabs = [
      AdminOverviewTab(
        machines: _machines,
        shifts: _shifts,
        workflows: _workflows,
        health: _health,
        loading: _loading,
        onRefresh: _loadAllData,
        onNavigateTab: (idx) => setState(() => _currentIndex = idx),
      ),
      ProductionEquipmentTab(
        machines: _machines,
        shifts: _shifts,
        service: _service,
        loading: _loading,
        onRefresh: _loadAllData,
      ),
      AgentWorkflowsTab(
        workflows: _workflows,
        service: _service,
        loading: _loading,
        onRefresh: _loadAllData,
      ),
      SystemHealthTab(
        health: _health,
        loading: _loading,
        onRefresh: _loadAllData,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF06B6D4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IT Admin Console',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Student 4 • Production & Monitoring',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF06B6D4)),
                  tooltip: 'Refresh Telemetry',
                  onPressed: _loadAllData,
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF06B6D4)),
                    tooltip: 'Account Profile',
                    onPressed: _showProfileDialog,
                  ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security_rounded, color: Color(0xFF06B6D4), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'IT Admin Console (Student 4)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF06B6D4), size: 18),
                    tooltip: 'Refresh',
                    onPressed: _loadAllData,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _error != null && _machines.isEmpty && _workflows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              color: Color(0xFFEF4444), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFE2E8F0)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadAllData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06B6D4),
                              foregroundColor: const Color(0xFF0B0F19),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : tabs[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF06B6D4),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.precision_manufacturing_outlined),
              activeIcon: Icon(Icons.precision_manufacturing_rounded),
              label: 'Production',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: const Color(0xFFF59E0B),
                child: const Icon(Icons.psychology_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: const Color(0xFFF59E0B),
                child: const Icon(Icons.psychology_rounded),
              ),
              label: 'Workflows',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.monitor_heart_outlined),
              activeIcon: Icon(Icons.monitor_heart_rounded),
              label: 'Health',
            ),
          ],
        ),
      ),
    );
  }
}
