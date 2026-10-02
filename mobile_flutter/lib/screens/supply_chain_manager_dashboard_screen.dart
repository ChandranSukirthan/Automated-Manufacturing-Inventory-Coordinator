import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_colors.dart';
import '../models/purchase_order_models.dart';
import '../models/procurement_models.dart';
import '../services/purchase_order_service.dart';
import '../widgets/app_widgets.dart';
import 'purchase_orders/po_create_screen.dart';
import 'purchase_orders/procurement_details_screen.dart';

class SupplyChainManagerDashboardScreen extends StatefulWidget {
  const SupplyChainManagerDashboardScreen({
    required this.service,
    this.appState,
    super.key,
  });

  final PurchaseOrderService service;
  final AppState? appState;

  @override
  State<SupplyChainManagerDashboardScreen> createState() => _SupplyChainManagerDashboardScreenState();
}

class _SupplyChainManagerDashboardScreenState extends State<SupplyChainManagerDashboardScreen> {
  bool _loading = true;
  String? _error;
  
  List<PurchaseOrderSummary> _purchaseOrders = [];
  List<StockAlertItem> _alerts = [];
  
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await widget.service.getPurchaseOrders();
      final alerts = await widget.service.getUnreadStockAlerts();
      if (mounted) {
        setState(() {
          _purchaseOrders = pos;
          _alerts = alerts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load supply chain metrics.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text('Supply Chain Manager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (widget.appState?.session?.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => widget.appState!.logout(),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 20),
                      _buildAlertsSection(),
                      const SizedBox(height: 20),
                      _buildRecentPurchaseOrders(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final pendingApprovals = _purchaseOrders.where((po) => po.status == 'PendingApproval').length;
    final totalValue = _purchaseOrders.fold<double>(0, (sum, po) => sum + po.totalCost);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          title: 'Total Purchase Value',
          value: '\$${totalValue.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Pending Approvals',
          value: '$pendingApprovals',
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Active Alerts',
          value: '${_alerts.length}',
          icon: Icons.warning_amber,
          color: Colors.redAccent,
        ),
        _buildMetricCard(
          title: 'Total POs',
          value: '${_purchaseOrders.length}',
          icon: Icons.receipt_long,
          color: Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    if (_alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Low Stock Alerts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alerts.length,
          itemBuilder: (context, index) {
            final alert = _alerts[index];
            return Card(
              color: const Color(0xFF0F172A),
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.redAccent),
                title: Text(alert.materialName ?? alert.sku, style: const TextStyle(color: Colors.white)),
                subtitle: Text('SKU: ${alert.sku} - Deficit: ${alert.netDeficit ?? 0}', style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                onTap: () => _showAlertActionSheet(alert),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAlertActionSheet(StockAlertItem alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Take action for ${alert.materialName ?? alert.sku}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('SKU: ${alert.sku} requires ${alert.netDeficit ?? 0} units', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Color(0xFF3B82F6)),
                  title: const Text('Autonomous AI Reorder', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('AI will analyze vendors and suggest a PO', style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(context);
                    _triggerAiProcurement(alert);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Color(0xFF10B981)),
                  title: const Text('Manual Purchase', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Select a supplier and create a PO manually', style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(context);
                    _openManualPurchase(alert);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _triggerAiProcurement(StockAlertItem alert) async {
    setState(() => _loading = true);
    try {
      final reqData = {
        'rawMaterialId': alert.rawMaterialId,
        'quantity': alert.netDeficit != null && alert.netDeficit! > 0 ? alert.netDeficit : 100,
      };
      // Step 1: Create request
      final request = await widget.service.createProcurementRequest(reqData);
      
      // Step 2: Trigger AI Research
      await widget.service.startProcurementResearch(request.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Procurement Workflow Started!'), backgroundColor: Colors.green),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcurementDetailsScreen(
              service: widget.service,
              procurementId: request.id,
            ),
          ),
        ).then((_) => _load());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Reorder failed: $e'), backgroundColor: Colors.red),
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
          quantity: alert.netDeficit != null && alert.netDeficit! > 0 ? alert.netDeficit : 100,
        ),
      ),
    ).then((_) => _load());
  }

  Widget _buildRecentPurchaseOrders() {
    if (_purchaseOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Purchase Orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _purchaseOrders.take(5).length,
          itemBuilder: (context, index) {
            final po = _purchaseOrders[index];
            return Card(
              color: const Color(0xFF0F172A),
              child: ListTile(
                leading: const Icon(Icons.receipt, color: Colors.blueAccent),
                title: Text(po.poNumber, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${po.supplierName} - \$${po.totalCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                trailing: Text(po.status, style: const TextStyle(color: Colors.white54)),
              ),
            );
          },
        ),
      ],
    );
  }
}
