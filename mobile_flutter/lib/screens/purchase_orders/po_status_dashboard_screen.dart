import '../../utils/locale.dart';
import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';
import 'po_list_screen.dart';
import 'procurement_details_screen.dart';
import 'supplier_status_screen.dart';

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
  List<SupplierSummary> _suppliers = [];
  List<StockAlertItem> _stockAlerts = [];

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
      final suppliers = await widget.service.getSuppliers();
      final alerts = await widget.service.getStockAlerts();

      if (mounted) {
        setState(() {
          _orders = orders;
          _suppliers = suppliers;
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
    const amberAccent = Color(0xFFFFB74D);
    const emeraldAccent = Color(0xFF10B981);
    const roseAccent = Color(0xFFEF4444);

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

    // Calculations matching React Web AdminDashboard.jsx
    final totalOrders = _orders.length;
    final draftOrders = _orders.where((o) => o.status.toLowerCase() == 'draft').toList();
    final pendingOrders = _orders.where((o) => o.status.toLowerCase() == 'pendingapproval').toList();
    final approvedOrders = _orders.where((o) => o.status.toLowerCase() == 'approved').toList();
    final rejectedOrders = _orders.where((o) => o.status.toLowerCase() == 'rejected').toList();
    final revisionOrders = _orders.where((o) => o.status.toLowerCase() == 'revisionrequested').toList();
    final sentOrders = _orders.where((o) => o.status.toLowerCase() == 'sent').toList();

    final totalPurchaseValue = _orders.where((o) => o.currency.toUpperCase() == 'LKR').fold<double>(0, (sum, o) => sum + o.totalCost);
    final pendingApprovalAmount = pendingOrders.where((o) => o.currency.toUpperCase() == 'LKR').fold<double>(0, (sum, o) => sum + o.totalCost);
    final supplierCount = _suppliers.length;
    final activeSuppliersCount = _suppliers.where((s) => s.isActive).length;
    final supplierPerformance = supplierCount > 0 ? ((activeSuppliersCount / supplierCount) * 100).round() : 100;
    final lowStockCount = _stockAlerts.length;

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
              // ── 1. Top Executive Welcome Banner (Matching Web) ──
              _buildWelcomeBanner(cyanAccent, emeraldAccent),
              const SizedBox(height: 16),

              // ── 2. Primary Financial & Strategic KPI Cards (4 Cards Grid) ──
              _buildKpiGrid(
                cardBg: cardBg,
                cyanAccent: cyanAccent,
                amberAccent: amberAccent,
                emeraldAccent: emeraldAccent,
                roseAccent: roseAccent,
                totalPurchaseValue: totalPurchaseValue,
                totalOrders: totalOrders,
                pendingApprovalAmount: pendingApprovalAmount,
                pendingCount: pendingOrders.length,
                supplierCount: supplierCount,
                supplierPerformance: supplierPerformance,
                lowStockCount: lowStockCount,
              ),
              const SizedBox(height: 16),

              // ── 3. Operations & Quick Actions Hub Buttons ──
              _buildOperationsHub(cardBg, cyanAccent, emeraldAccent, amberAccent),
              const SizedBox(height: 16),

              // ── 4. PO Status Distribution Cockpit ──
              _buildStatusCockpit(
                cardBg: cardBg,
                totalOrders: totalOrders,
                draftCount: draftOrders.length,
                pendingCount: pendingOrders.length,
                approvedCount: approvedOrders.length,
                sentCount: sentOrders.length,
                revisionCount: revisionOrders.length,
                rejectedCount: rejectedOrders.length,
              ),
              const SizedBox(height: 16),

              // ── 5. Urgent Executive Approvals Queue ──
              _buildApprovalsQueue(cardBg, amberAccent, pendingOrders),
              const SizedBox(height: 16),

              // ── 6. Low Stock Replenishment Alerts ──
              if (_stockAlerts.isNotEmpty) ...[
                _buildLowStockAlertsCard(cardBg, roseAccent, cyanAccent),
                const SizedBox(height: 16),
              ],

              // ── 7. Recent Purchase Orders Activity ──
              _buildRecentOrdersTable(cardBg, cyanAccent, _orders),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Welcome Banner ──
  Widget _buildWelcomeBanner(Color cyanAccent, Color emeraldAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1E36), Color(0xFF0A1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF5CC8F8), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Supply Chain Command Center',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cyanAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MANAGER',
                            style: TextStyle(color: Color(0xFF5CC8F8), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Live stock replenishment, manager approvals & Stripe payments.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLivePill('Stripe Sandbox Ready', emeraldAccent),
                const SizedBox(width: 8),
                _buildLivePill('SendGrid Online', cyanAccent),
                const SizedBox(width: 8),
                _buildLivePill('AI Agent Active', const Color(0xFFA855F7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── KPI Grid ──
  Widget _buildKpiGrid({
    required Color cardBg,
    required Color cyanAccent,
    required Color amberAccent,
    required Color emeraldAccent,
    required Color roseAccent,
    required double totalPurchaseValue,
    required int totalOrders,
    required double pendingApprovalAmount,
    required int pendingCount,
    required int supplierCount,
    required int supplierPerformance,
    required int lowStockCount,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildKpiCard(
          title: 'Total Purchase Value',
          value: formatMoney(totalPurchaseValue),
          subtitle: '$totalOrders Total POs',
          icon: Icons.payments_outlined,
          color: cyanAccent,
          cardBg: cardBg,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => POListScreen(service: widget.service))),
        ),
        _buildKpiCard(
          title: 'Pending Approvals',
          value: formatMoney(pendingApprovalAmount),
          subtitle: '$pendingCount Orders Awaiting',
          icon: Icons.pending_actions_outlined,
          color: amberAccent,
          cardBg: cardBg,
          onTap: () => _openPendingApprovals(),
        ),
        _buildKpiCard(
          title: 'Supplier Ecosystem',
          value: '$supplierCount Vendors',
          subtitle: 'SLA Perf: $supplierPerformance%',
          icon: Icons.business_outlined,
          color: emeraldAccent,
          cardBg: cardBg,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierStatusScreen(service: widget.service))),
        ),
        _buildKpiCard(
          title: 'Low Stock Alerts',
          value: '$lowStockCount Items',
          subtitle: lowStockCount > 0 ? 'Replenish Required' : 'Healthy Inventory',
          icon: Icons.warning_amber_rounded,
          color: lowStockCount > 0 ? roseAccent : emeraldAccent,
          cardBg: cardBg,
          onTap: () => _showLowStockReorderDialog(),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Operations & Quick Actions Hub ──
  Widget _buildOperationsHub(
    Color cardBg,
    Color cyanAccent,
    Color emeraldAccent,
    Color amberAccent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Operations & Quick Actions',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Icon(Icons.bolt, color: Color(0xFF5CC8F8), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Action buttons grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _buildActionButton(
                label: 'Low Stock Reorder',
                desc: 'Auto-detect & buy',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFFEF4444),
                onTap: _showLowStockReorderDialog,
              ),
              _buildActionButton(
                label: 'AI Sourcing Hub',
                desc: 'Market research & MOQ',
                icon: Icons.auto_awesome,
                color: const Color(0xFFA855F7),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProcurementDetailsScreen(service: widget.service))),
              ),
              _buildActionButton(
                label: '+ Create PO',
                desc: 'Manual purchase order',
                icon: Icons.post_add_rounded,
                color: cyanAccent,
                onTap: _showCreatePODialog,
              ),
              _buildActionButton(
                label: '+ Add Supplier',
                desc: 'Register new vendor',
                icon: Icons.domain_add_rounded,
                color: emeraldAccent,
                onTap: _showAddSupplierDialog,
              ),
              _buildActionButton(
                label: 'Verify Suppliers',
                desc: 'Audit & activate',
                icon: Icons.verified_user_outlined,
                color: amberAccent,
                onTap: _showVerifySupplierDialog,
              ),
              _buildActionButton(
                label: 'Stripe Settlement',
                desc: 'Pay & send receipt',
                icon: Icons.credit_card,
                color: const Color(0xFF6366F1),
                onTap: _showStripeSettlementDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Cockpit ──
  Widget _buildStatusCockpit({
    required Color cardBg,
    required int totalOrders,
    required int draftCount,
    required int pendingCount,
    required int approvedCount,
    required int sentCount,
    required int revisionCount,
    required int rejectedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Purchase Order Status Distribution',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text('$totalOrders total', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('Draft', draftCount, const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _buildStatusChip('Pending Approval', pendingCount, const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildStatusChip('Approved', approvedCount, const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildStatusChip('Sent', sentCount, const Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                _buildStatusChip('Revision Req.', revisionCount, const Color(0xFFF97316)),
                const SizedBox(width: 8),
                _buildStatusChip('Rejected', rejectedCount, const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Approvals Queue ──
  Widget _buildApprovalsQueue(Color cardBg, Color amberAccent, List<PurchaseOrderSummary> pendingOrders) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amberAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: amberAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Approvals Queue (${pendingOrders.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              TextButton(
                onPressed: _openPendingApprovals,
                child: const Text('View All', style: TextStyle(color: Color(0xFF5CC8F8), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pendingOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text('No orders waiting for executive approval.', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingOrders.length > 3 ? 3 : pendingOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final po = pendingOrders[idx];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(po.poNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(po.supplierName, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(formatMoney(po.totalCost, currency: po.currency), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PODetailsScreen(service: widget.service, poId: po.id)),
                            ).then((_) => _loadData()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
    );
  }

  // ── Low Stock Alerts Card ──
  Widget _buildLowStockAlertsCard(Color cardBg, Color roseAccent, Color cyanAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roseAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notification_important_rounded, color: roseAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Low Stock Detected • Auto-Reorder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text('${_stockAlerts.length} alerts', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stockAlerts.length > 2 ? 2 : _stockAlerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final alert = _stockAlerts[idx];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.materialName ?? alert.sku, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Deficit: ${alert.quantityRequested} units • SKU: ${alert.sku}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handleInstantReplenish(alert),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.flash_on, size: 14),
                      label: const Text('Reorder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Recent Orders Table ──
  Widget _buildRecentOrdersTable(Color cardBg, Color cyanAccent, List<PurchaseOrderSummary> orders) {
    final recent = orders.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Purchase Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => POListScreen(service: widget.service))),
                child: const Text('All Orders →', style: TextStyle(color: Color(0xFF5CC8F8), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: Text('No purchase orders found.', style: TextStyle(color: Colors.white38))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 12),
              itemBuilder: (context, idx) {
                final po = recent[idx];
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PODetailsScreen(service: widget.service, poId: po.id)),
                  ).then((_) => _loadData()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(po.poNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(po.supplierName, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: po.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: po.statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(po.status, style: TextStyle(color: po.statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Text(formatMoney(po.totalCost, currency: po.currency), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Helper Actions ──

  void _openPendingApprovals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => POListScreen(service: widget.service),
      ),
    );
  }

  Future<void> _handleInstantReplenish(StockAlertItem alert) async {
    final qty = alert.quantityRequested > 0 ? alert.quantityRequested : 500;
    try {
      final po = await widget.service.createPurchaseOrder({
        'supplierId': _suppliers.isNotEmpty ? _suppliers.first.id : 1,
        'notes': 'Auto-replenish stock alert for SKU ${alert.sku}',
        'lines': [
          {
            'rawMaterialId': alert.rawMaterialId ?? 1,
            'quantity': qty.toDouble(),
            'unitPrice': 3.50,
            'totalPrice': qty * 3.50,
          }
        ],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reorder PO ${po.poNumber} created for ${alert.sku}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadData();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PODetailsScreen(service: widget.service, poId: po.id)),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Replenish error: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLowStockReorderDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Low Stock Replenishment', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _stockAlerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('All raw material stock levels are healthy! No active alerts.', style: TextStyle(color: Colors.white70)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _stockAlerts.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white10),
                  itemBuilder: (_, idx) {
                    final item = _stockAlerts[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.materialName ?? item.sku, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Deficit: ${item.quantityRequested} units', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleInstantReplenish(item);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5CC8F8), foregroundColor: Colors.black),
                        child: const Text('Reorder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  Future<void> _showCreatePODialog() async {
    final qtyController = TextEditingController(text: '1000');
    final priceController = TextEditingController(text: '3.50');
    final notesController = TextEditingController();
    int selectedSupplierId = _suppliers.isNotEmpty ? _suppliers.first.id : 1;
    int selectedMaterialId = 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Text('Create Manual Purchase Order', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: selectedSupplierId.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Supplier ID (e.g. 1)', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (val) {
                  final id = int.tryParse(val);
                  if (id != null) selectedSupplierId = id;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: selectedMaterialId.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Raw Material ID (e.g. 1)', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (val) {
                  final id = int.tryParse(val);
                  if (id != null) selectedMaterialId = id;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Unit Price (LKR )', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5CC8F8), foregroundColor: Colors.black),
            child: const Text('Submit PO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      final qty = double.tryParse(qtyController.text.trim()) ?? 1000;
      final price = double.tryParse(priceController.text.trim()) ?? 3.50;

      try {
        final po = await widget.service.createPurchaseOrder({
          'supplierId': selectedSupplierId,
          'notes': notesController.text.trim(),
          'lines': [
            {
              'rawMaterialId': selectedMaterialId,
              'quantity': qty,
              'unitPrice': price,
              'totalPrice': qty * price,
            }
          ],
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PO ${po.poNumber} created!'), backgroundColor: const Color(0xFF10B981)),
          );
          _loadData();
          Navigator.push(context, MaterialPageRoute(builder: (_) => PODetailsScreen(service: widget.service, poId: po.id)));
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Create PO failed: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Text('Register New Supplier', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Supplier Company Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contactController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Contact Person Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email Address', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Physical Address', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Register Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await widget.service.createSupplier({
          'name': nameController.text.trim(),
          'contactEmail': emailController.text.trim().isNotEmpty ? emailController.text.trim() : 'contact@supplier.com',
          'contactPhone': phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : '',
          'address': addressController.text.trim().isNotEmpty ? addressController.text.trim() : 'Industrial Zone, Sector 4',
          'paymentTerms': 'Net30',
          'leadTimeDays': 5,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier registered successfully!'), backgroundColor: Color(0xFF10B981)),
          );
          _loadData();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add supplier: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showVerifySupplierDialog() async {
    final unverified = _suppliers.where((s) => !s.isActive).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Text('Verify Supplier Vendors', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: unverified.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('All registered suppliers are currently verified & active.', style: TextStyle(color: Colors.white70)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: unverified.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white10),
                  itemBuilder: (_, idx) {
                    final s = unverified[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${s.email} • Terms: ${s.paymentTerms}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await widget.service.verifySupplier(s.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Supplier ${s.name} verified & activated!'), backgroundColor: const Color(0xFF10B981)),
                              );
                              _loadData();
                            }
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Verification error: $err'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        child: const Text('Verify', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  Future<void> _showStripeSettlementDialog() async {
    final readyForPayment = _orders.where((o) => o.status.toLowerCase() == 'approved' || o.status.toLowerCase() == 'payment').toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text('Stripe Payment Gateway', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: readyForPayment.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No orders waiting in Approved/Payment status for financial settlement.', style: TextStyle(color: Colors.white70)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: readyForPayment.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white10),
                  itemBuilder: (_, idx) {
                    final po = readyForPayment[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(po.poNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${po.supplierName} • ${formatMoney(po.totalCost, currency: po.currency)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PODetailsScreen(service: widget.service, poId: po.id)),
                          ).then((_) => _loadData());
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                        child: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }
}
