import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/inventory_api_service.dart';
import '../../services/purchase_order_service.dart';

class POCreateScreen extends StatefulWidget {
  const POCreateScreen({
    required this.service,
    this.materialId,
    this.sku,
    this.quantity,
    super.key,
  });

  final PurchaseOrderService service;
  final int? materialId;
  final String? sku;
  final num? quantity;

  @override
  State<POCreateScreen> createState() => _POCreateScreenState();
}

class _LineItemDraft {
  int? rawMaterialId;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '100');
  final TextEditingController unitPriceController = TextEditingController(text: '15.00');

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }

  double get subtotal {
    final qty = double.tryParse(quantityController.text) ?? 0.0;
    final price = double.tryParse(unitPriceController.text) ?? 0.0;
    return qty * price;
  }
}

class _POCreateScreenState extends State<POCreateScreen> {
  final _inventoryService = InventoryApiService();
  bool _loading = true;
  bool _submitting = false;

  List<SupplierSummary> _suppliers = [];
  List<RawMaterialModel> _materials = [];
  int? _selectedSupplierId;

  final List<_LineItemDraft> _lineItems = [];
  final _budgetController = TextEditingController(text: '25000.00');
  final _shippingController = TextEditingController(text: '0.00');
  final _notesController = TextEditingController(
    text: 'Standard replenishing purchase order generated from mobile',
  );

  @override
  void initState() {
    super.initState();
    final initialLine = _LineItemDraft();
    if (widget.quantity != null) {
      initialLine.quantityController.text = widget.quantity.toString();
    }
    _lineItems.add(initialLine);
    _loadData();
  }

  @override
  void dispose() {
    for (final line in _lineItems) {
      line.dispose();
    }
    _budgetController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.service.getSuppliers(),
        _inventoryService.fetchRawMaterials(),
      ]);

      if (mounted) {
        final suppliers = results[0] as List<SupplierSummary>;
        final materials = results[1] as List<RawMaterialModel>;

        setState(() {
          _suppliers = suppliers;
          _materials = materials;
          _selectedSupplierId = suppliers.isNotEmpty ? suppliers.first.id : null;

          if (_lineItems.isNotEmpty && materials.isNotEmpty) {
            if (widget.materialId != null && materials.any((m) => m.id == widget.materialId)) {
              _lineItems.first.rawMaterialId = widget.materialId;
            } else if (widget.sku != null && materials.any((m) => m.skuCode == widget.sku)) {
              final match = materials.firstWhere((m) => m.skuCode == widget.sku);
              _lineItems.first.rawMaterialId = match.id;
            } else {
              _lineItems.first.rawMaterialId = materials.first.id;
            }
          }
          _updateBudgetRecommendation();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _subtotal {
    double total = 0;
    for (final line in _lineItems) {
      total += line.subtotal;
    }
    return total;
  }

  double get _totalCost {
    final shipping = double.tryParse(_shippingController.text) ?? 0.0;
    return _subtotal + shipping;
  }

  void _updateBudgetRecommendation() {
    final total = _totalCost;
    final recommended = (total * 1.15).clamp(1000.0, 10000000.0);
    _budgetController.text = recommended.toStringAsFixed(2);
  }

  void _addLineItem() {
    setState(() {
      final line = _LineItemDraft();
      if (_materials.isNotEmpty) {
        line.rawMaterialId = _materials.first.id;
      }
      _lineItems.add(line);
      _updateBudgetRecommendation();
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      final removed = _lineItems.removeAt(index);
      removed.dispose();
      _updateBudgetRecommendation();
    });
  }

  Future<void> _createPo() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier.'), backgroundColor: Colors.red),
      );
      return;
    }

    for (int i = 0; i < _lineItems.length; i++) {
      final line = _lineItems[i];
      if (line.rawMaterialId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a material for line #${i + 1}.'), backgroundColor: Colors.red),
        );
        return;
      }
      final qty = double.tryParse(line.quantityController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quantity for line #${i + 1} must be > 0.'), backgroundColor: Colors.red),
        );
        return;
      }
      final price = double.tryParse(line.unitPriceController.text) ?? 0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unit price for line #${i + 1} must be > 0.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final budget = double.tryParse(_budgetController.text) ?? 0;
    if (budget < _totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget limit must be at least total cost (LKR ${_totalCost.toStringAsFixed(2)}).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final shipping = double.tryParse(_shippingController.text) ?? 0.0;
      final poData = {
        'supplierId': _selectedSupplierId,
        'currency': 'LKR',
        'budgetLimit': budget,
        'shipping': shipping,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Manual Purchase Order generated from mobile',
        'lines': _lineItems.map((line) {
          final mat = _materials.firstWhere(
            (m) => m.id == line.rawMaterialId,
            orElse: () => _materials.first,
          );
          final desc = line.descriptionController.text.trim().isNotEmpty
              ? line.descriptionController.text.trim()
              : '${mat.name} (${mat.skuCode})';
          return {
            'rawMaterialId': line.rawMaterialId,
            'description': desc,
            'quantity': double.parse(line.quantityController.text),
            'unitPrice': double.parse(line.unitPriceController.text),
          };
        }).toList(),
      };

      final createdPo = await widget.service.createPurchaseOrder(poData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft Purchase Order Created! Please submit for approval.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, createdPo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create PO: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF0B0F19);
    const cardBg = Color(0xFF0F172A);
    const borderColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        title: const Text('Create Purchase Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Supplier Selection Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: Color(0xFF06B6D4), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Supplier Details',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select Approved Vendor *',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedSupplierId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: _suppliers
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.isActive ? "Active" : "Inactive"})'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedSupplierId = val),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0F19),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Order Lines Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list_alt_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Order Lines (${_lineItems.length})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _addLineItem,
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF06B6D4)),
                            label: const Text('Add Line', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ..._lineItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final line = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0F19),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Item #${idx + 1}',
                                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (_lineItems.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                      onPressed: () => _removeLineItem(idx),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Material Dropdown
                              const Text('Raw Material *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                initialValue: line.rawMaterialId,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                isExpanded: true,
                                items: _materials
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text(
                                          '${m.name} [${m.skuCode}] (${m.unitOfMeasure})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    line.rawMaterialId = val;
                                  });
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Qty & Unit Price Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Quantity *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: line.quantityController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          onChanged: (_) => setState(_updateBudgetRecommendation),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFF0F172A),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: const BorderSide(color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Unit Price (LKR) *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: line.unitPriceController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          onChanged: (_) => setState(_updateBudgetRecommendation),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFF0F172A),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: const BorderSide(color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Subtotal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'LKR ${line.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Overview & Budget Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF59E0B), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Financial Summary & Cap',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Lines Subtotal:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Text('LKR ${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Shipping:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _shippingController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              onChanged: (_) => setState(_updateBudgetRecommendation),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0B0F19),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFF334155), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Estimated Order Cost:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            'LKR ${_totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Budget Ceiling Limit (LKR) *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0F19),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Order Notes & Instructions', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Notes for supplier...',
                          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF0B0F19),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _submitting ? null : _createPo,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F19)),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _submitting ? 'Creating PO...' : 'Create Draft Purchase Order',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: const Color(0xFF0B0F19),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }
}
