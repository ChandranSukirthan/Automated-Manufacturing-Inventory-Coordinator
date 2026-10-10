import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../utils/locale.dart';
import 'po_details_screen.dart';
import 'supplier_quotes_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({
    required this.supplier,
    required this.service,
    super.key,
  });

  final SupplierSummary supplier;
  final PurchaseOrderService service;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late SupplierSummary _supplier;
  bool _loading = false;
  List<PurchaseOrderSummary> _orders = [];
  bool _loadingOrders = true;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadingOrders = true;
      _ordersError = null;
    });

    try {
      final updatedSup = await widget.service.getSupplierById(_supplier.id);
      if (mounted) {
        setState(() {
          _supplier = updatedSup;
        });
      }
    } catch (_) {
      // If getSupplierById fails (e.g. mock/offline), keep existing _supplier
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    try {
      final allOrders = await widget.service.getPurchaseOrders();
      if (mounted) {
        setState(() {
          _orders = allOrders
              .where((po) =>
                  po.supplierName.trim().toLowerCase() ==
                  _supplier.name.trim().toLowerCase())
              .toList();
          _loadingOrders = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _ordersError = err.toString();
          _loadingOrders = false;
        });
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Deactivate Supplier',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to deactivate ${_supplier.name}? Existing purchase orders will be preserved, but new orders cannot be assigned to this vendor.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Deactivate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.deleteSupplier(_supplier.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supplier "${_supplier.name}" deactivated successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _loadData();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to deactivate supplier: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleActivate() async {
    try {
      await widget.service.verifySupplier(_supplier.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier "${_supplier.name}" activated successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadData();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate supplier: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _supplier.name);
    final codeCtrl = TextEditingController(
      text: _supplier.supplierCode ?? 'SUP-${_supplier.id}',
    );
    final emailCtrl = TextEditingController(text: _supplier.email);
    final phoneCtrl = TextEditingController(text: _supplier.phone);
    final addressCtrl = TextEditingController(text: _supplier.address);
    final leadTimeCtrl = TextEditingController(
      text: '${_supplier.leadTimeDays}',
    );
    String paymentTerms = _supplier.paymentTerms.isNotEmpty
        ? _supplier.paymentTerms
        : 'Net 30';
    bool isActive = _supplier.isActive;

    const termOptions = ['Net 15', 'Net 30', 'Net 60', 'Net 90', 'Due on Receipt'];
    if (!termOptions.contains(paymentTerms)) {
      paymentTerms = 'Net 30';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1B2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF5CC8F8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Supplier — ${_supplier.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Company / Supplier Name *',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Supplier Code',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: leadTimeCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Lead Time (Days)',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Email *',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Physical / Billing Address',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentTerms,
                  dropdownColor: const Color(0xFF0F1B2B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Payment Terms',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  items: termOptions
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentTerms = val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Active Partner',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Inactive suppliers cannot receive new Purchase Orders',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  value: isActive,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (v) => setDialogState(() => isActive = v),
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
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Supplier name and email are required.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5CC8F8),
                foregroundColor: const Color(0xFF070E17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final updatePayload = {
          'name': nameCtrl.text.trim(),
          'supplierCode': codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
          'contactEmail': emailCtrl.text.trim(),
          'contactPhone': phoneCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'paymentTerms': paymentTerms,
          'leadTimeDays': int.tryParse(leadTimeCtrl.text.trim()) ?? 7,
          'isActive': isActive,
        };
        final updated = await widget.service.updateSupplier(_supplier.id, updatePayload);
        if (mounted) {
          setState(() {
            _supplier = updated;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadData();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update supplier: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const emeraldAccent = Color(0xFF10B981);

    final totalOrders = _orders.length;
    final totalSpend = _orders
        .where((po) =>
            po.status == 'Approved' ||
            po.status == 'Payment' ||
            po.status == 'Sent' ||
            po.status == 'Delivered')
        .fold<double>(0.0, (sum, po) => sum + po.totalCost);
    final pendingOrders = _orders
        .where((po) => po.status.toLowerCase().contains('pending'))
        .length;

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: Text(
          _supplier.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: cyanAccent),
            tooltip: 'Edit Supplier',
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: cyanAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cyanAccent.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.business_rounded,
                                  color: cyanAccent,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _supplier.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _supplier.supplierCode ?? 'SUP-${_supplier.id}',
                                            style: const TextStyle(
                                              color: cyanAccent,
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _supplier.isActive
                                                ? emeraldAccent.withValues(alpha: 0.15)
                                                : Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _supplier.isActive
                                                  ? emeraldAccent.withValues(alpha: 0.35)
                                                  : Colors.white24,
                                            ),
                                          ),
                                          child: Text(
                                            _supplier.isActive
                                                ? 'ACTIVE PARTNER'
                                                : 'INACTIVE',
                                            style: TextStyle(
                                              color: _supplier.isActive
                                                  ? emeraldAccent
                                                  : Colors.white60,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 12),
                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => SupplierQuotesScreen(
                                        supplierId: _supplier.id,
                                      ),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cyanAccent,
                                    side: const BorderSide(color: cyanAccent),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.price_change, size: 15),
                                  label: const Text(
                                    'Material Quotes',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (_supplier.isActive)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleDeactivate,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(color: Colors.redAccent),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.block_rounded, size: 15),
                                    label: const Text(
                                      'Deactivate',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _handleActivate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: emeraldAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, size: 15),
                                    label: const Text(
                                      'Activate Partner',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Contact & Logistics details
                    const Text(
                      'Contact & Contract Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            Icons.person_outline,
                            'Contact Person',
                            _supplier.contactPerson.isNotEmpty
                                ? _supplier.contactPerson
                                : 'Primary Contact',
                          ),
                          const Divider(color: Colors.white10, height: 18),
                          _buildDetailRow(
                            Icons.mail_outline,
                            'Email Address',
                            _supplier.email.isNotEmpty ? _supplier.email : '—',
                          ),
                          const Divider(color: Colors.white10, height: 18),
                          _buildDetailRow(
                            Icons.phone_outlined,
                            'Phone Number',
                            _supplier.phone.isNotEmpty ? _supplier.phone : '—',
                          ),
                          const Divider(color: Colors.white10, height: 18),
                          _buildDetailRow(
                            Icons.location_on_outlined,
                            'Physical / Billing Address',
                            _supplier.address.isNotEmpty ? _supplier.address : '—',
                          ),
                          const Divider(color: Colors.white10, height: 18),
                          _buildDetailRow(
                            Icons.credit_card_outlined,
                            'Payment Terms',
                            _supplier.paymentTerms,
                          ),
                          const Divider(color: Colors.white10, height: 18),
                          _buildDetailRow(
                            Icons.schedule_outlined,
                            'Standard Lead Time',
                            '${_supplier.leadTimeDays} Business Days',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Associated Purchase Orders section
                    const Text(
                      'Associated Purchase Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Order metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            'Total Orders',
                            '$totalOrders',
                            Colors.white,
                            cardBg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStat(
                            'Total Spend',
                            formatMoney(totalSpend),
                            emeraldAccent,
                            cardBg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStat(
                            'Pending',
                            '$pendingOrders',
                            const Color(0xFFFFB74D),
                            cardBg,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_loadingOrders)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_ordersError != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Could not load purchase orders: $_ordersError',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      )
                    else if (_orders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.white30,
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No purchase orders linked to this vendor yet.',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
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
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final po = _orders[idx];
                          return Material(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PODetailsScreen(
                                    service: widget.service,
                                    poId: po.id,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
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
                                          const SizedBox(height: 4),
                                          Text(
                                            'Created: ${_formatDate(po.createdAt)}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatMoney(po.totalCost, currency: po.currency),
                                          style: const TextStyle(
                                            color: emeraldAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            po.status,
                                            style: const TextStyle(
                                              color: cyanAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                  ],
                                ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
