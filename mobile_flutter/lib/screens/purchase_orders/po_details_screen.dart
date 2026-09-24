import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/po_status_stepper.dart';

class PODetailsScreen extends StatefulWidget {
  const PODetailsScreen({
    required this.service,
    required this.poId,
    super.key,
  });

  final PurchaseOrderService service;
  final int poId;

  @override
  State<PODetailsScreen> createState() => _PODetailsScreenState();
}

class _PODetailsScreenState extends State<PODetailsScreen> {
  bool _loading = true;
  String? _error;
  PurchaseOrderDetail? _po;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.getPurchaseOrderById(widget.poId);
      if (mounted) {
        setState(() {
          _po = data;
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

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: Text(
          _po?.poNumber ?? 'PO Details',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchDetails,
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
                  action: _fetchDetails,
                )
              : _po == null
                  ? const Center(child: Text('Order not found', style: TextStyle(color: Colors.white54)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Authority Notice Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_user_outlined, color: cyanAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Supply Chain Manager Read-Only Tracking. Formal approval signatures must be executed on the Web Manager Console.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Header Card: PO Number, Status, Supplier, Total
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _po!.poNumber,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Created ${_po!.createdAt.year}-${_po!.createdAt.month.toString().padLeft(2, '0')}-${_po!.createdAt.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_po!.status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getStatusColor(_po!.status).withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _po!.status,
                                        style: TextStyle(
                                          color: _getStatusColor(_po!.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMetaColumn('Supplier', _po!.supplierName, Icons.business_outlined),
                                    _buildMetaColumn('Total Cost', '\$${_po!.totalCost.toStringAsFixed(2)}', Icons.payments_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 10-Step Order Lifecycle Stepper
                          POStatusStepper(currentStep: _po!.currentLifecycleStep),

                          const SizedBox(height: 16),

                          // Status Breakdown Cards: Approval, Payment, Notification
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Telemetry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildStatusRow(
                                  title: 'Approval Status',
                                  value: _po!.approvalStatusDisplay,
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: const Color(0xFF10B981),
                                ),
                                const Divider(color: Colors.white10, height: 16),
                                _buildStatusRow(
                                  title: 'Payment Status',
                                  value: _po!.paymentStatusDisplay,
                                  icon: Icons.credit_card_outlined,
                                  iconColor: const Color(0xFF8B5CF6),
                                ),
                                const Divider(color: Colors.white10, height: 16),
                                _buildStatusRow(
                                  title: 'Supplier Notification',
                                  value: _po!.supplierNotificationDisplay,
                                  icon: Icons.send_outlined,
                                  iconColor: cyanAccent,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Order Lines (Material, Quantity, Unit Price, Total)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Order Lines',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${_po!.orderLines.length} items',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_po!.orderLines.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      'No item lines attached.',
                                      style: TextStyle(color: Colors.white38),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _po!.orderLines.length,
                                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 16),
                                    itemBuilder: (context, idx) {
                                      final line = _po!.orderLines[idx];
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: cyanAccent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.inventory_2_outlined, color: cyanAccent, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  line.rawMaterialName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'SKU: ${line.rawMaterialSku}',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${line.quantity} units @ \$${line.unitPrice.toStringAsFixed(2)} / unit',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '\$${line.totalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMetaColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'sent':
        return const Color(0xFF06B6D4);
      case 'pendingapproval':
        return const Color(0xFFF59E0B);
      case 'payment':
        return const Color(0xFF8B5CF6);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'draft':
      default:
        return const Color(0xFF64748B);
    }
  }
}
