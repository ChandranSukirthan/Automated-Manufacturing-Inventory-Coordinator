import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'controllers/inventory_controller.dart';
import 'models/user_profile.dart';
import 'views/agentic_execution_log_view.dart';
import 'views/employee_management_view.dart';
import 'views/factory_assistant_view.dart';
import 'views/login_view.dart';
import 'views/manager_dashboard_view.dart';
import 'views/profile_view.dart';
import 'views/qa_control_center_view.dart';
import 'views/register_employee_view.dart';
import 'views/scanner_view.dart';
import 'views/stock_view.dart';
import 'views/tracker_view.dart';

void main() {
  runApp(const MyApp());
}

class _RegisteredEmployee {
  UserProfile profile;
  final String password;

  _RegisteredEmployee({required this.profile, required this.password});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _adminUsername = 'Admin';
  static const _adminPassword = 'Admin@123';

  final _navigatorKey = GlobalKey<NavigatorState>();
  final List<_RegisteredEmployee> _registeredEmployees = [];
  late final InventoryController _inventoryController;
  late final ScrollController _topNavigationScrollController;

  UserProfile? _profile;
  int _nextFloorWorkerNumber = 1;
  int _nextSupplyManagerNumber = 1;
  int _nextQualityInspectorNumber = 1;
  int _currentScreenIndex = 0;
  bool _showExecutionLogModal = false;

  @override
  void initState() {
    super.initState();
    _inventoryController = InventoryController();
    _topNavigationScrollController = ScrollController();
  }

  @override
  void dispose() {
    _topNavigationScrollController.dispose();
    _inventoryController.dispose();
    super.dispose();
  }

  bool _signInAdmin(String username, String password) {
    if (username != _adminUsername || password != _adminPassword) return false;

    setState(() {
      _profile = UserProfile(
        fullName: 'System Administrator',
        username: _adminUsername,
        employeeId: 'ADMIN',
        role: 'IT / System Admin',
        isOnline: true,
        lastLoginAt: DateTime.now(),
      );
      _currentScreenIndex = 1;
      _showExecutionLogModal = false;
    });
    return true;
  }

  bool _signInEmployee(String employeeIdOrUsername, String password) {
    final normalizedInput = employeeIdOrUsername.trim().toLowerCase();
    for (final employee in _registeredEmployees) {
      final profile = employee.profile;
      final idMatches = profile.employeeId.toLowerCase() == normalizedInput;
      final usernameMatches = profile.username.toLowerCase() == normalizedInput;
      if ((idMatches || usernameMatches) && employee.password == password) {
        final signedInProfile = profile.copyWith(
          isOnline: true,
          lastLoginAt: DateTime.now(),
        );
        setState(() {
          employee.profile = signedInProfile;
          _profile = signedInProfile;
          _currentScreenIndex = _homeScreenFor(signedInProfile);
          _showExecutionLogModal = false;
        });
        return true;
      }
    }
    return false;
  }

  String _registerEmployee({
    required String fullName,
    required String username,
    required String role,
    required String password,
    Uint8List? profileImageBytes,
  }) {
    final employeeId = switch (role) {
      'Factory / Floor Worker' => 'EMP$_nextFloorWorkerNumber',
      'Supply Chain Manager' => 'SM$_nextSupplyManagerNumber',
      'Quality Inspector' => 'QI$_nextQualityInspectorNumber',
      _ => 'EMP$_nextFloorWorkerNumber',
    };
    final profile = UserProfile(
      fullName: fullName,
      username: username,
      employeeId: employeeId,
      role: role,
      profileImageBytes: profileImageBytes,
    );

    setState(() {
      _registeredEmployees.add(
        _RegisteredEmployee(profile: profile, password: password),
      );
      switch (role) {
        case 'Factory / Floor Worker':
          _nextFloorWorkerNumber += 1;
          break;
        case 'Supply Chain Manager':
          _nextSupplyManagerNumber += 1;
          break;
        case 'Quality Inspector':
          _nextQualityInspectorNumber += 1;
          break;
      }
    });
    return employeeId;
  }

