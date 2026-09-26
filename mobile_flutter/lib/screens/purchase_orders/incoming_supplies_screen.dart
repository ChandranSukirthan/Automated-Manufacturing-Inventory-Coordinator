import 'package:flutter/material.dart';
import '../../models/procurement_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';

/// Screen for Floor Workers to track incoming raw material deliveries from approved POs.
class IncomingSuppliesScreen extends StatefulWidget {
  const IncomingSuppliesScreen({
    required this.service,
    super.key,
  });

  final PurchaseOrderService service;

  @override
  State<IncomingSuppliesScreen> createState() => _IncomingSuppliesScreenState();
}

class _IncomingSuppliesScreenState extends State<IncomingSuppliesScreen> {
  bool _loading = true;
  String? _error;
  List<IncomingSupplyItem> _supplies = [];
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'EXPECTED',
    'IN_TRANSIT',
    'RECEIVED',
    'DELAYED',
    'COMPLETED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSupplies();
  }

  Future<void> _fetchSupplies() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.service.getIncomingSupplies();
      if (mounted) {
        setState(() {
          _supplies = list.isNotEmpty
              ? list
              : [
                  // Fallback sample data if backend has no active POs yet
                  IncomingSupplyItem(
                    purchaseOrderId: 42,
                    poNumber: 'PO-2026-0042',
                    supplierName: 'Apex Packaging Materials Ltd',
                    materialName: 'Food Grade BOPP Film',
                    quantity: 1000.0,
                    expectedDelivery: DateTime.now().add(const Duration(days: 3)),
                    deliveryStatus: SupplyDeliveryStatus.inTransit,
                    trackingNumber: 'TRK-APEX-9921',
                    actualDeliveryDate: null,
                    statusRemarks: 'Dispatched from regional warehouse via Express Freight',
                  ),
                  IncomingSupplyItem(
                    purchaseOrderId: 39,
                    poNumber: 'PO-2026-0039',
                    supplierName: 'Global Polymers Corp',
                    materialName: 'High-Density Polyethylene Resin',
                    quantity: 2500.0,
                    expectedDelivery: DateTime.now().add(const Duration(days: 6)),
                    deliveryStatus: SupplyDeliveryStatus.expected,
                    trackingNumber: 'TRK-GPC-4412',
                    actualDeliveryDate: null,
                    statusRemarks: 'Order confirmed and awaiting carrier pickup',
                  ),
                  IncomingSupplyItem(
                    purchaseOrderId: 36,
                    poNumber: 'PO-2026-0036',
                    supplierName: 'BioPack Eco Solutions',
                    materialName: 'Biodegradable Sealant Layer',
                    quantity: 500.0,
                    expectedDelivery: DateTime.now().subtract(const Duration(days: 1)),
                    deliveryStatus: SupplyDeliveryStatus.received,
                    trackingNumber: 'TRK-BIO-1082',
                    actualDeliveryDate: DateTime.now().subtract(const Duration(days: 1)),
                    statusRemarks: 'Delivered at Loading Bay 2. Awaiting QA inspection roll verification.',
                  ),
                ];
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

    final filteredList = _supplies.where((item) {
      if (_selectedFilter == 'ALL') return true;
      return item.deliveryStatus.label == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: const Text(
          'Incoming Supplies',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchSupplies,
            tooltip: 'Refresh Deliveries',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? StateMessage(
                  message: _error!,
                  icon: Icons.cloud_off,
                  action: _fetchSupplies,
                )
              : RefreshIndicator(
                  onRefresh: _fetchSupplies,
                  child: Column(
                    children: [
                      // Filter Chips Row
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (context, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = _filters[index];
                            final isSelected = filter == _selectedFilter;
                            return ChoiceChip(
                              label: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: cyanAccent,
                              backgroundColor: cardBg,
                              onSelected: (_) => setState(() => _selectedFilter = filter),
                            );
                          },
                        ),
                      ),

                      // Deliveries List
                      Expanded(
                        child: filteredList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.local_shipping_outlined, size: 54, color: Colors.white24),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'No Incoming Orders Found',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'No shipments currently match the selected filter.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _fetchSupplies,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cyanAccent,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.refresh, size: 18),
                                        label: const Text('Tap to Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredList.length,
                                separatorBuilder: (context, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  return _buildDeliveryCard(item, cardBg, cyanAccent, amberAccent);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDeliveryCard(
    IncomingSupplyItem item,
    Color cardBg,
    Color cyanAccent,
    Color amberAccent,
  ) {
    final status = item.deliveryStatus;

    return Container(
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
              Text(
                item.poNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: status.color.withOpacity(0.4)),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.supplierName,
            style: TextStyle(color: cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildRow('Material', item.materialName),
          _buildRow('Quantity', '${item.quantity.toStringAsFixed(0)} units'),
          _buildRow(
            'Expected Delivery',
            item.expectedDelivery.toString().substring(0, 10),
            valueColor: Colors.white,
          ),
          if (item.trackingNumber != null && item.trackingNumber!.isNotEmpty)
            _buildRow('Tracking', item.trackingNumber!, valueColor: Colors.white70),
          if (item.statusRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.statusRemarks,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showUpdateDeliveryStatusDialog(item),
              style: OutlinedButton.styleFrom(
                foregroundColor: cyanAccent,
                side: BorderSide(color: cyanAccent.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_road_outlined, size: 16),
              label: const Text(
                'UPDATE DELIVERY STATUS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateDeliveryStatusDialog(IncomingSupplyItem item) {
    String selectedStatus = item.deliveryStatus.label;
    final remarksController = TextEditingController(text: item.statusRemarks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Update Status • ${item.poNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Material: ${item.materialName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DELIVERY STATUS',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: const ['EXPECTED', 'IN_TRANSIT', 'RECEIVED', 'COMPLETED'].contains(selectedStatus)
                        ? selectedStatus
                        : 'IN_TRANSIT',
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'EXPECTED', child: Text('EXPECTED')),
                      DropdownMenuItem(value: 'IN_TRANSIT', child: Text('IN_TRANSIT')),
                      DropdownMenuItem(value: 'RECEIVED', child: Text('RECEIVED / DELIVERED')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'STATUS REMARKS',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarksController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Received at Loading Bay 2, verified seal intact',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _loading = true);
                        try {
                          await widget.service.updateDeliveryStatus(
                            item.purchaseOrderId,
                            selectedStatus,
                            remarks: remarksController.text,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Delivery status for ${item.poNumber} updated to $selectedStatus.'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            _fetchSupplies();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                            setState(() => _loading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5CC8F8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('CONFIRM UPDATE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
