import 'package:flutter/material.dart';
import 'package:mobile_flutter/controllers/inventory_controller.dart';

class TrackerAlertItem {
  final String packagingType;
  final String sku;
  final int quantity;
  final String timestamp;
  final String status;
  final bool isPending;
  final List<String> progressSteps;

  const TrackerAlertItem({
    required this.packagingType,
    required this.sku,
    required this.quantity,
    required this.timestamp,
    required this.status,
    required this.isPending,
    required this.progressSteps,
  });
}

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

  final List<TrackerAlertItem> _mockHistory = const [
    TrackerAlertItem(
      packagingType: 'Box Pouch',
      sku: 'RM-PLASTIC-502',
      quantity: 500,
      timestamp: 'Today, 08:15 AM',
      status: 'Pending Manager Approval',
      isPending: true,
      progressSteps: ['Alert Logged', 'AI Plan Generated', 'Awaiting Approval'],
    ),
    TrackerAlertItem(
      packagingType: 'Cardboard Box',
      sku: 'BX-CARD-901',
      quantity: 1200,
      timestamp: 'Yesterday, 03:40 PM',
      status: 'PO Dispatched',
      isPending: false,
      progressSteps: ['Data Extracted', 'PO Drafted', 'PO Dispatched'],
    ),
    TrackerAlertItem(
      packagingType: 'Plastic Drum',
      sku: 'DR-CHEM-33',
      quantity: 300,
      timestamp: 'Aug 18, 11:20 AM',
      status: 'Fulfilled',
      isPending: false,
      progressSteps: ['Alert Logged', 'Supplier Confirmed', 'Delivered'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBg = Color(0xFF121212);
    const cardBg = Color(0xFF1E1E1E);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // Build items list with dynamic submission from controller if present
        final List<TrackerAlertItem> alertItems = [
          if (widget.controller.sku.isNotEmpty)
            TrackerAlertItem(
              packagingType: widget.controller.packagingType.isNotEmpty
                  ? widget.controller.packagingType
                  : 'Box Pouch',
              sku: widget.controller.sku,
              quantity: widget.controller.quantityRequested,
              timestamp: 'Just now',
              status: widget.controller.successMessage != null
                  ? 'Pending Manager Approval'
                  : 'Submitted to AI',
              isPending: true,
              progressSteps: ['Alert Logged', 'AI Plan Generated', 'Awaiting Approval'],
            ),
          ..._mockHistory,
        ];

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

          // 3. Main body: ListView displaying history of submitted low-stock alerts
          body: ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: alertItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final alert = alertItems[index];
              return _buildAlertCard(alert: alert, cardBg: cardBg);
            },
          ),

          // 6. BottomNavigationBar with TRACKER tab (index 3) set as active, highlighted tab
          bottomNavigationBar: _buildBottomNavBar(),
        );
      },
    );
  }

  // 4. Dark card (0xFF1E1E1E) with packaging type & SKU, quantity, timestamp, status badge, and mini-timeline
  Widget _buildAlertCard({
    required TrackerAlertItem alert,
    required Color cardBg,
  }) {
    const yellowAccent = Color(0xFFFFD700);
    const greenAccent = Color(0xFF4CAF50);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.isPending
              ? yellowAccent.withAlpha(100)
              : Colors.white12,
          width: alert.isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: alert.isPending
                ? const Color(0x14FFD700)
                : const Color(0x0F000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Packaging Type & SKU + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.packagingType} - ${alert.sku}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alert.quantity} Units • ${alert.timestamp}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge with Yellow or Green outline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: alert.isPending
                      ? yellowAccent.withAlpha(25)
                      : greenAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.isPending ? yellowAccent : greenAccent,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  alert.status,
                  style: TextStyle(
                    color: alert.isPending ? yellowAccent : greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Mini-Timeline Row showing AI agent progress
          Row(
            children: [
              for (int i = 0; i < alert.progressSteps.length; i++) ...[
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: (alert.isPending && i == alert.progressSteps.length - 1)
                              ? yellowAccent.withAlpha(40)
                              : (alert.isPending ? yellowAccent : greenAccent),
                          shape: BoxShape.circle,
                          border: (alert.isPending && i == alert.progressSteps.length - 1)
                              ? Border.all(color: yellowAccent, width: 1.5)
                              : null,
                        ),
                        child: Icon(
                          (alert.isPending && i == alert.progressSteps.length - 1)
                              ? Icons.hourglass_empty
                              : Icons.check,
                          color: (alert.isPending && i == alert.progressSteps.length - 1)
                              ? yellowAccent
                              : Colors.black,
                          size: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alert.progressSteps[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (alert.isPending && i == alert.progressSteps.length - 1)
                                ? yellowAccent
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < alert.progressSteps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                  ),
              ],
            ],
          ),
        ],
      ),
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
