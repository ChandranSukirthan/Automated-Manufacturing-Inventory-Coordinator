import 'package:flutter/material.dart';
import '../controllers/inventory_controller.dart';
import 'scanner_view.dart'; // Added the scanner import!
// ignore: unused_import
import 'stock_view.dart';
import 'tracker_view.dart'; // Added the tracker import!

class FactoryAssistantView extends StatefulWidget {
  final InventoryController controller;
  final Function(int)? onTabSelected;

  const FactoryAssistantView({
    super.key,
    required this.controller,
    this.onTabSelected,
  });

  @override
  State<FactoryAssistantView> createState() => _FactoryAssistantViewState();
}

class _FactoryAssistantViewState extends State<FactoryAssistantView> {
  late final TextEditingController _skuController;
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
    _skuController = TextEditingController(text: widget.controller.sku);
    _skuController.addListener(() {
      if (_skuController.text != widget.controller.sku) {
        widget.controller.setSku(_skuController.text);
      }
    });
  }

  @override
  void dispose() {
    _skuController.dispose();
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
                            'LOW-STOCK ALERT',
                            style: TextStyle(
                              color: yellowAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Packaging Type Dropdown
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
                        initialValue: widget.controller.packagingType.isNotEmpty && _packagingOptions.contains(widget.controller.packagingType)
                            ? widget.controller.packagingType
                            : _packagingOptions.first,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF262626),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: yellowAccent),
                          ),
                        ),
                        items: _packagingOptions.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            widget.controller.setPackagingType(newValue);
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      // SKU Field
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
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'e.g. RM-PLASTIC-502',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF262626),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: yellowAccent),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

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
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                              icon: const Icon(Icons.remove, color: Colors.white70, size: 28),
                            ),
                            Text(
                              '${widget.controller.quantityRequested}',
                              style: const TextStyle(
                                color: yellowAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => widget.controller.incrementQuantity(50),
                              icon: const Icon(Icons.add, color: Colors.white70, size: 28),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
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
                                        backgroundColor: yellowAccent,
                                        content: Text(
                                          'Alert submitted to AI Coordinator!',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: widget.controller.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.smart_toy, 
                                      color: Colors.black,
                                      size: 22,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'SUBMIT TO AI COORDINATOR',
                                      style: TextStyle(
                                        fontSize: 14,
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
                        title: 'Pending Manager Approval',
                        subtitle: 'Awaiting response',
                        leadingIcon: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFD700),
                            shape: BoxShape.circle,
                            border: Border.all(color: yellowAccent.withAlpha(150), width: 1.5),
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

          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: Colors.white12, width: 1)),
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
                _buildNavItem(
                  index: 3,
                  icon: Icons.precision_manufacturing,
                  label: 'TRACKER',
                  isActive: _selectedNavIndex == 3,
                ),
              ],
            ),
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

        // 2. Navigate to the correct screen based on which tab was clicked!
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