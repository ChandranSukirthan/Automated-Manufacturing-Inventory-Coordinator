import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/inventory_controller.dart';
import '../models/user_profile.dart';
import '../utils/shift_helper.dart';
import 'profile_view.dart';

class FactoryAssistantView extends StatefulWidget {
  final InventoryController controller;
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileChanged;
  final VoidCallback onLogout;
  final VoidCallback? onManageEmployees;
  final Function(int)? onTabSelected;

  const FactoryAssistantView({
    super.key,
    required this.controller,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogout,
    this.onManageEmployees,
    this.onTabSelected,
  });

  @override
  State<FactoryAssistantView> createState() => _FactoryAssistantViewState();
}

class _FactoryAssistantViewState extends State<FactoryAssistantView> {
  late final TextEditingController _skuController;
  late final TextEditingController _quantityController;
  late final ScrollController _pageScrollController;
  Timer? _shiftRefreshTimer;
  int _selectedNavIndex = 0;

  final List<String> _packagingOptions = [
    'Box Pouch',
    'Poly Bag',
    'Cardboard Box',
    'Plastic Drum',
    'Custom Roll',
  ];

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.controller.sku);
    _quantityController = TextEditingController(
      text: widget.controller.quantityRequested.toString(),
    );
    _pageScrollController = ScrollController();
    _shiftRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _skuController.addListener(() {
      if (_skuController.text != widget.controller.sku) {
        widget.controller.setSku(_skuController.text);
      }
    });
  }

  @override
  void dispose() {
    _shiftRefreshTimer?.cancel();
    _pageScrollController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _syncQuantityField() {
    final quantityText = widget.controller.quantityRequested.toString();
    if (int.tryParse(_quantityController.text) == widget.controller.quantityRequested) {
      return;
    }

    _quantityController.value = TextEditingValue(
      text: quantityText,
      selection: TextSelection.collapsed(offset: quantityText.length),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileView(
          profile: widget.profile,
          onProfileChanged: widget.onProfileChanged,
          onManageEmployees: widget.onManageEmployees,
        ),
      ),
    );
  }

  String _formatWorkflowTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
        _syncQuantityField();

        return Scaffold(
          backgroundColor: darkBg,
          appBar: AppBar(
            backgroundColor: darkBg,
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FACTORY ASSISTANT',
                  style: TextStyle(
                    color: yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentShiftLabel(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Profile options',
                color: const Color(0xFF262626),
                onSelected: (value) {
                  if (value == 'profile') {
                    _openProfile();
                  } else if (value == 'logout') {
                    widget.onLogout();
                  }
                },
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1E2E42),
                  backgroundImage: widget.profile.profileImageBytes == null
                      ? null
                      : MemoryImage(widget.profile.profileImageBytes!),
                  child: widget.profile.profileImageBytes == null
                      ? Text(
                          widget.profile.initials.isEmpty
                              ? '?'
                              : widget.profile.initials,
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person_outline, color: Colors.white70),
                      title: Text('View profile', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.redAccent),
                      title: Text('Log out', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          // The visible scrollbar indicates that the full form can be scrolled.
          body: Scrollbar(
            controller: _pageScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _pageScrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Buttons
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'SCAN QR',
                  iconColor: yellowAccent,
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'REPORT LOW STOCK',
                  iconColor: yellowAccent,
                  onPressed: () {},
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
                        initialValue: _packagingOptions.contains(widget.controller.packagingType)
                            ? widget.controller.packagingType
                            : null,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        hint: const Text(
                          'Select a packaging type',
                          style: TextStyle(color: Colors.white38),
                        ),
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
                          hintText: 'Enter or scan SKU',
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
                              onPressed: widget.controller.quantityRequested > 1
                                  ? () => widget.controller.decrementQuantity()
                                  : null,
                              icon: const Icon(Icons.remove, color: Colors.white70, size: 28),
                            ),
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: yellowAccent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  final quantity = int.tryParse(value);
                                  if (quantity != null) {
                                    widget.controller.setQuantityRequested(quantity);
                                  }
                                },
                                onEditingComplete: _syncQuantityField,
                              ),
                            ),
                            IconButton(
                              onPressed: () => widget.controller.incrementQuantity(),
                              icon: const Icon(Icons.add, color: Colors.white70, size: 28),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. Submit Button: Yellow button with "SUBMIT TO AI COORDINATOR" and 'smart_toy' icon immediately to the left
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
                                  if (!mounted) return;

                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: success
                                          ? yellowAccent
                                          : Colors.redAccent,
                                      content: Text(
                                        success
                                            ? 'Alert submitted to AI Coordinator!'
                                            : widget.controller.errorMessage ??
                                                'Unable to submit the alert.',
                                        style: TextStyle(
                                          color: success ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
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
                                      Icons.smart_toy, // smart_toy robot icon
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

                // 3. Active Workflow Section Title with trending-up icon
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
                            Icons.trending_up, // Trending up icon
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
                      if (widget.controller.workflowStatus == null)
                        const Text(
                          'No low-stock alert has been submitted yet.',
                          style: TextStyle(color: Colors.white60),
                        )
                      else ...[
                        _buildTimelineStep(
                          title: 'Alert Logged',
                          subtitle: _formatWorkflowTime(
                            widget.controller.workflowStartedAt ?? DateTime.now(),
                          ),
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
                          subtitle: 'Request prepared for review',
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
                          title: widget.controller.workflowStatus!,
                          subtitle: widget.controller.workflowStatus == 'Pending Approval'
                              ? 'Waiting for manager review'
                              : widget.controller.workflowStatus == 'Approved'
                                  ? 'Manager approved the request'
                                  : widget.controller.workflowStatus == 'Rejected'
                                      ? 'Manager rejected the request'
                                      : 'Check the connection and submit again',
                          leadingIcon: widget.controller.workflowStatus == 'Pending Approval'
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: yellowAccent,
                                    strokeWidth: 2,
                                  ),
                                )
                              : widget.controller.workflowStatus == 'Approved'
                                  ? Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.black,
                                        size: 14,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                          titleColor: widget.controller.workflowStatus == 'Pending Approval'
                              ? yellowAccent
                              : widget.controller.workflowStatus == 'Approved'
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                          showConnectingLine: false,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
          ),

          // 5. Bottom Navigation Bar on Scaffold with dark background & 4 specified items
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
              if (widget.onTabSelected != null) {
                widget.onTabSelected!(index);
              }
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'DASHBOARD',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'SCANNER',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'STOCK',
              ),
              const BottomNavigationBarItem(
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
          // Icon and thin vertical grey line column
          Column(
            children: [
              leadingIcon,
              if (showConnectingLine)
                Expanded(
                  child: Container(
                    width: 2, // Thin grey line
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white24,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content Column
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
