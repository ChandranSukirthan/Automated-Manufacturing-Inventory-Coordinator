import 'package:flutter/material.dart';
import 'package:mobile_flutter/controllers/inventory_controller.dart';

class TrackerView extends StatefulWidget {
  final InventoryController controller;
  final VoidCallback? onBack;
  final Function(int)? onTabSelected;

  const TrackerView({
    super.key,
    required this.controller,
    this.onBack,
    this.onTabSelected,
  });

  @override
  State<TrackerView> createState() => _TrackerViewState();
}

class _TrackerViewState extends State<TrackerView> {
  int _selectedNavIndex = 3; // Index 3: TRACKER active

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBg = Color(0xFF121212);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Scaffold(
          // 1. Scaffold background must be dark (0xFF121212)
          backgroundColor: darkBg,

          // 2. AppBar: Bold yellow title "ALERT TRACKER", transparent background, white back button
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
            centerTitle: true,
            title: const Text(
              'ALERT TRACKER',
              style: TextStyle(
                color: yellowAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
          ),

          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No real low-stock alerts have been submitted for this account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ),

          // 6. BottomNavigationBar with TRACKER tab (index 3) set as active, highlighted tab
          bottomNavigationBar: _buildBottomNavBar(),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.grid_view_rounded,
            label: 'DASHBOARD',
            isActive: _selectedNavIndex == 0,
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.qr_code_scanner,
            label: 'SCANNER',
            isActive: _selectedNavIndex == 1,
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.inventory_2_outlined,
            label: 'STOCK',
            isActive: _selectedNavIndex == 2,
          ),
          // TRACKER (index 3) active highlighted tab
          _buildNavItem(
            index: 3,
            icon: Icons.precision_manufacturing,
            label: 'TRACKER',
            isActive: _selectedNavIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    const yellowAccent = Color(0xFFFFD700);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        if (widget.onTabSelected != null) {
          widget.onTabSelected!(index);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? yellowAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.black : Colors.white60,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white60,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
