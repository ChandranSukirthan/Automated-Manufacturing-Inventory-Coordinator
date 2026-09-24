import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';

class SupplierStatusScreen extends StatefulWidget {
  const SupplierStatusScreen({
    required this.service,
    super.key,
  });

  final PurchaseOrderService service;

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
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: const Text(
          'Supplier Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchSuppliers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
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
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final sup = _suppliers[idx];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: amberAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star, color: amberAccent, size: 12),
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
                                        const Icon(Icons.person_outline, size: 14, color: Colors.white38),
                                        const SizedBox(width: 6),
                                        Text(
                                          sup.contactPerson.isNotEmpty ? sup.contactPerson : 'Primary Contact',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.mail_outline, size: 14, color: Colors.white38),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            sup.email,
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Terms: ${sup.paymentTerms}',
                                          style: const TextStyle(color: cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          sup.isActive ? 'Active Vendor' : 'Inactive',
                                          style: TextStyle(
                                            color: sup.isActive ? const Color(0xFF10B981) : Colors.white38,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
