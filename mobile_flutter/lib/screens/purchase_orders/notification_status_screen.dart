import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_create_screen.dart';
import 'procurement_details_screen.dart';

class NotificationStatusScreen extends StatefulWidget {
  const NotificationStatusScreen({
    required this.service,
    this.showAppBar = true,
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;

  @override
  State<NotificationStatusScreen> createState() =>
      _NotificationStatusScreenState();
}

class _NotificationStatusScreenState extends State<NotificationStatusScreen> {
  bool _loading = true;
  String? _error;
  List<PurchaseOrderSummary> _orders = [];
  List<StockAlertItem> _stockAlerts = [];

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
          _stockAlerts = alerts;
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
    const roseAccent = Color(0xFFEF4444);

    final sentCount = _orders
        .where((o) => o.status.toLowerCase() == 'sent')
        .length;
    final pendingCount = _orders
        .where(
          (o) =>
              o.status.toLowerCase() == 'pendingapproval' ||
              o.status.toLowerCase() == 'approved',
        )
        .length;
    final draftCount = _orders
        .where((o) => o.status.toLowerCase() == 'draft')
        .length;

    return Scaffold(
      backgroundColor: navyBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: navyBg,
              elevation: 0,
              title: const Text(
                'Notification Status',
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
                  onPressed: _fetchNotificationTelemetry,
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
                onPressed: _fetchNotificationTelemetry,
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

                          // ── Low Stock Detection Section ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: roseAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Low Stock Detection (${_stockAlerts.length})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _stockAlerts.isEmpty
                                    ? 'All Healthy'
                                    : 'Action Required',
                                style: TextStyle(
                                  color: _stockAlerts.isEmpty
                                      ? emeraldAccent
                                      : roseAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_stockAlerts.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'No critical stock breaches. All inventory items are within safety thresholds.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _stockAlerts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final alert = _stockAlerts[idx];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: roseAccent.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alert.materialName ?? alert.sku,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roseAccent.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: roseAccent.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              'LOW STOCK',
                                              style: TextStyle(
                                                color: roseAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Deficit: ${alert.quantityRequested} units • SKU: ${alert.sku}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _triggerAiProcurement(alert),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF3B82F6,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.auto_awesome,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'AI Procure',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _openManualPurchase(alert),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF10B981,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.shopping_cart,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'Manual Purchase',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () =>
                                                _handleMarkRead(alert.id),
                                            icon: const Icon(Icons.close),
                                            color: Colors.white54,
                                            iconSize: 20,
                                            tooltip: 'Dismiss',
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
                              child: const Center(
                                child: Text(
                                  'No notification history available.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _orders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final po = _orders[idx];
                                final isSent =
                                    po.status.toLowerCase() == 'sent';
                                final isApproved =
                                    po.status.toLowerCase() == 'approved';

                                Color badgeColor;
                                String statusText;
                                IconData badgeIcon;

                                if (isSent) {
                                  badgeColor = emeraldAccent;
                                  statusText = 'Sent to Supplier';
                                  badgeIcon =
                                      Icons.check_circle_outline_rounded;
                                } else if (isApproved) {
                                  badgeColor = cyanAccent;
                                  statusText =
                                      'Payment Succeeded • Email Queued';
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
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            badgeIcon,
                                            color: badgeColor,
                                            size: 16,
                                          ),
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
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    Color bg,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerAiProcurement(StockAlertItem alert) async {
    setState(() => _loading = true);
    try {
      final reqData = {
        'rawMaterialId': alert.rawMaterialId,
        'quantity': alert.quantityRequested > 0 ? alert.quantityRequested : 100,
      };
      final request = await widget.service.createProcurementRequest(reqData);
      await widget.service.startProcurementResearch(request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Procurement Workflow Started!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcurementDetailsScreen(
              service: widget.service,
              procurementId: request.id,
            ),
          ),
        ).then((_) => _fetchNotificationTelemetry());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Reorder failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openManualPurchase(StockAlertItem alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => POCreateScreen(
          service: widget.service,
          materialId: alert.rawMaterialId,
          sku: alert.sku,
          quantity: alert.quantityRequested > 0 ? alert.quantityRequested : 100,
        ),
      ),
    ).then((_) => _fetchNotificationTelemetry());
  }

  Future<void> _handleMarkRead(int alertId) async {
    try {
      await widget.service.markStockAlertAsRead(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert acknowledged and dismissed.'),
            backgroundColor: Color(0xFF5CC8F8),
          ),
        );
        _fetchNotificationTelemetry();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss alert: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
