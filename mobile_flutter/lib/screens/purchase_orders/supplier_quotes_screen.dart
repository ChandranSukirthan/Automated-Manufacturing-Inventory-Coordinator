import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class SupplierQuotesScreen extends StatefulWidget {
  const SupplierQuotesScreen({required this.supplierId, super.key});
  final int supplierId;
  @override
  State<SupplierQuotesScreen> createState() => _SupplierQuotesScreenState();
}

class _SupplierQuotesScreenState extends State<SupplierQuotesScreen> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{for (final key in ['unitPrice', 'minimumOrderQuantity', 'packSize', 'availableQuantity', 'leadTimeDays', 'qualityEvidence', 'currency']) key: TextEditingController()};
  List<dynamic> _quotes = [], _materials = [];
  int? _materialId, _quoteId;
  bool _active = true, _busy = false;
  String? _error;
  String get _path => '/suppliers/${widget.supplierId}/quotes';
  @override
  void initState() { super.initState(); _reset(); _load(); }
  void _reset() { _materialId = null; _quoteId = null; _active = true; for (final c in _fields.values) { c.clear(); } _fields['currency']!.text = 'USD'; _fields['packSize']!.text = '1'; _fields['minimumOrderQuantity']!.text = '1'; }
  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.get(_path), _api.get('/inventory/rawmaterials')]);
      if (mounted) setState(() { _quotes = results[0] as List<dynamic>; _materials = results[1] as List<dynamic>; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
  }
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final data = <String, dynamic>{'rawMaterialId': _materialId, 'isActive': _active};
      for (final entry in _fields.entries) { data[entry.key] = ['currency', 'qualityEvidence'].contains(entry.key) ? entry.value.text.trim() : num.parse(entry.value.text); }
      if (_quoteId == null) { await _api.post(_path, data); } else { await _api.put('$_path/$_quoteId', data); }
      setState(_reset); await _load();
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { for (final c in _fields.values) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Confirmed material quotes')), body: ListView(padding: const EdgeInsets.all(16), children: [
    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
    ..._quotes.map((quote) => ListTile(title: Text('${quote['unitPrice']} ${quote['currency']} · available ${quote['availableQuantity']}'), subtitle: Text('Material ${quote['rawMaterialId']} · ${quote['isActive'] == true ? 'Active' : 'Inactive'}'),
      trailing: TextButton(onPressed: _busy ? null : () => setState(() { _quoteId = (quote['id'] as num).toInt(); _materialId = (quote['rawMaterialId'] as num).toInt(); _active = quote['isActive'] == true; for (final entry in _fields.entries) { entry.value.text = quote[entry.key].toString(); } }), child: const Text('Edit')))),
    Form(key: _form, child: Column(children: [
      DropdownButtonFormField<int>(key: ValueKey('$_materialId-$_quoteId'), initialValue: _materialId, decoration: const InputDecoration(labelText: 'Material'),
        items: _materials.map((m) => DropdownMenuItem(value: (m['id'] as num).toInt(), child: Text('${m['skuCode']} · ${m['name']}'))).toList(), onChanged: _quoteId != null || _busy ? null : (value) => setState(() => _materialId = value), validator: (value) => value == null ? 'Choose material' : null),
      ..._fields.entries.map((entry) => TextFormField(controller: entry.value, decoration: InputDecoration(labelText: {'unitPrice': 'Unit price', 'minimumOrderQuantity': 'Minimum order', 'packSize': 'Pack size', 'availableQuantity': 'Available quantity', 'leadTimeDays': 'Lead time (days)', 'qualityEvidence': 'Quality evidence', 'currency': 'Currency'}[entry.key]), validator: (value) {
        if ((value ?? '').trim().isEmpty) return 'Required';
        if (['currency', 'qualityEvidence'].contains(entry.key)) return null;
        final number = num.tryParse(value!); if (number == null || number < 0) return 'Enter a nonnegative number';
        if (['unitPrice', 'packSize'].contains(entry.key) && number <= 0) return 'Must be positive';
        if (entry.key == 'leadTimeDays' && number != number.truncate()) return 'Enter whole days';
        return null;
      })),
      SwitchListTile(title: const Text('Active quote'), value: _active, onChanged: _busy ? null : (value) => setState(() => _active = value)),
      ElevatedButton(onPressed: _busy ? null : _save, child: Text(_quoteId == null ? 'Add quote' : 'Update quote')),
      if (_quoteId != null) TextButton(onPressed: () => setState(_reset), child: const Text('Cancel edit')),
    ])),
  ]));
}
