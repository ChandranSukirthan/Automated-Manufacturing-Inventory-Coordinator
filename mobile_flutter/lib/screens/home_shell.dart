import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/quality_service.dart';
import 'dashboard_screen.dart';
import 'defects_screen.dart';
import 'quarantine_screen.dart';
import 'quarantine_history_screen.dart';
import 'role_dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.appState,
    required this.qualityService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.session!.user;
    final isQualityInspector = user.isQualityInspector;
    final screens = isQualityInspector
        ? [
            DashboardScreen(service: widget.qualityService),
            DefectsScreen(service: widget.qualityService),
            QuarantineScreen(service: widget.qualityService),
            QuarantineHistoryScreen(service: widget.qualityService),
          ]
        : [
            RoleDashboardScreen(
              service: widget.qualityService,
              role: user.role,
            ),
          ];
    final titles = isQualityInspector
        ? ['Dashboard', 'Defect reports', 'Quarantine', 'History']
        : ['Dashboard'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'logout') await widget.appState.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'profile',
                enabled: false,
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
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: isQualityInspector
          ? NavigationBar(
              selectedIndex: _selectedIndex,
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
          : null,
    );
  }
}
