import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';

class NotificationStatusScreen extends StatefulWidget {
  const NotificationStatusScreen({
    required this.service,
    super.key,
  });

  final PurchaseOrderService service;

  @override
  State<NotificationStatusScreen> createState() => _NotificationStatusScreenState();
}

class _NotificationStatusScreenState extends State<NotificationStatusScreen> {
  bool _loading = true;
  String? _error;
  List<PurchaseOrderSummary> _orders = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchNotificationTelemetry();
  }

  Future<void> _fetchNotificationTelemetry() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.getPurchaseOrders();
      final alerts = await widget.service.getStockAlerts();
      if (mounted) {
        setState(() {
          _orders = data;
          _alerts = alerts;
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
    const emeraldAccent = Color(0xFF10B981);
    const amberAccent = Color(0xFFFFB74D);

    final sentCount = _orders.where((o) => o.status.toLowerCase() == 'sent').length;
    final pendingCount = _orders.where((o) => o.status.toLowerCase() == 'pendingapproval' || o.status.toLowerCase() == 'approved').length;
    final draftCount = _orders.where((o) => o.status.toLowerCase() == 'draft').length;

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: const Text(
          'Notification Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchNotificationTelemetry,
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
                  action: _fetchNotificationTelemetry,
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotificationTelemetry,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Telemetry Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                'Dispatched',
                                '$sentCount',
                                emeraldAccent,
                                cardBg,
                                Icons.mark_email_read_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                'In Pipeline',
                                '$pendingCount',
                                amberAccent,
                                cardBg,
                                Icons.hourglass_top_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                'Unsent Drafts',
                                '$draftCount',
                                Colors.white60,
                                cardBg,
                                Icons.drafts_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Low Stock Alerts Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Low Stock Alerts',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: amberAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_alerts.length} ALERTS',
                                style: TextStyle(color: amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_alerts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'No low stock alerts recorded.',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _alerts.length > 5 ? 5 : _alerts.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final alert = _alerts[idx];
                              final material = alert['materialName']?.toString() ?? alert['sku']?.toString() ?? 'Material Alert';
                              final deficit = (alert['netDeficit'] ?? alert['shortage'] ?? alert['quantityRequested'] ?? 0).toString();
                              final status = alert['status']?.toString() ?? 'Active';
                              final time = alert['timestamp']?.toString() ?? alert['createdAt']?.toString() ?? '';
                              final timeStr = time.length >= 16 ? time.substring(0, 16).replaceAll('T', ' ') : time;
                              final severity = (alert['severity'] ?? alert['priority'] ?? 'Normal').toString().toUpperCase();
                              final isHigh = severity == 'HIGH' || severity == 'CRITICAL';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isHigh ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isHigh ? Icons.warning_amber_rounded : Icons.notifications_outlined,
                                              size: 16,
                                              color: isHigh ? const Color(0xFFEF4444) : cyanAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              material,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isHigh ? const Color(0x33EF4444) : const Color(0x3310B981),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            severity,
                                            style: TextStyle(
                                              color: isHigh ? const Color(0xFFEF4444) : emeraldAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Deficit: $deficit units',
                                          style: TextStyle(
                                            color: isHigh ? const Color(0xFFFFD700) : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Status: $status',
                                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                                        ),
                                        if (timeStr.isNotEmpty)
                                          Text(
                                            timeStr,
                                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        const Text(
                          'Supplier Notification Outbox',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_orders.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'No notification history available.',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _fetchNotificationTelemetry,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cyanAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Tap to Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _orders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final po = _orders[idx];
                              final isSent = po.status.toLowerCase() == 'sent';
                              final isApproved = po.status.toLowerCase() == 'approved';

                              Color badgeColor;
                              String statusText;
                              IconData badgeIcon;

                              if (isSent) {
                                badgeColor = emeraldAccent;
                                statusText = 'Sent to Supplier';
                                badgeIcon = Icons.check_circle_outline_rounded;
                              } else if (isApproved) {
                                badgeColor = cyanAccent;
                                statusText = 'Payment Succeeded • Email Queued';
                                badgeIcon = Icons.sync_rounded;
                              } else {
                                badgeColor = Colors.white38;
                                statusText = 'Waiting Approval';
                                badgeIcon = Icons.schedule_rounded;
                              }

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
                                          po.poNumber,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '\$${po.totalCost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      po.supplierName,
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(badgeIcon, color: badgeColor, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: badgeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'PDF Generated',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: 10,
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

  Widget _buildMetricTile(String label, String value, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
