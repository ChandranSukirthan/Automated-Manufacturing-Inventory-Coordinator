import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'supplier_detail_screen.dart';
import 'supplier_quotes_screen.dart';

class SupplierStatusScreen extends StatefulWidget {
  const SupplierStatusScreen({
    required this.service,
    this.showAppBar = true,
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;

  @override
  State<SupplierStatusScreen> createState() => _SupplierStatusScreenState();
}

class _SupplierStatusScreenState extends State<SupplierStatusScreen> {
  bool _loading = true;
  String? _error;
  List<SupplierSummary> _suppliers = [];
  SupplierAnalytics? _analytics;

  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.service.getSuppliers();
      final stats = await widget.service.getSupplierAnalytics();

      if (mounted) {
        setState(() {
          _suppliers = list;
          _analytics = stats;
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

  List<SupplierSummary> get _filteredSuppliers {
    return _suppliers.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.supplierCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          s.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && s.isActive) ||
          (_statusFilter == 'inactive' && !s.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const emeraldAccent = Color(0xFF10B981);

    final totalCount = _suppliers.length;
    final activeCount = _suppliers.where((s) => s.isActive).length;
    final inactiveCount = _suppliers.where((s) => !s.isActive).length;

    final filteredList = _filteredSuppliers;

    return Scaffold(
      backgroundColor: navyBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: navyBg,
              elevation: 0,
              title: const Text(
                'Supplier Status',
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
                  onPressed: _fetchSuppliers,
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Refresh',
                  onPressed: _fetchSuppliers,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? StateMessage(
                        message: _error!,
                        icon: Icons.cloud_off,
                        action: _fetchSuppliers,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchSuppliers,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Metrics Cards — Matching Web (Matching, Active, Inactive)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Total Vendors',
                                      '$totalCount',
                                      Colors.white,
                                      cardBg,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Active Vendors',
                                      '$activeCount',
                                      emeraldAccent,
                                      cardBg,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Inactive Vendors',
                                      '$inactiveCount',
                                      Colors.white60,
                                      cardBg,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Search & Status Filters
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      onChanged: (val) =>
                                          setState(() => _searchQuery = val.trim()),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Search by vendor name, code, email...',
                                        hintStyle: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: Colors.white54,
                                          size: 18,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: Colors.white38,
                                                  size: 16,
                                                ),
                                                onPressed: () => setState(
                                                  () => _searchQuery = '',
                                                ),
                                              )
                                            : null,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 12,
                                        ),
                                        fillColor: const Color(0xFF070E17),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _buildFilterTab('all', 'All ($totalCount)'),
                                        const SizedBox(width: 8),
                                        _buildFilterTab(
                                          'active',
                                          'Active ($activeCount)',
                                          activeColor: emeraldAccent,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildFilterTab(
                                          'inactive',
                                          'Inactive ($inactiveCount)',
                                          activeColor: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Approved Vendor Directory',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${filteredList.length} shown',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (filteredList.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.domain_disabled_rounded,
                                        color: Colors.white24,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _searchQuery.isNotEmpty ||
                                                _statusFilter != 'all'
                                            ? 'No matching suppliers found.'
                                            : 'No suppliers registered yet.',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: filteredList.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, idx) {
                                    final sup = filteredList[idx];
                                    return _buildSupplierCard(
                                      sup,
                                      cardBg,
                                      cyanAccent,
                                      emeraldAccent,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        backgroundColor: cyanAccent,
        foregroundColor: const Color(0xFF070E17),
        icon: const Icon(Icons.domain_add_rounded),
        label: const Text(
          'Add Supplier',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filterKey, String label, {Color? activeColor}) {
    final isSelected = _statusFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = filterKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (activeColor ?? const Color(0xFF5CC8F8))
                    .withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (activeColor ?? const Color(0xFF5CC8F8))
                  : Colors.white12,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (activeColor ?? const Color(0xFF5CC8F8))
                    : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierCard(
    SupplierSummary sup,
    Color cardBg,
    Color cyanAccent,
    Color emeraldAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetail(sup),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name, Code, and Status Badge (NO Rating!)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cyanAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Color(0xFF5CC8F8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sup.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sup.supplierCode ?? 'SUP-${sup.id}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sup.isActive
                            ? emeraldAccent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sup.isActive
                              ? emeraldAccent.withValues(alpha: 0.3)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        sup.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: sup.isActive ? emeraldAccent : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Contact details
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      size: 13,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sup.email.isNotEmpty ? sup.email : 'No email provided',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sup.phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sup.phone,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),

                if (sup.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sup.address,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      'Terms: ${sup.paymentTerms} • Lead Time: ${sup.leadTimeDays}d',
                      style: const TextStyle(
                        color: Color(0xFF5CC8F8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),

                // CRUD Action Buttons Row: View, Edit, Delete (Deactivate) / Activate, Quotes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // View Button
                    TextButton.icon(
                      onPressed: () => _navigateToDetail(sup),
                      style: TextButton.styleFrom(
                        foregroundColor: cyanAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text(
                        'View',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Edit Button
                    TextButton.icon(
                      onPressed: () => _showEditSupplierDialog(sup),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Delete / Deactivate or Activate Button
                    if (sup.isActive)
                      TextButton.icon(
                        onPressed: () => _handleDeactivateSupplier(sup),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _handleVerifySupplier(sup),
                        style: TextButton.styleFrom(
                          foregroundColor: emeraldAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 15),
                        label: const Text(
                          'Activate',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                    // Material Quotes Shortcut
                    IconButton(
                      tooltip: 'Material Quotes',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SupplierQuotesScreen(
                            supplierId: sup.id,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.price_change_outlined,
                        size: 18,
                        color: Colors.white54,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(SupplierSummary sup) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupplierDetailScreen(
          supplier: sup,
          service: widget.service,
        ),
      ),
    ).then((_) => _fetchSuppliers());
  }

  Future<void> _handleDeactivateSupplier(SupplierSummary sup) async {
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
          'Are you sure you want to deactivate ${sup.name}? Existing purchase orders will be preserved, but new orders cannot be assigned to this vendor.',
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
        await widget.service.deleteSupplier(sup.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supplier "${sup.name}" deactivated successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _fetchSuppliers();
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

  Future<void> _handleVerifySupplier(SupplierSummary sup) async {
    try {
      await widget.service.verifySupplier(sup.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier "${sup.name}" verified & activated!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchSuppliers();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditSupplierDialog(SupplierSummary sup) async {
    final nameController = TextEditingController(text: sup.name);
    final codeController = TextEditingController(
      text: sup.supplierCode ?? 'SUP-${sup.id}',
    );
    final emailController = TextEditingController(text: sup.email);
    final phoneController = TextEditingController(text: sup.phone);
    final addressController = TextEditingController(text: sup.address);
    final leadTimeController = TextEditingController(
      text: '${sup.leadTimeDays}',
    );
    String paymentTerms = sup.paymentTerms.isNotEmpty ? sup.paymentTerms : 'Net 30';
    bool isActive = sup.isActive;

    const termOptions = ['Net 15', 'Net 30', 'Net 60', 'Net 90', 'Due on Receipt'];
    if (!termOptions.contains(paymentTerms)) {
      paymentTerms = 'Net 30';
    }

    final result = await showDialog<bool>(
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
                  'Edit Supplier — ${sup.name}',
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
              children: [
                TextField(
                  controller: nameController,
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
                        controller: codeController,
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
                        controller: leadTimeController,
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
                  controller: emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Email *',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
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
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
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

    if (result == true) {
      try {
        await widget.service.updateSupplier(sup.id, {
          'name': nameController.text.trim(),
          'supplierCode': codeController.text.trim().isNotEmpty
              ? codeController.text.trim()
              : null,
          'contactEmail': emailController.text.trim(),
          'contactPhone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'paymentTerms': paymentTerms,
          'leadTimeDays':
              int.tryParse(leadTimeController.text.trim()) ?? 7,
          'isActive': isActive,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _fetchSuppliers();
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

  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    String paymentTerms = 'Net 30';
    final leadTimeController = TextEditingController(text: '7');

    const termOptions = ['Net 15', 'Net 30', 'Net 60', 'Net 90', 'Due on Receipt'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1B2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.domain_add_rounded, color: Color(0xFF5CC8F8)),
              SizedBox(width: 8),
              Text(
                'Register New Supplier',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
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
                        controller: codeController,
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
                        controller: leadTimeController,
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
                  controller: contactController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Person Name',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Email *',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Physical Address',
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
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
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Register Supplier',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await widget.service.createSupplier({
          'name': nameController.text.trim(),
          'supplierCode': codeController.text.trim().isNotEmpty
              ? codeController.text.trim()
              : null,
          'contactEmail': emailController.text.trim(),
          'contactPhone': phoneController.text.trim(),
          'address': addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : 'Sector 4, Industrial Zone',
          'paymentTerms': paymentTerms,
          'leadTimeDays': int.tryParse(leadTimeController.text.trim()) ?? 7,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier registered successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _fetchSuppliers();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add supplier: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildMetricTile(String label, String value, Color color, Color bg) {
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
