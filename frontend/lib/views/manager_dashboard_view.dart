import 'package:flutter/material.dart';

class ManagerDashboardView extends StatefulWidget {
  final VoidCallback? onOpenExecutionLog;
  final Function(int)? onTabSelected;

  const ManagerDashboardView({
    super.key,
    this.onOpenExecutionLog,
    this.onTabSelected,
  });

  @override
  State<ManagerDashboardView> createState() => _ManagerDashboardViewState();
}

class _ManagerDashboardViewState extends State<ManagerDashboardView> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const amberAccent = Color(0xFFFFB74D);
    const coralAccent = Color(0xFFFF7043);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Color(0xFF1E2E42),
            child: Icon(Icons.person, color: Colors.white70, size: 20),
          ),
        ),
        title: const Text(
          'Manufacturing\nInventory\nCoordinator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 26),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2x2 Metric Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildMetricCard(
                  title: 'Total Material Value',
                  value: '\$1.2M',
                  valueColor: Colors.white,
                  cardBg: cardBg,
                ),
                _buildMetricCard(
                  title: 'Pending POs',
                  value: '12',
                  valueColor: amberAccent,
                  cardBg: cardBg,
                ),
                _buildMetricCard(
                  title: 'Quarantined Lots',
                  value: '3',
                  valueColor: coralAccent,
                  cardBg: cardBg,
                ),
                _buildMetricCard(
                  title: 'Machine Uptime',
                  value: '98.4%',
                  valueColor: cyanAccent,
                  cardBg: cardBg,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // AI Action Required Section
            Row(
              children: const [
                Icon(Icons.memory_rounded, color: cyanAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'AI Action Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Item Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4D5CC8F8), width: 1.5),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '#WF-8902',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Raw Polyethylene\nFilm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF7043),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x66FF7043)),
                        ),
                        child: const Text(
                          'EXCEEDS\nTHRESHOLD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: coralAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Apex Polymers • 3 Days SLA',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cyanAccent,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: widget.onOpenExecutionLog,
                            child: const Text(
                              'Approve & Execute',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0x33FF7043),
                              side: const BorderSide(color: coralAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {},
                            child: const Text(
                              'Reject',
                              style: TextStyle(
                                color: coralAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Live Inventory Status Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Inventory\nStatus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      Container(
                        width: 170,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF070E17),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: const [
                            Icon(Icons.search, color: Colors.white38, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Search materials...',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Table Header
                  Row(
                    children: const [
                      Expanded(
                        flex: 3,
                        child: Text('Material', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('SKU', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Stock Level', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Status', textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  // Table Row 1
                  Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Polyethylene\nFilm',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'SKU-\nPE-\n01',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.15,
                                  backgroundColor: Colors.white12,
                                  color: amberAccent,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('15%', style: TextStyle(color: amberAccent, fontSize: 11)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x26FFB74D),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0x4DFFB74D)),
                            ),
                            child: const Text(
                              'LOW\nSTOCK',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomItem(0, Icons.grid_view_rounded, 'Dashboard'),
            _buildBottomItem(1, Icons.inventory_2_outlined, 'Inventory'),
            _buildBottomItem(2, Icons.receipt_long_outlined, 'Orders'),
            _buildBottomItem(3, Icons.smart_toy_outlined, 'Agents'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required Color cardBg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomItem(int index, IconData icon, String label) {
    const cyanAccent = Color(0xFF5CC8F8);
    final isSelected = _selectedNavIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        if (widget.onTabSelected != null) {
          widget.onTabSelected!(index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? cyanAccent : Colors.white54, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? cyanAccent : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
