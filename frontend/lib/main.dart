import 'package:flutter/material.dart';
import 'controllers/inventory_controller.dart';
import 'views/factory_assistant_view.dart';
import 'views/manager_dashboard_view.dart';
import 'views/agentic_execution_log_view.dart';
import 'views/qa_control_center_view.dart';
import 'views/scanner_view.dart';
import 'views/stock_view.dart';
import 'views/tracker_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final InventoryController _inventoryController;
  int _currentScreenIndex = 0;
  bool _showExecutionLogModal = false;

  @override
  void initState() {
    super.initState();
    _inventoryController = InventoryController();
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBackground = Color(0xFF121212);
    const darkSurface = Color(0xFF1E1E1E);

    Widget currentBody;

    if (_showExecutionLogModal) {
      currentBody = AgenticExecutionLogView(
        onClose: () {
          setState(() {
            _showExecutionLogModal = false;
          });
        },
      );
    } else {
      switch (_currentScreenIndex) {
        case 0:
          currentBody = FactoryAssistantView(
            controller: _inventoryController,
            onTabSelected: (index) {
              if (index == 1) {
                // Open ScannerView
                setState(() {
                  _currentScreenIndex = 3;
                });
              } else if (index == 2) {
                // Open StockView
                setState(() {
                  _currentScreenIndex = 4;
                });
              } else if (index == 3) {
                // Open TrackerView
                setState(() {
                  _currentScreenIndex = 5;
                });
              }
            },
          );
          break;
        case 1:
          currentBody = ManagerDashboardView(
            onOpenExecutionLog: () {
              setState(() {
                _showExecutionLogModal = true;
              });
            },
            onTabSelected: (index) {
              if (index == 0) {
                setState(() {
                  _currentScreenIndex = 1;
                });
              }
            },
          );
          break;
        case 2:
          currentBody = QaControlCenterView(
            onTabSelected: (index) {
              if (index == 0) {
                setState(() {
                  _currentScreenIndex = 0;
                });
              }
            },
          );
          break;
        case 3:
          currentBody = ScannerView(
            controller: _inventoryController,
            onBack: () {
              setState(() {
                _currentScreenIndex = 0;
              });
            },
          );
          break;
        case 4:
          currentBody = StockView(
            controller: _inventoryController,
            onBack: () {
              setState(() {
                _currentScreenIndex = 0;
              });
            },
          );
          break;
        case 5:
          currentBody = TrackerView(
            controller: _inventoryController,
            onBack: () {
              setState(() {
                _currentScreenIndex = 0;
              });
            },
            onTabSelected: (index) {
              if (index == 0) {
                setState(() {
                  _currentScreenIndex = 0;
                });
              } else if (index == 1) {
                setState(() {
                  _currentScreenIndex = 3;
                });
              } else if (index == 2) {
                setState(() {
                  _currentScreenIndex = 4;
                });
              } else if (index == 3) {
                setState(() {
                  _currentScreenIndex = 5;
                });
              }
            },
          );
          break;
        default:
          currentBody = FactoryAssistantView(controller: _inventoryController);
      }
    }

    return MaterialApp(
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
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Top Quick Screen Switcher Bar
              Container(
                color: const Color(0xFF0F1B2B),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScreenChip(0, 'Factory Assistant', Icons.precision_manufacturing),
                      const SizedBox(width: 6),
                      _buildScreenChip(5, 'Alert Tracker', Icons.track_changes),
                      const SizedBox(width: 6),
                      _buildScreenChip(4, 'Live Stock', Icons.inventory_2),
                      const SizedBox(width: 6),
                      _buildScreenChip(3, 'QR Scanner', Icons.qr_code_scanner),
                      const SizedBox(width: 6),
                      _buildScreenChip(1, 'Manager Dashboard', Icons.dashboard),
                      const SizedBox(width: 6),
                      _buildScreenChip(2, 'QA Center', Icons.fact_check),
                    ],
                  ),
                ),
              ),
              Expanded(child: currentBody),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenChip(int index, String label, IconData icon) {
    final isSelected = _currentScreenIndex == index && !_showExecutionLogModal;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white70),
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
        if (selected) {
          setState(() {
            _showExecutionLogModal = false;
            _currentScreenIndex = index;
          });
        }
      },
    );
  }
}
