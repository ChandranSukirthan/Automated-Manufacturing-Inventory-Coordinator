import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/inventory_api_service.dart';
import '../../services/purchase_order_service.dart';
import '../../utils/locale.dart';

class POCreateScreen extends StatefulWidget {
  const POCreateScreen({
    required this.service,
    this.initialSupplierId,
    this.initialMaterialId,
    this.initialQuantity,
    this.initialPrice,
    this.initialBudget,
    this.initialCurrency = 'LKR',
    this.procurementId,
    this.candidateId,
    this.materialId,
    this.sku,
    this.quantity,
    super.key,
  });
  final PurchaseOrderService service;
  final int? initialSupplierId, initialMaterialId, procurementId, candidateId;
  final double? initialQuantity, initialPrice, initialBudget;
  final String initialCurrency;
  final int? materialId;
  final String? sku;
  final num? quantity;
  @override
  State<POCreateScreen> createState() => _POCreateScreenState();
}

class _OrderLineInput {
  _OrderLineInput({this.materialId, double? quantity, double? price})
    : quantity = TextEditingController(text: quantity?.toString() ?? ''),
      price = TextEditingController(text: price?.toString() ?? '');
  int? materialId;
  final TextEditingController quantity, price;
  final description = TextEditingController();
  double get total =>
      (double.tryParse(quantity.text) ?? 0) *
      (double.tryParse(price.text) ?? 0);
  void dispose() {
    quantity.dispose();
    price.dispose();
    description.dispose();
  }
}

class _POCreateScreenState extends State<POCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _notes = TextEditingController();
  final _shipping = TextEditingController(text: '0');
  final _lines = <_OrderLineInput>[];
  List<SupplierSummary> _suppliers = [];
  List<RawMaterialModel> _materials = [];
  int? _supplierId;
  String _currency = 'LKR';
  bool _loading = true, _saving = false;
  String? _error;
  double get _total => _lines.fold(0, (sum, line) => sum + line.total);

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    _budget.text = widget.initialBudget?.toString() ?? '';
    if (widget.procurementId != null) {
      _notes.text =
          'Customised from procurement request ${widget.procurementId}.';
    }
    _lines.add(
      _OrderLineInput(
        materialId: widget.initialMaterialId ?? widget.materialId,
        quantity: widget.initialQuantity ?? widget.quantity?.toDouble(),
        price: widget.initialPrice,
      ),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.procurementId != null) {
        final request = await widget.service.getProcurementById(
          widget.procurementId!,
        );
        if (request == null) {
          throw StateError('Unable to load the procurement request.');
        }
        if (request.generatedPurchaseOrderId != null) {
          if (mounted) {
            Navigator.pop(context, request.generatedPurchaseOrderId);
          }
          return;
        }
      }
      final suppliers = await widget.service.getSuppliers();
      final materials = await widget.service.getRawMaterials();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers.where((s) => s.isActive).toList();
        _materials = materials;
        if (_lines.first.materialId == null && widget.sku != null) {
          final matches = materials.where((m) => m.skuCode == widget.sku);
          if (matches.isNotEmpty) _lines.first.materialId = matches.first.id;
        }
        _supplierId = _suppliers.any((s) => s.id == widget.initialSupplierId)
            ? widget.initialSupplierId
            : null;
        for (final line in _lines) {
          if (!_materials.any((m) => m.id == line.materialId)) {
            line.materialId = null;
          }
        }
        _loading = false;
        if (_suppliers.isEmpty || _materials.isEmpty) {
          _error =
              'Active suppliers and materials must be available before creating an order. Retry loading.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load order options: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _budget.dispose();
    _notes.dispose();
    _shipping.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String? _positive(String? value) {
    final number = double.tryParse((value ?? '').trim());
    return number == null || !number.isFinite || number <= 0
        ? 'Enter a positive number.'
        : null;
  }

  Future<void> _save(bool submit) async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_total + double.parse(_shipping.text.trim()) >
        double.parse(_budget.text.trim())) {
      setState(() => _error = 'Order total exceeds the budget limit.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var po = await widget.service.createPurchaseOrder({
        'supplierId': _supplierId,
        'currency': _currency,
        'budgetLimit': double.parse(_budget.text.trim()),
        'notes': _notes.text.trim(),
        if (widget.procurementId != null)
          'procurementRequestId': widget.procurementId,
        if (widget.candidateId != null) 'candidateId': widget.candidateId,
        'lines': [
          for (final line in _lines)
            {
              'rawMaterialId': line.materialId,
              'description': line.description.text.trim(),
              'quantity': double.parse(line.quantity.text.trim()),
              'unitPrice': double.parse(line.price.text.trim()),
            },
        ],
      });
      if (submit && po.status.toLowerCase() == 'draft') {
        try {
          po = await widget.service.submitPurchaseOrder(po.id);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Draft saved. Submission failed: $error. You can retry from order details.',
                ),
              ),
            );
          }
        }
      }
      if (mounted) Navigator.pop(context, po.id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to create purchase order: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Purchase Order')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  if (_suppliers.isEmpty || _materials.isEmpty)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry loading'),
                    ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<int>(
                  key: const ValueKey('po-supplier'),
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Supplier *'),
                  items: _suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _supplierId = id),
                  validator: (id) =>
                      id == null ? 'Select an active supplier.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: {'LKR', 'EUR', 'GBP', widget.initialCurrency}
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _currency = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _budget,
                  enabled: !_saving,
                  validator: _positive,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Budget limit ($_currency) *',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Order notes'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _shipping,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Estimated shipping ($_currency)',
                    helperText:
                        'Budget planning estimate; the purchase order records item costs.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a non-negative amount.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < _lines.length; index++)
                  _lineCard(_lines[index], index),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _lines.add(_OrderLineInput())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order total: ${formatMoney(_total, currency: _currency)}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving || _suppliers.isEmpty || _materials.isEmpty
                      ? null
                      : () => _save(false),
                  child: Text(_saving ? 'Saving…' : 'Save draft'),
                ),
                OutlinedButton(
                  onPressed: _saving || _suppliers.isEmpty || _materials.isEmpty
                      ? null
                      : () => _save(true),
                  child: const Text('Save and submit for approval'),
                ),
              ],
            ),
          ),
  );
  Widget _lineCard(_OrderLineInput line, int index) => Card(
    key: ObjectKey(line),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _lines.remove(line));
                          line.dispose();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue: line.materialId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Material *'),
            items: _materials
                .map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.name} (${m.skuCode})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (id) => setState(() => line.materialId = id),
            validator: (id) => id == null ? 'Select a material.' : null,
          ),
          TextFormField(
            controller: line.description,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Item description'),
          ),
          TextFormField(
            controller: line.quantity,
            enabled: !_saving,
            validator: _positive,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity *'),
            onChanged: (_) => setState(() {}),
          ),
          TextFormField(
            controller: line.price,
            enabled: !_saving,
            validator: _positive,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Unit price ($_currency) *'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
  );
}
