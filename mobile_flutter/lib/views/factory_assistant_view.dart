import 'package:flutter/material.dart';
import '../controllers/inventory_controller.dart';
import '../services/purchase_order_service.dart';
import '../screens/purchase_orders/procurement_details_screen.dart';
import 'scanner_view.dart'; // Added the scanner import!
// ignore: unused_import
import 'stock_view.dart';
import 'tracker_view.dart'; // Added the tracker import!

class FactoryAssistantView extends StatefulWidget {
  final InventoryController controller;
  final Function(int)? onTabSelected;
  final PurchaseOrderService? poService;

  const FactoryAssistantView({
    super.key,
    required this.controller,
    this.onTabSelected,
    this.poService,
  });

  @override
  State<FactoryAssistantView> createState() => _FactoryAssistantViewState();
}

class _FactoryAssistantViewState extends State<FactoryAssistantView> {
  late final TextEditingController _materialController;
  late final TextEditingController _skuController;
  late final TextEditingController _currentStockController;
  late final TextEditingController _minStockController;
  int _selectedNavIndex = 0;

  // Updated to match your exact C# Database Enums!
  final List<String> _packagingOptions = [
    'BoxPouch',
    'BiscuitPackaging',
    'TeaBag',
    'Bag',
    'Can',
    'Bottle',
  ];

  @override
  void initState() {
    super.initState();
    _materialController = TextEditingController(text: widget.controller.materialName);
    _skuController = TextEditingController(text: widget.controller.sku);
    _currentStockController = TextEditingController(text: widget.controller.currentStock.toStringAsFixed(0));
    _minStockController = TextEditingController(text: widget.controller.minimumStock.toStringAsFixed(0));

    _materialController.addListener(() {
      if (_materialController.text != widget.controller.materialName) {
        widget.controller.setMaterialName(_materialController.text);
      }
    });
    _skuController.addListener(() {
      if (_skuController.text != widget.controller.sku) {
        widget.controller.setSku(_skuController.text);
      }
    });
    _currentStockController.addListener(() {
      final parsed = double.tryParse(_currentStockController.text);
      if (parsed != null && parsed != widget.controller.currentStock) {
        widget.controller.setCurrentStock(parsed);
      }
    });
    _minStockController.addListener(() {
      final parsed = double.tryParse(_minStockController.text);
      if (parsed != null && parsed != widget.controller.minimumStock) {
        widget.controller.setMinimumStock(parsed);
      }
    });
  }

