import 'dart:async';
import '../../utils/locale.dart';
import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';
import 'po_create_screen.dart';

class POListScreen extends StatefulWidget {
  const POListScreen({
    required this.service,
    this.showAppBar = true,
    this.isActive = true,
    this.allowManagement = true,
    this.allowApproval = false,
    this.initialFilter = 'ALL',
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;
  final bool isActive;
  final bool allowManagement;
  final bool allowApproval;
  final String initialFilter;

  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _fetching = false;
  bool _loading = true;
  String? _error;
  List<PurchaseOrderSummary> _orders = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'PendingApproval',
    'Approved',
    'Payment',
    'PaymentPending',
    'Paid',
    'PaymentFailed',
    'Sent',
    'SupplierNotified',
    'InTransit',
    'Delivered',
    'Completed',
    'Draft',
    'Rejected',
    'RevisionRequested',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = _filters.contains(widget.initialFilter)
        ? widget.initialFilter
        : 'ALL';
    WidgetsBinding.instance.addObserver(this);
    _fetchOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        _fetchOrders(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant POListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _fetchOrders(showLoading: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _fetchOrders(showLoading: false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchOrders({bool showLoading = true}) async {
    if (_fetching) return;
    _fetching = true;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.getPurchaseOrders();
      if (mounted) {
        setState(() {
          _orders = data;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          if (showLoading || _orders.isEmpty) _error = err.toString();
          _loading = false;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  List<PurchaseOrderSummary> get _filteredOrders {
    return _orders.where((order) {
      final matchesSearch =
          order.poNumber.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          ) ||
          order.supplierName.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          );

      final matchesFilter =
          _selectedFilter == 'ALL' ||
          order.status.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _statusLabel(String status) => switch (status) {
    'ALL' => 'All statuses',
    'PendingApproval' => 'Pending Approval',
    'RevisionRequested' => 'Revision Requested',
    'Payment' => 'Payment Processing',
    'PaymentPending' => 'Payment Pending',
    'PaymentFailed' => 'Payment Failed',
    'SupplierNotified' => 'Supplier Notified',
    'InTransit' => 'In Transit',
    _ => status,
  };

  String _paymentLabel(PurchaseOrderSummary order) {
    final status = order.paymentStatusDisplay;
    return switch (status.toLowerCase()) {
      'succeeded' || 'paid' || 'settled' => 'Paid',
      'requires_payment_method' => 'Payment method required',
      'requires_action' => 'Action required',
      'processing' => 'Processing',
      'failed' => 'Failed',
      'canceled' => 'Cancelled',
      _ => status,
    };
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedFilter = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF0F1B2B);
    const accent = Color(0xFF5CC8F8);
    final orders = _filteredOrders;
    final hasFilters = _searchQuery.isNotEmpty || _selectedFilter != 'ALL';

    return Scaffold(
      backgroundColor: const Color(0xFF070E17),
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Purchase Orders'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Purchase Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _fetchOrders,
                  icon: const Icon(Icons.refresh_rounded, color: accent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search order number or supplier',
                hintStyle: const TextStyle(color: Color(0xFF9DAEC2)),
                prefixIcon: const Icon(Icons.search_rounded, color: accent),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26374B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('order-status-filter'),
              initialValue: _selectedFilter,
              isExpanded: true,
              dropdownColor: cardBg,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Order status',
                labelStyle: const TextStyle(color: Color(0xFFB6C6DA)),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _filters
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedFilter = value ?? 'ALL'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  '${orders.length} of ${_orders.length} orders',
                  style: const TextStyle(
                    color: Color(0xFFB6C6DA),
                    fontSize: 13,
                  ),
                ),
                if (hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? StateMessage(
                    message: _error!,
                    icon: Icons.cloud_off,
                    action: _fetchOrders,
                  )
                : orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: Color(0xFF8CA2BC),
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasFilters
                                ? 'No orders match your filters.'
                                : 'No purchase orders yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB6C6DA),
                              fontSize: 15,
                            ),
                          ),
                          if (hasFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Reset search and filters'),
                            ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, index) => _orderCard(orders[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.allowManagement
          ? FloatingActionButton.extended(
              onPressed: _showCreatePODialog,
              backgroundColor: accent,
              foregroundColor: const Color(0xFF070E17),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create PO'),
            )
          : null,
    );
  }

  Widget _orderCard(PurchaseOrderSummary po) {
    final payment = _paymentLabel(po);
    final paymentColor = switch (payment) {
      'Paid' => const Color(0xFF76E6B4),
      'Failed' || 'Cancelled' => const Color(0xFFFF9A9A),
      _ => const Color(0xFFECC879),
    };
    return Material(
      color: const Color(0xFF0F1B2B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF26374B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PODetailsScreen(
                service: widget.service,
                poId: po.id,
                allowManagement: widget.allowManagement,
                allowApproval: widget.allowApproval,
              ),
            ),
          );
          if (mounted) await _fetchOrders(showLoading: false);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                po.poNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: po.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(po.status),
                  style: TextStyle(
                    color: Color.lerp(po.statusColor, Colors.white, 0.3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 18,
                    color: Color(0xFF9DAEC2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      po.supplierName,
                      style: const TextStyle(
                        color: Color(0xFFD5DFEC),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFF26374B)),
              ),
              _infoRow(
                Icons.verified_outlined,
                'Approval: ${po.approvalStatusDisplay}',
                const Color(0xFFD5DFEC),
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.payments_outlined,
                'Payment: $payment',
                paymentColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'ORDER TOTAL',
                style: TextStyle(
                  color: Color(0xFF9DAEC2),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(po.totalCost, currency: po.currency),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow(
                Icons.calendar_today_outlined,
                'Created ${po.createdAt.day.toString().padLeft(2, '0')}/${po.createdAt.month.toString().padLeft(2, '0')}/${po.createdAt.year}',
                const Color(0xFFB6C6DA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 13, height: 1.4),
        ),
      ),
    ],
  );

  Future<void> _showCreatePODialog() async {
    final poId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => POCreateScreen(service: widget.service),
      ),
    );
    if (!mounted) return;
    await _fetchOrders(showLoading: false);
    if (poId != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PODetailsScreen(service: widget.service, poId: poId),
        ),
      );
      if (mounted) await _fetchOrders(showLoading: false);
    }
  }
}
