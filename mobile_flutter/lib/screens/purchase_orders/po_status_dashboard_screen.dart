import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';
import 'po_list_screen.dart';
import 'ai_workflow_status_screen.dart';
import 'supplier_status_screen.dart';
import 'notification_status_screen.dart';

class POStatusDashboardScreen extends StatefulWidget {
  const POStatusDashboardScreen({
    required this.service,
    super.key,
  });

  final PurchaseOrderService service;

  @override
  State<POStatusDashboardScreen> createState() => _POStatusDashboardScreenState();
}

class _POStatusDashboardScreenState extends State<POStatusDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<PurchaseOrderSummary> _orders = [];
  List<AgentWorkflowItem> _workflows = [];
  SupplierAnalytics? _supplierAnalytics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await widget.service.getPurchaseOrders();
      final workflows = await widget.service.getAgentWorkflows();
      final analytics = await widget.service.getSupplierAnalytics();

      if (mounted) {
        setState(() {
          _orders = orders;
          _workflows = workflows;
          _supplierAnalytics = analytics;
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
    const emeraldAccent = Color(0xFF10B981);

    if (_loading && _orders.isEmpty) {
      return const Scaffold(
        backgroundColor: navyBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _orders.isEmpty) {
      return Scaffold(
        backgroundColor: navyBg,
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _loadData,
        ),
      );
    }

    final totalOrders = _orders.length;
    final pendingOrders = _orders.where((o) => o.status.toLowerCase() == 'pendingapproval').length;
    final approvedOrders = _orders.where((o) =>
        o.status.toLowerCase() == 'approved' ||
        o.status.toLowerCase() == 'sent' ||
        o.status.toLowerCase() == 'payment').length;
    final totalSpend = _orders.fold<double>(0, (sum, o) => sum + o.totalCost);

    return Scaffold(
      backgroundColor: navyBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner: Web Console Authority
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: cyanAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mobile is optimized for live status tracking. Executive approvals are finalized on the Web Manager Console.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                    title: 'Total PO Value',
                    value: '\$${totalSpend >= 1000 ? (totalSpend / 1000).toStringAsFixed(1) : totalSpend.toStringAsFixed(0)}${totalSpend >= 1000 ? 'K' : ''}',
                    valueColor: Colors.white,
                    cardBg: cardBg,
                    subtitle: '$totalOrders POs total',
                  ),
                  _buildMetricCard(
                    title: 'Pending Approvals',
                    value: '$pendingOrders',
                    valueColor: amberAccent,
                    cardBg: cardBg,
                    subtitle: 'Requires Web approval',
                  ),
                  _buildMetricCard(
                    title: 'Approved / Sent',
                    value: '$approvedOrders',
                    valueColor: emeraldAccent,
                    cardBg: cardBg,
                    subtitle: 'In procurement pipeline',
                  ),
                  _buildMetricCard(
                    title: 'Active Workflows',
                    value: '${_workflows.length}',
                    valueColor: cyanAccent,
                    cardBg: cardBg,
                    subtitle: _supplierAnalytics != null
                        ? '${_supplierAnalytics!.activeSuppliers} vendors active'
                        : 'Multi-agent tracking',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Module Quick Navigation Hub
              const Text(
                'Procurement Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNavButton(
                      icon: Icons.assignment_outlined,
                      label: 'PO Catalog',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => POListScreen(service: widget.service),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNavButton(
                      icon: Icons.psychology_outlined,
                      label: 'AI Workflows',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AIWorkflowStatusScreen(service: widget.service),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildNavButton(
                      icon: Icons.business_outlined,
                      label: 'Suppliers',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierStatusScreen(service: widget.service),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNavButton(
                      icon: Icons.notifications_active_outlined,
                      label: 'Notifications',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationStatusScreen(service: widget.service),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Orders Watchlist
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Purchase Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => POListScreen(service: widget.service),
                      ),
                    ),
                    child: const Text('View All', style: TextStyle(color: cyanAccent, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_orders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'No Purchase Orders found.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orders.take(5).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final po = _orders[idx];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PODetailsScreen(
                            service: widget.service,
                            poId: po.id,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: po.statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: po.statusColor.withOpacity(0.3)),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: po.statusColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    po.poNumber,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    po.supplierName,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${po.totalCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: po.statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    po.status,
                                    style: TextStyle(
                                      color: po.statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required Color cardBg,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5CC8F8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