  void _updateProfile(UserProfile updatedProfile) {
    final currentProfile = _profile;
    if (currentProfile == null) return;

    final canEditUsername = !currentProfile.isFloorWorker && !currentProfile.isAdmin;
    final protectedProfile = UserProfile(
      fullName: updatedProfile.fullName.trim(),
      username: canEditUsername ? updatedProfile.username.trim() : currentProfile.username,
      employeeId: currentProfile.employeeId,
      role: currentProfile.role,
      isOnline: currentProfile.isOnline,
      lastLoginAt: currentProfile.lastLoginAt,
      lastLogoutAt: currentProfile.lastLogoutAt,
      profileImageBytes: updatedProfile.profileImageBytes,
    );

    setState(() {
      _profile = protectedProfile;
      for (final employee in _registeredEmployees) {
        if (employee.profile.employeeId == protectedProfile.employeeId) {
          employee.profile = protectedProfile;
          break;
        }
      }
    });
  }

  void _updateEmployee(String employeeId, UserProfile updatedEmployee) {
    final administrator = _profile;
    if (administrator == null || !administrator.isAdmin) return;

    setState(() {
      for (final employee in _registeredEmployees) {
        if (employee.profile.employeeId == employeeId) {
          employee.profile = updatedEmployee.copyWith(
            employeeId: employee.profile.employeeId,
          );
          if (_profile?.employeeId == employeeId) {
            _profile = employee.profile;
          }
          break;
        }
      }
    });
  }

  void _deleteEmployee(String employeeId) {
    final administrator = _profile;
    if (administrator == null || !administrator.isAdmin) return;
    setState(() {
      _registeredEmployees.removeWhere(
        (employee) => employee.profile.employeeId == employeeId,
      );
    });
  }

