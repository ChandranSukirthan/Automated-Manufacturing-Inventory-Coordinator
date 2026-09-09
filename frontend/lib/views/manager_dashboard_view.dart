import 'dart:convert';
import 'package:http/http.dart' as http;
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
  bool _isLoading = true;
  List<dynamic> _inventoryItems = [];
  List<dynamic> _alerts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invResponse = await http.get(Uri.parse('http://localhost:5158/api/Inventory'));
      final alertsResponse = await http.get(Uri.parse('http://localhost:5158/api/Inventory/alerts'));

      if (invResponse.statusCode == 200 && alertsResponse.statusCode == 200) {
        setState(() {
          _inventoryItems = json.decode(invResponse.body);
          _alerts = json.decode(alertsResponse.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateAlertStatus(int id, String status) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:5158/api/Inventory/alerts/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Alert marked as $status!'), backgroundColor: Colors.green),
          );
        }
        _fetchData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAgentPlanDialog(Map<String, dynamic> alert) {
    // Generate pseudo-dynamic values based on the alert
    final int quantity = alert['quantityRequested'] ?? 0;
    final double cost = quantity * 1.85;
    final String supplier = 'Apex Polymers';
    final String leadTime = '3 Days';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: const [
              Icon(Icons.smart_toy, color: Color(0xFF5CC8F8)),
              SizedBox(width: 8),
              Text('LangGraph Execution Plan', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Agent Steps:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildAgentStep('1. Data Extraction', 'Extracted SKU and quantity needs.', true),
                _buildAgentStep('2. Planner', 'Evaluated vendor SLAs and prices.', true),
                _buildAgentStep('3. PO Drafter', 'Drafted PO for $quantity units.', true),
                _buildAgentStep('4. Manager Approval', 'Awaiting your confirmation.', false),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),
                _buildPlanDetailRow('Selected Supplier:', supplier),
                _buildPlanDetailRow('Calculated Total Cost:', '\$${cost.toStringAsFixed(2)}'),
                _buildPlanDetailRow('Estimated Lead Time:', leadTime),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5CC8F8)),
              onPressed: () {
                Navigator.pop(context);
                _updateAlertStatus(alert['id'], 'Approved');
              },
              child: const Text('Confirm & Dispatch PO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAgentStep(String title, String subtitle, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, 
               color: isCompleted ? const Color(0xFF4CAF50) : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isCompleted ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

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

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: cyanAccent))
            else if (_alerts.where((a) => a['status'] == 'Pending' || a['status'] == 'Scanned').isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No AI actions required at this time.', style: TextStyle(color: Colors.white54)),
              )
            else
              ..._alerts.where((a) => a['status'] == 'Pending' || a['status'] == 'Scanned').map((alert) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#WF-${alert['id']}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${alert['packagingType']}\n(SKU: ${alert['sku']})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF7043),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x66FF7043)),
                              ),
                              child: const Text(
                                'ACTION\nREQUIRED',
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
                        Text(
                          'Requested: ${alert['quantityRequested']} units • By: ${alert['workerId']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                                  onPressed: () => _showAgentPlanDialog(alert),
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
                                  onPressed: () => _updateAlertStatus(alert['id'], 'Rejected'),
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
                );
              }).toList(),

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
                      SizedBox(
                        width: 170,
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search materials...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                            filled: true,
                            fillColor: const Color(0xFF070E17),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: cyanAccent),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
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
                  
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: cyanAccent)))
                  else if (_inventoryItems.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No inventory data found.', style: TextStyle(color: Colors.white54))))
                  else
                    ..._inventoryItems.where((item) {
                      if (_searchQuery.isEmpty) return true;
                      final name = (item['name'] ?? '').toString().toLowerCase();
                      final sku = (item['sku'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || sku.contains(_searchQuery);
                    }).map((item) {
                      final int stockLevel = item['stockLevel'] ?? 0;
                      final int threshold = item['reorderThreshold'] ?? 0;
                      final bool isLowStock = threshold > 0 && stockLevel <= threshold;
                      
                      final double ratio = threshold > 0 ? stockLevel / (threshold * 3.0) : 1.0;
                      final progressValue = ratio.clamp(0.0, 1.0);

                      String rawCategory = item['category'] ?? 'Units';
                      String formattedUnit = rawCategory;
                      if (rawCategory.isNotEmpty) {
                        formattedUnit = rawCategory[0].toUpperCase() + rawCategory.substring(1).toLowerCase();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${item['name'] ?? 'Unknown'}\n($formattedUnit)',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item['sku'] ?? 'N/A',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                                        value: progressValue,
                                        backgroundColor: Colors.white12,
                                        color: isLowStock ? amberAccent : cyanAccent,
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('$stockLevel', style: TextStyle(color: isLowStock ? amberAccent : cyanAccent, fontSize: 11)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: isLowStock
                                    ? Container(
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
                                      )
                                    : const Text(
                                        'HEALTHY',
                                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
