import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';

class POListScreen extends StatefulWidget {
  const POListScreen({
    required this.service,
    super.key,
  });

  final PurchaseOrderService service;

  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen> {
  bool _loading = true;
  String? _error;
  List<PurchaseOrderSummary> _orders = [];
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'PendingApproval',
    'Approved',
    'Payment',
    'Sent',
    'Draft',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
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
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  List<PurchaseOrderSummary> get _filteredOrders {
    return _orders.where((order) {
      final matchesSearch = order.poNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.supplierName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'ALL' ||
          order.status.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
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
        title: const Text(
          'Purchase Orders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by PO# or Supplier...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cyanAccent),
                ),
              ),
            ),
          ),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter == 'PendingApproval' ? 'Pending' : filter,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF070E17) : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: cyanAccent,
                    backgroundColor: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? cyanAccent : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Orders List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? StateMessage(
                        message: _error!,
                        icon: Icons.cloud_off,
                        action: _fetchOrders,
                      )
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No purchase orders match your criteria.',
                                  style: TextStyle(color: Colors.white54, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchOrders,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _filteredOrders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final po = _filteredOrders[idx];
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
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
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
                                                fontSize: 15,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: po.statusColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: po.statusColor.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                po.status,
                                                style: TextStyle(
                                                  color: po.statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.business_outlined, size: 16, color: Colors.white38),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                po.supplierName,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(color: Colors.white10, height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white38),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${po.createdAt.year}-${po.createdAt.month.toString().padLeft(2, '0')}-${po.createdAt.day.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '\$${po.totalCost.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
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
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePODialog,
        backgroundColor: cyanAccent,
        foregroundColor: const Color(0xFF070E17),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create PO', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _showCreatePODialog() async {
    final qtyController = TextEditingController(text: '1000');
    final priceController = TextEditingController(text: '3.50');
    final notesController = TextEditingController();
    int selectedSupplierId = 1;
    int selectedMaterialId = 1;

    try {
      final suppliers = await widget.service.getSuppliers();
      if (suppliers.isNotEmpty) {
        selectedSupplierId = suppliers.first.id;
      }
    } catch (_) {}

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1B2B),
          title: const Row(
            children: [
              Icon(Icons.post_add_rounded, color: Color(0xFF5CC8F8)),
              SizedBox(width: 8),
              Text('Create Purchase Order', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Supplier ID', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  onChanged: (val) {
                    final id = int.tryParse(val);
                    if (id != null) selectedSupplierId = id;
                  },
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: selectedSupplierId.toString()),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter Supplier ID (e.g. 1)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Raw Material ID', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  onChanged: (val) {
                    final id = int.tryParse(val);
                    if (id != null) selectedMaterialId = id;
                  },
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: selectedMaterialId.toString()),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter Material ID (e.g. 1)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit Price (\$)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Order Notes', style: TextStyle(color: Colors.white54, fontSize: 12)),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Optional notes or spec details...',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5CC8F8),
                foregroundColor: const Color(0xFF070E17),
              ),
              child: const Text('Submit PO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
            SnackBar(
              content: Text('Purchase Order ${po.poNumber} created successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _fetchOrders();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PODetailsScreen(service: widget.service, poId: po.id),
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create PO: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