  Future<void> _openEmployeeRegistration(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterEmployeeView(
          onRegister: _registerEmployee,
          onBackToLogin: () => Navigator.of(context).pop(),
          currentUserRole: _profile?.role ?? 'Admin',
        ),
      ),
    );
  }

  void _openEmployeeManagement() {
    if (!(_profile?.isAdmin ?? false)) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => EmployeeManagementView(
          employees: () => _registeredEmployees
              .map((employee) => employee.profile)
              .toList(growable: false),
          canManageEmployees: true,
          onAddEmployee: _openEmployeeRegistration,
          onUpdateEmployee: _updateEmployee,
          onDeleteEmployee: _deleteEmployee,
        ),
      ),
    );
  }

  void _openProfile() {
    final profile = _profile;
    if (profile == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ProfileView(
          profile: profile,
          onProfileChanged: _updateProfile,
          onManageEmployees: profile.isAdmin ? _openEmployeeManagement : null,
        ),
      ),
    );
  }

  void _signOut() {
    setState(() {
      final currentProfile = _profile;
      if (currentProfile != null && !currentProfile.isAdmin) {
        for (final employee in _registeredEmployees) {
          if (employee.profile.employeeId == currentProfile.employeeId) {
            employee.profile = employee.profile.copyWith(
              isOnline: false,
              lastLogoutAt: DateTime.now(),
            );
            break;
          }
        }
      }
      _profile = null;
      _currentScreenIndex = 0;
      _showExecutionLogModal = false;
    });
  }

  bool _canAccessScreen(UserProfile profile, int screenIndex) {
    if (profile.isAdmin || profile.isManager) {
      return screenIndex == 1 ||
          screenIndex == 4 ||
          screenIndex == 5 ||
          screenIndex == 6;
    }
    if (profile.isFloorWorker) {
      return screenIndex == 0 ||
          screenIndex == 2 ||
          screenIndex == 3 ||
          screenIndex == 4 ||
          screenIndex == 5;
    }
    return profile.role == 'Quality Inspector' && screenIndex == 2;
  }

  int _homeScreenFor(UserProfile profile) {
    if (profile.isAdmin || profile.isManager) return 1;
    if (profile.role == 'Quality Inspector') return 2;
    return 0;
  }

  Widget _accessDeniedView() {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'You do not have permission to view this screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBackground = Color(0xFF121212);
    const darkSurface = Color(0xFF1E1E1E);

    final profile = _profile;
    Widget? currentBody;

    if (profile != null && !_canAccessScreen(profile, _currentScreenIndex)) {
      currentBody = _accessDeniedView();
    } else if (profile != null && _showExecutionLogModal) {
      currentBody = AgenticExecutionLogView(
        onClose: () => setState(() => _showExecutionLogModal = false),
      );
    } else if (profile != null) {
      switch (_currentScreenIndex) {
        case 0:
          currentBody = FactoryAssistantView(
            controller: _inventoryController,
            profile: profile,
            onProfileChanged: _updateProfile,
            onLogout: _signOut,
            onManageEmployees: _openEmployeeManagement,
            onTabSelected: (index) {
              if (index == 1) {
                setState(() => _currentScreenIndex = 3);
              } else if (index == 2) {
                setState(() => _currentScreenIndex = 4);
              } else if (index == 3) {
                setState(() => _currentScreenIndex = 5);
              }
            },
          );
          break;
        case 1:
          currentBody = ManagerDashboardView(
            canApproveFinancialActions: profile.canApproveFinancialActions,
            onOpenExecutionLog: () => setState(() => _showExecutionLogModal = true),
            onWorkflowStatusChanged: _inventoryController.setWorkflowStatus,
            onTabSelected: (index) {
              setState(() {
                _showExecutionLogModal = index == 3;
                _currentScreenIndex = switch (index) {
                  0 => 1,
                  1 => 4,
                  2 => 5,
                  _ => _currentScreenIndex,
                };
              });
            },
          );
          break;
        case 2:
          currentBody = const QaControlCenterView();
          break;
        case 3:
          currentBody = ScannerView(
            controller: _inventoryController,
            onBack: () => setState(() => _currentScreenIndex = 0),
          );
          break;
        case 4:
          currentBody = StockView(
            controller: _inventoryController,
            onBack: () => setState(() => _currentScreenIndex = _homeScreenFor(profile)),
          );
          break;
        case 5:
          currentBody = TrackerView(
            controller: _inventoryController,
            onBack: () => setState(
              () => _currentScreenIndex = profile.isFloorWorker ? 0 : 1,
            ),
            onTabSelected: (index) {
              setState(() {
                _currentScreenIndex = switch (index) {
                  0 => profile.isFloorWorker ? 0 : 1,
                  1 => 3,
                  2 => 4,
                  3 => 5,
                  _ => _currentScreenIndex,
                };
              });
            },
          );
          break;
        case 6:
          currentBody = EmployeeManagementView(
            employees: () => _registeredEmployees
                .map((employee) => employee.profile)
                .toList(growable: false),
            canManageEmployees: profile.isAdmin,
            onAddEmployee: profile.isAdmin ? _openEmployeeRegistration : null,
            onUpdateEmployee: profile.isAdmin ? _updateEmployee : null,
            onDeleteEmployee: profile.isAdmin ? _deleteEmployee : null,
          );
          break;
        default:
          currentBody = _accessDeniedView();
      }
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Automated Manufacturing Inventory Coordinator',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: yellowAccent,
          onPrimary: Colors.black,
          secondary: yellowAccent,
          onSecondary: Colors.black,
          surface: darkSurface,
          onSurface: Colors.white,
        ),
      ),
      home: profile == null
          ? LoginView(
              onAdminLogin: _signInAdmin,
              onEmployeeLogin: _signInEmployee,
            )
          : Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFF0F1B2B),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Scrollbar(
                              controller: _topNavigationScrollController,
                              thumbVisibility: true,
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              child: SingleChildScrollView(
                                controller: _topNavigationScrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (profile.canViewManagerDashboard) ...[
                                      _buildScreenChip(
                                        1,
                                        'Manager Dashboard',
                                        Icons.dashboard,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildScreenChip(
                                        6,
                                        profile.isAdmin
                                            ? 'Manage Employees'
                                            : 'Employees',
                                        Icons.groups_outlined,
                                      ),
                                    ] else if (profile.isFloorWorker) ...[
                                      _buildScreenChip(
                                        0,
                                        'Factory Assistant',
                                        Icons.precision_manufacturing,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildScreenChip(
                                        5,
                                        'Alert Tracker',
                                        Icons.track_changes,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildScreenChip(
                                        4,
                                        'Live Stock',
                                        Icons.inventory_2,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildScreenChip(
                                        3,
                                        'QR Scanner',
                                        Icons.qr_code_scanner,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildScreenChip(
                                        2,
                                        'QA Center',
                                        Icons.fact_check,
                                      ),
                                    ] else if (profile.role == 'Quality Inspector')
                                      _buildScreenChip(
                                        2,
                                        'QA Center',
                                        Icons.fact_check,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Account options',
                            icon: const Icon(Icons.account_circle_outlined),
                            onSelected: (value) {
                              if (value == 'profile') _openProfile();
                              if (value == 'logout') _signOut();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'profile',
                                child: Text('View profile'),
                              ),
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel'),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Text('Log out'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: currentBody!),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScreenChip(int index, String label, IconData icon) {
    final isSelected = _currentScreenIndex == index && !_showExecutionLogModal;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.black : Colors.white70,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF1E2E42),
      onSelected: (selected) {
        if (!selected) return;
        setState(() {
          _showExecutionLogModal = false;
          _currentScreenIndex = index;
        });
      },
    );
  }
}