  @override
  void dispose() {
    _materialController.dispose();
    _skuController.dispose();
    _currentStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBg = Color(0xFF121212);
    const cardBg = Color(0xFF1E1E1E);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (_skuController.text != widget.controller.sku) {
          _skuController.text = widget.controller.sku;
        }

        return Scaffold(
          backgroundColor: darkBg,
          appBar: AppBar(
            backgroundColor: darkBg,
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'FACTORY ASSISTANT',
                  style: TextStyle(
                    color: yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Morning Shift - Line 03',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white70, size: 28),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Buttons
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'SCAN QR',
                  iconColor: yellowAccent,
                  onPressed: () {
                    // Added the navigation logic here!
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ScannerView(controller: widget.controller)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'REPORT LOW STOCK',
                  iconColor: yellowAccent,
                  onPressed: () {
                    // Tell the user to use the form right below!
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: cardBg,
                        content: Text(
                          'Please fill out the Low-Stock Alert form below.',
                          style: TextStyle(color: yellowAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'LOG DEFECT',
                  iconColor: const Color(0xFFFF5252),
                  onPressed: () {
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(3);
                    }

                    // Placeholder for Student C's Defect Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFFFF5252),
                        content: Text(
                          'Routing to Quality Inspector Portal...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );

                  },
                ),

                const SizedBox(height: 24),

                // LOW-STOCK ALERT Section
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_rounded, color: yellowAccent, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'REPORT LOW RAW MATERIAL STOCK',
                            style: TextStyle(
                              color: yellowAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Material Name Field
                      const Text(
                        'MATERIAL NAME',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _materialController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Food Grade BOPP Film',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF262626),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellowAccent)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // SKU & Packaging Type Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SKU',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _skuController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'RM-PLASTIC-502',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: const Color(0xFF262626),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellowAccent)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PACKAGING TYPE',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: widget.controller.packagingType.isNotEmpty && _packagingOptions.contains(widget.controller.packagingType)
                                      ? widget.controller.packagingType
                                      : _packagingOptions.first,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF262626),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellowAccent)),
                                  ),
                                  items: _packagingOptions.map((type) => DropdownMenuItem(value: type, child: Text(type, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (val) {
                                    if (val != null) widget.controller.setPackagingType(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Current Stock & Minimum Stock Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CURRENT STOCK',
                                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _currentStockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF262626),
                                    suffixText: 'units',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellowAccent)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MINIMUM STOCK',
                                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _minStockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF262626),
                                    suffixText: 'units',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellowAccent)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Shortage Metric Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.controller.shortage > 0
                              ? const Color(0x28EF4444)
                              : const Color(0x2810B981),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.controller.shortage > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  widget.controller.shortage > 0
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline,
                                  size: 18,
                                  color: widget.controller.shortage > 0
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'SHORTAGE DEFICIT',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${widget.controller.shortage.toStringAsFixed(0)} units',
                              style: TextStyle(
                                color: widget.controller.shortage > 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quantity Requested Row
                      const Text(
                        'QUANTITY REQUESTED',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => widget.controller.decrementQuantity(50),
                              icon: const Icon(Icons.remove, color: Colors.white70, size: 24),
                            ),
                            Text(
                              '${widget.controller.quantityRequested}',
                              style: const TextStyle(
                                color: yellowAccent,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => widget.controller.incrementQuantity(50),
                              icon: const Icon(Icons.add, color: Colors.white70, size: 24),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Submit Low Stock Alert Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: yellowAccent,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: widget.controller.isLoading
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final success = await widget.controller.submitLowStockAlert();
                                  if (mounted && success) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF10B981),
                                        content: Text(
                                          'Low Stock Alert Submitted • Procurement Started',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: widget.controller.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.send_rounded, color: Colors.black, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'SUBMIT LOW STOCK ALERT',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // AFTER SUBMIT: Procurement Started & Workflow Details
                if (widget.controller.procurementStarted) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1B2B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF5CC8F8).withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5CC8F8).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Procurement Started',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5CC8F8).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF5CC8F8).withOpacity(0.4)),
                              ),
                              child: Text(
                                widget.controller.currentStatus ?? 'AI RESEARCHING',
                                style: const TextStyle(
                                  color: Color(0xFF5CC8F8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Workflow ID', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                              widget.controller.workflowId ?? 'WF-PROC-101',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Status', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                              widget.controller.currentStatus ?? 'Procurement Started',
                              style: const TextStyle(color: Color(0xFF5CC8F8), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5CC8F8),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              if (widget.poService != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProcurementDetailsScreen(
                                      service: widget.poService!,
                                      procurementId: widget.controller.activeProcurementId,
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.timeline_rounded, size: 18),
                            label: const Text(
                              'Track Procurement Pipeline (11 Stages)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 24),

                // Active Workflow Section
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.trending_up, 
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ACTIVE WORKFLOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildTimelineStep(
                        title: 'Alert Logged',
                        subtitle: '08:15 AM',
                        leadingIcon: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: yellowAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        ),
                        titleColor: Colors.white,
                        showConnectingLine: true,
                      ),

                      _buildTimelineStep(
                        title: 'AI Plan Generated',
                        subtitle: '08:16 AM',
                        leadingIcon: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: yellowAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        ),
                        titleColor: Colors.white,
                        showConnectingLine: true,
                      ),

                      _buildTimelineStep(
                        title: 'Pending Approval...',
                        subtitle: 'Waiting for manager review',
                        leadingIcon: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: yellowAccent,
                            strokeWidth: 2,
                          ),
                        ),
                        titleColor: yellowAccent, 
                        showConnectingLine: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: cardBg,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedNavIndex,
            selectedItemColor: yellowAccent,
            unselectedItemColor: Colors.white60,
            onTap: (index) {
              setState(() {
                _selectedNavIndex = index;
              });

              if (index == 1) { // SCANNER TAB
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScannerView(controller: widget.controller),
                  ),
                );
              } else if (index == 2) { // STOCK TAB
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StockView(controller: widget.controller),
                  ),
                );
              } else if (index == 3) { // TRACKER TAB
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackerView(controller: widget.controller),
                  ),
                );
              } else if (widget.onTabSelected != null) {
                widget.onTabSelected!(index);
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'DASHBOARD',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'SCANNER',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'STOCK',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.precision_manufacturing),
                label: 'TRACKER',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required Widget leadingIcon,
    required Color titleColor,
    required bool showConnectingLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              leadingIcon,
              if (showConnectingLine)
                Expanded(
                  child: Container(
                    width: 2, 
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white24,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}