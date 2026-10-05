import 'supplier_quotes_screen.dart';
import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';

class SupplierStatusScreen extends StatefulWidget {
  const SupplierStatusScreen({
    required this.service,
    this.showAppBar = true,
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;

  @override
  State<SupplierStatusScreen> createState() => _SupplierStatusScreenState();
}

class _SupplierStatusScreenState extends State<SupplierStatusScreen> {
  bool _loading = true;
  String? _error;
  List<SupplierSummary> _suppliers = [];
  SupplierAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.service.getSuppliers();
      final stats = await widget.service.getSupplierAnalytics();

      if (mounted) {
        setState(() {
          _suppliers = list;
          _analytics = stats;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const amberAccent = Color(0xFFFFB74D);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: navyBg,
              elevation: 0,
              title: const Text(
                'Supplier Status',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: _fetchSuppliers,
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: _fetchSuppliers,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? StateMessage(
                    message: _error!,
                    icon: Icons.cloud_off,
                    action: _fetchSuppliers,
                  )
                : RefreshIndicator(
                    onRefresh: _fetchSuppliers,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Analytics summary cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricTile(
                                  'Total Suppliers',
                                  '${_analytics?.totalSuppliers ?? _suppliers.length}',
                                  Colors.white,
                                  cardBg,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  'Active Vendors',
                                  '${_analytics?.activeSuppliers ?? _suppliers.where((s) => s.isActive).length}',
                                  const Color(0xFF10B981),
                                  cardBg,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  'Avg Rating',
                                  '${_analytics?.averageRating.toStringAsFixed(1) ?? '4.8'} ★',
                                  amberAccent,
                                  cardBg,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Approved Vendor Directory',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (_suppliers.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'No suppliers found.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _suppliers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final sup = _suppliers[idx];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                SupplierQuotesScreen(
                                                  supplierId: sup.id,
                                                ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.price_change),
                                        label: const Text('Material quotes'),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            sup.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: amberAccent.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: amberAccent,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  sup.rating.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: amberAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            sup.contactPerson.isNotEmpty
                                                ? sup.contactPerson
                                                : 'Primary Contact',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                            Icons.mail_outline,
                                            size: 14,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              sup.email,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Terms: ${sup.paymentTerms} • Lead Time: ${sup.leadTimeDays}d',
                                            style: const TextStyle(
                                              color: cyanAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sup.isActive
                                                  ? const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.15)
                                                  : amberAccent.withValues(
                                                      alpha: 0.15,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: sup.isActive
                                                    ? const Color(
                                                        0xFF10B981,
                                                      ).withValues(alpha: 0.3)
                                                    : amberAccent.withValues(
                                                        alpha: 0.3,
                                                      ),
                                              ),
                                            ),
                                            child: Text(
                                              sup.isActive
                                                  ? 'VERIFIED & ACTIVE'
                                                  : 'PENDING VERIFICATION',
                                              style: TextStyle(
                                                color: sup.isActive
                                                    ? const Color(0xFF10B981)
                                                    : amberAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!sup.isActive) ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _handleVerifySupplier(sup),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF10B981,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.verified_user_outlined,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Verify & Activate Supplier',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        backgroundColor: cyanAccent,
        foregroundColor: const Color(0xFF070E17),
        icon: const Icon(Icons.domain_add_rounded),
        label: const Text(
          'Add Supplier',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _handleVerifySupplier(SupplierSummary sup) async {
    try {
      await widget.service.verifySupplier(sup.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier ${sup.name} verified & activated!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchSuppliers();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final termsController = TextEditingController(text: 'Net30');
    final leadTimeController = TextEditingController(text: '5');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Row(
          children: [
            Icon(Icons.domain_add_rounded, color: Color(0xFF5CC8F8)),
            SizedBox(width: 8),
            Text(
              'Register New Supplier',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Company / Supplier Name',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contactController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contact Person Name',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contact Email',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Physical Address',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: termsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: leadTimeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Lead Time (Days)',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Register Supplier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await widget.service.createSupplier({
          'name': nameController.text.trim(),
          'contactEmail': emailController.text.trim().isNotEmpty
              ? emailController.text.trim()
              : 'contact@vendor.com',
          'contactPhone': phoneController.text.trim().isNotEmpty
              ? phoneController.text.trim()
              : '',
          'address': addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : 'Sector 4, Industrial Zone',
          'paymentTerms': termsController.text.trim().isNotEmpty
              ? termsController.text.trim()
              : 'Net30',
          'leadTimeDays': int.tryParse(leadTimeController.text.trim()) ?? 5,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier registered successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _fetchSuppliers();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add supplier: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildMetricTile(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
